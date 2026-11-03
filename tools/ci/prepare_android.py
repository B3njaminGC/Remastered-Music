#!/usr/bin/env python3
"""Prepara la carpeta android/ para compilar en CI.

1. Si el repo no tiene android/, la genera con `flutter create` (en una carpeta
   temporal, sin tocar lib/ ni pubspec.yaml) y la copia.
2. Asegura, de forma idempotente, lo que necesita el reproductor en segundo plano
   (just_audio_background / audio_service): permisos, <service>, <receiver> y
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


APP_LABEL = "Cadencia"
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


if __name__ == "__main__":
    generated = generate_android()
    if not os.path.exists(MANIFEST):
        print("::error::No se encontró", MANIFEST)
        sys.exit(1)
    if generated:
        apply_branding()
    patch_manifest()
    patch_main_activity()
    patch_signing()
