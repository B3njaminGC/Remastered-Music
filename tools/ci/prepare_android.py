#!/usr/bin/env python3
"""Prepara la carpeta android/ para compilar en CI.

1. Si el repo no tiene android/, la genera con `flutter create` (en una carpeta
   temporal, sin tocar lib/ ni pubspec.yaml) y la copia.
2. Asegura, de forma idempotente, lo que necesita el reproductor en segundo plano
   (audio_service): permisos, <service>, <receiver> y
   MainActivity extendiendo AudioServiceActivity.
Si tu repo ya trae su propio android/, solo se añade lo que falte.
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

ANDROID = "android"
MANIFEST = os.path.join(ANDROID, "app", "src", "main", "AndroidManifest.xml")

PERMISSIONS = [
    ("android.permission.INTERNET", ""),  # solo para buscar letras (opcional)
    ("android.permission.READ_MEDIA_AUDIO", ""),
    ("android.permission.READ_EXTERNAL_STORAGE", ' android:maxSdkVersion="32"'),
    ("android.permission.WAKE_LOCK", ""),
    ("android.permission.FOREGROUND_SERVICE", ""),
    ("android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK", ""),
    ("android.permission.POST_NOTIFICATIONS", ""),
]

SERVICE = """        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>
"""
RECEIVER = """        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>
"""


APP_LABEL = "Resonar"
ICON_RES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icon", "res")


def generate_android():
    """Devuelve True si generó android/ (y por tanto hay que aplicar la marca propia)."""
    if os.path.isdir(ANDROID):
        print("android/ ya existe: se conserva.")
        return False
    print("android/ no existe: generándola con flutter create…")
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(
            ["flutter", "create", "--platforms=android", "--org", "com.b3njamingc",
             "--project-name", "play_music_app", tmp],
            check=True,
        )
        shutil.copytree(os.path.join(tmp, ANDROID), ANDROID)
    return True


def apply_branding():
    """Ícono propio (en vez del de Flutter) y nombre de la app."""
    res = os.path.join(ANDROID, "app", "src", "main", "res")
    shutil.copytree(ICON_RES, res, dirs_exist_ok=True)
    text = open(MANIFEST, encoding="utf-8").read()
    text = re.sub(r'android:label="[^"]*"', f'android:label="{APP_LABEL}"', text, count=1)
    open(MANIFEST, "w", encoding="utf-8").write(text)
    print("Ícono y nombre aplicados:", APP_LABEL)


def patch_manifest():
    text = open(MANIFEST, encoding="utf-8").read()
    changed = []
    if "<application" not in text:
        print("::warning::No encontré <application> en el manifest; no se tocó.")
        return
    missing = [(n, a) for n, a in PERMISSIONS if n not in text]
    if missing:
        lines = "".join(f'    <uses-permission android:name="{n}"{a} />\n' for n, a in missing)
        text = text.replace("<application", lines + "    <application", 1)
        changed.append("permisos: " + ", ".join(n.split(".")[-1] for n, _ in missing))
    extra = ""
    if "com.ryanheise.audioservice.AudioService" not in text:
        extra += SERVICE
        changed.append("service de audio")
    if "com.ryanheise.audioservice.MediaButtonReceiver" not in text:
        extra += RECEIVER
        changed.append("receiver de botones multimedia")
    if extra:
        if "</application>" not in text:
            print("::warning::No encontré </application>; no se añadió el service.")
        else:
            text = text.replace("</application>", extra + "    </application>", 1)
    if changed:
        open(MANIFEST, "w", encoding="utf-8").write(text)
    print("Manifest:", "; ".join(changed) if changed else "sin cambios.")


def patch_signing():
    """Firma release con el keystore fijo de CI (variable CI_KEYSTORE_PATH).

    Sin esa variable (o si el archivo no existe) se conserva la firma debug por
    defecto. Esto evita depender de dónde busque Gradle ~/.android/debug.keystore.
    """
    kts = os.path.join(ANDROID, "app", "build.gradle.kts")
    groovy = os.path.join(ANDROID, "app", "build.gradle")
    if os.path.exists(kts):
        path, is_kts = kts, True
    elif os.path.exists(groovy):
        path, is_kts = groovy, False
    else:
        print("::warning::No encontré build.gradle(.kts); firma sin tocar.")
        return
    text = open(path, encoding="utf-8").read()
    if "CI_KEYSTORE_PATH" in text:
        print("Firma: ya configurada.")
        return
    if is_kts:
        block = (
            "    signingConfigs {\n"
            '        create("ci") {\n'
            '            val ciKeystore = System.getenv("CI_KEYSTORE_PATH")\n'
            "            if (ciKeystore != null) {\n"
            "                storeFile = file(ciKeystore)\n"
            '                storePassword = "android"\n'
            '                keyAlias = "androiddebugkey"\n'
            '                keyPassword = "android"\n'
            "            }\n"
            "        }\n"
            "    }\n\n"
        )
        old = 'signingConfig = signingConfigs.getByName("debug")'
        new = (
            'signingConfig = if (System.getenv("CI_KEYSTORE_PATH") != null) '
            'signingConfigs.getByName("ci") else signingConfigs.getByName("debug")'
        )
    else:
        block = (
            "    signingConfigs {\n"
            "        ci {\n"
            "            def ciKeystore = System.getenv('CI_KEYSTORE_PATH')\n"
            "            if (ciKeystore != null) {\n"
            "                storeFile file(ciKeystore)\n"
            "                storePassword 'android'\n"
            "                keyAlias 'androiddebugkey'\n"
            "                keyPassword 'android'\n"
            "            }\n"
            "        }\n"
            "    }\n\n"
        )
        old = "signingConfig signingConfigs.debug"
        new = "signingConfig (System.getenv('CI_KEYSTORE_PATH') != null ? signingConfigs.ci : signingConfigs.debug)"
    if old not in text or "buildTypes {" not in text:
        print("::warning::No reconocí el bloque de firma de release; firma sin tocar.")
        return
    text = text.replace("buildTypes {", block + "    buildTypes {", 1)
    text = text.replace(old, new, 1)
    open(path, "w", encoding="utf-8").write(text)
    print("Firma: release usará CI_KEYSTORE_PATH si existe.")


def patch_main_activity():
    for root, _, files in os.walk(os.path.join(ANDROID, "app", "src", "main")):
        for name in files:
            if name not in ("MainActivity.kt", "MainActivity.java"):
                continue
            path = os.path.join(root, name)
            text = open(path, encoding="utf-8").read()
            if "AudioServiceActivity" in text:
                print(name, "ya extiende AudioServiceActivity.")
                return
            new = text.replace(
                "io.flutter.embedding.android.FlutterActivity",
                "com.ryanheise.audioservice.AudioServiceActivity",
            )
            new = re.sub(r"\bFlutterActivity\b", "AudioServiceActivity", new)
            open(path, "w", encoding="utf-8").write(new)
            print(name, "ahora extiende AudioServiceActivity.")
            return
    print("::warning::No encontré MainActivity.")

VECTOR = (
    '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
    '    android:width="24dp" android:height="24dp"\n'
    '    android:viewportWidth="24" android:viewportHeight="24">\n'
    '    <path android:fillColor="#FFFFFFFF" android:pathData="{path}"/>\n'
    '</vector>\n'
)
NOTIFICATION_ICONS = {
    # Nota musical (ícono chico de la notificación).
    "ic_notification": "M12,3v10.55c-0.59,-0.34 -1.27,-0.55 -2,-0.55 -2.21,0 -4,1.79 -4,4s1.79,4 4,4 4,-1.79 4,-4V7h4V3h-6z",
    # Corazón vacío y lleno (botón de favorita).
    "ic_heart_outline": "M16.5,3c-1.74,0 -3.41,0.81 -4.5,2.09C10.91,3.81 9.24,3 7.5,3 4.42,3 2,5.42 2,8.5c0,3.78 3.4,6.86 8.55,11.54L12,21.35l1.45,-1.32C18.6,15.36 22,12.28 22,8.5 22,5.42 19.58,3 16.5,3zM12.1,18.55l-0.1,0.1 -0.1,-0.1C7.14,14.24 4,11.39 4,8.5 4,6.5 5.5,5 7.5,5c1.54,0 3.04,0.99 3.57,2.36h1.87C13.46,5.99 14.96,5 16.5,5c2,0 3.5,1.5 3.5,3.5 0,2.89 -3.14,5.74 -7.9,10.05z",
    "ic_heart": "M12,21.35l-1.45,-1.32C5.4,15.36 2,12.28 2,8.5 2,5.42 4.42,3 7.5,3c1.74,0 3.41,0.81 4.5,2.09C13.09,3.81 14.76,3 16.5,3 19.58,3 22,5.42 22,8.5c0,3.78 -3.4,6.86 -8.55,11.54L12,21.35z",
}
KEEP_XML = (
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<resources xmlns:tools="http://schemas.android.com/tools"\n'
    '    tools:keep="@drawable/ic_notification,@drawable/ic_heart,'
    '@drawable/ic_heart_outline,@mipmap/ic_launcher" />\n'
)


def write_notification_resources():
    """Íconos de la notificación (se piden por nombre, así que hay que impedir
    que el compilador los quite como "sin usar")."""
    res = os.path.join(ANDROID, "app", "src", "main", "res")
    drawable = os.path.join(res, "drawable")
    raw = os.path.join(res, "raw")
    os.makedirs(drawable, exist_ok=True)
    os.makedirs(raw, exist_ok=True)
    for name, path in NOTIFICATION_ICONS.items():
        with open(os.path.join(drawable, name + ".xml"), "w", encoding="utf-8") as f:
            f.write(VECTOR.format(path=path))
    with open(os.path.join(raw, "keep.xml"), "w", encoding="utf-8") as f:
        f.write(KEEP_XML)
    print("Íconos de notificación escritos:", ", ".join(NOTIFICATION_ICONS))


if __name__ == "__main__":
    generated = generate_android()
    if not os.path.exists(MANIFEST):
        print("::error::No se encontró", MANIFEST)
        sys.exit(1)
    if generated:
        apply_branding()
    patch_manifest()
    write_notification_resources()
    patch_main_activity()
    patch_signing()
