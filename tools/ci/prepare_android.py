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
    ("android.permission.REQUEST_INSTALL_PACKAGES", ""),
]

UNUSED_PERMISSIONS = [
    "android.permission.READ_MEDIA_IMAGES",
    "android.permission.READ_MEDIA_VIDEO",
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
    # Una librería (carátulas) declara permisos de fotos y videos que la app no
    # usa: se quitan para que Android solo pida "Música y audio".
    if "xmlns:tools" not in text:
        text = text.replace(
            "<manifest ",
            '<manifest xmlns:tools="http://schemas.android.com/tools" ',
            1,
        )
        changed.append("namespace tools")
    removals = [
        p for p in UNUSED_PERMISSIONS if f'android:name="{p}" tools:node="remove"' not in text
    ]
    if removals:
        lines = "".join(
            f'    <uses-permission android:name="{p}" tools:node="remove" />\n' for p in removals
        )
        text = text.replace("<application", lines + "    <application", 1)
        changed.append("permisos quitados: " + ", ".join(p.split(".")[-1] for p in removals))
    extra = ""
    if "com.ryanheise.audioservice.AudioService" not in text:
        extra += SERVICE
        changed.append("service de audio")
    if "com.ryanheise.audioservice.MediaButtonReceiver" not in text:
        extra += RECEIVER
        changed.append("receiver de botones multimedia")
    if WIDGET_RECEIVERS.strip().splitlines()[0] not in text:
        extra += WIDGET_RECEIVERS
        changed.append("widgets de pantalla de inicio")
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
    '    tools:keep="@drawable/audio_service_*,@drawable/ic_notification,'
    '@drawable/ic_heart,@drawable/ic_heart_outline,@mipmap/ic_launcher,'
    '@layout/widget_player,@layout/widget_shortcuts,@drawable/widget_bg,'
    '@drawable/widget_button_bg,@drawable/ic_widget_*,@xml/widget_*" />\n'
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



# ---- widgets de pantalla de inicio -----------------------------------------

WIDGET_RECEIVERS = """        <receiver android:name=".PlayerWidget" android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data android:name="android.appwidget.provider"
                android:resource="@xml/widget_player_info" />
        </receiver>
        <receiver android:name=".ShortcutsWidget" android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data android:name="android.appwidget.provider"
                android:resource="@xml/widget_shortcuts_info" />
        </receiver>
        <receiver android:name=".WidgetActionReceiver" android:exported="false" />
"""

MAIN_ACTIVITY = """package {package}

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Actividad principal: audio en segundo plano + puente con los widgets. */
class MainActivity : AudioServiceActivity() {{
    private var pendingAction: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {{
        super.onCreate(savedInstanceState)
        pendingAction = intent?.getStringExtra(EXTRA_ACTION)
    }}

    override fun onNewIntent(intent: Intent) {{
        super.onNewIntent(intent)
        setIntent(intent)
        pendingAction = intent.getStringExtra(EXTRA_ACTION)
    }}

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler {{ call, result ->
                when (call.method) {{
                    "update" -> {{
                        saveState(
                            this,
                            call.argument("title"),
                            call.argument("artist"),
                            call.argument("art"),
                            call.argument<Boolean>("playing") ?: false,
                            call.argument<Int>("accent") ?: DEFAULT_ACCENT,
                        )
                        refreshWidgets(this)
                        result.success(null)
                    }}
                    "takeAction" -> {{
                        val action = pendingAction
                        pendingAction = null
                        result.success(action)
                    }}
                    else -> result.notImplemented()
                }}
            }}
    }}

    companion object {{
        const val CHANNEL = "resonar/widget"
        const val EXTRA_ACTION = "resonar_action"
        const val PREFS = "resonar_widget"
        const val DEFAULT_ACCENT = -0xaddd4 // 0xFFFF5722

        fun saveState(
            context: Context,
            title: String?,
            artist: String?,
            art: String?,
            playing: Boolean,
            accent: Int,
        ) {{
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString("title", title)
                .putString("artist", artist)
                .putString("art", art)
                .putBoolean("playing", playing)
                .putInt("accent", accent)
                .apply()
        }}

        /** Pide a Android que vuelva a dibujar los widgets colocados. */
        fun refreshWidgets(context: Context) {{
            val manager = AppWidgetManager.getInstance(context) ?: return
            for (cls in listOf(PlayerWidget::class.java, ShortcutsWidget::class.java)) {{
                val ids = manager.getAppWidgetIds(ComponentName(context, cls))
                if (ids == null || ids.isEmpty()) continue
                val intent = Intent(context, cls).apply {{
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }}
                context.sendBroadcast(intent)
            }}
        }}
    }}
}}
"""

WIDGETS_KT = """package {package}

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.RectF
import android.os.Handler
import android.os.Looper
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.session.MediaControllerCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.util.Log
import android.widget.RemoteViews

private const val TAG = "ResonarWidget"
internal const val EXTRA_MEDIA_ACTION = "media_action"

/** Abre la app; con [action] le pide algo al arrancar (ver WidgetBridge en Dart). */
internal fun openApp(context: Context, action: String?): PendingIntent {{
    val intent = Intent(context, MainActivity::class.java).apply {{
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        if (action != null) putExtra(MainActivity.EXTRA_ACTION, action)
    }}
    return PendingIntent.getActivity(
        context,
        (action ?: "open").hashCode(),
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}}

/** Manda una orden al reproductor sin abrir la app. */
internal fun mediaAction(context: Context, action: String): PendingIntent {{
    val intent = Intent(context, WidgetActionReceiver::class.java)
        .putExtra(EXTRA_MEDIA_ACTION, action)
    return PendingIntent.getBroadcast(
        context,
        action.hashCode(),
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}}

/** Recorta la carátula en un cuadrado con esquinas redondeadas. */
internal fun roundedArt(path: String?, size: Int): Bitmap? {{
    if (path.isNullOrEmpty()) return null
    return try {{
        val options = BitmapFactory.Options().apply {{ inJustDecodeBounds = true }}
        BitmapFactory.decodeFile(path, options)
        if (options.outWidth <= 0) return null
        var sample = 1
        while (options.outWidth / sample > size * 2) sample *= 2
        val source = BitmapFactory.decodeFile(
            path,
            BitmapFactory.Options().apply {{ inSampleSize = sample }},
        ) ?: return null
        val side = minOf(source.width, source.height)
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val target = RectF(0f, 0f, size.toFloat(), size.toFloat())
        canvas.drawRoundRect(target, size * 0.18f, size * 0.18f, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        val src = Rect(
            (source.width - side) / 2,
            (source.height - side) / 2,
            (source.width + side) / 2,
            (source.height + side) / 2,
        )
        canvas.drawBitmap(source, src, target, paint)
        if (source !== output) source.recycle()
        output
    }} catch (error: Throwable) {{
        Log.w(TAG, "No se pudo preparar la carátula del widget", error)
        null
    }}
}}

/** Widget grande: carátula, título, artista y controles. */
class PlayerWidget : AppWidgetProvider() {{
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {{
        val views = build(context)
        for (id in appWidgetIds) appWidgetManager.updateAppWidget(id, views)
    }}

    private fun build(context: Context): RemoteViews {{
        val prefs = context.getSharedPreferences(MainActivity.PREFS, Context.MODE_PRIVATE)
        val views = RemoteViews(context.packageName, R.layout.widget_player)
        val title = prefs.getString("title", null)
        val playing = prefs.getBoolean("playing", false)
        val accent = prefs.getInt("accent", MainActivity.DEFAULT_ACCENT)

        views.setTextViewText(R.id.widget_title, title ?: "Resonar")
        views.setTextViewText(
            R.id.widget_artist,
            prefs.getString("artist", null) ?: "Tocá para elegir música",
        )
        val art = roundedArt(prefs.getString("art", null), 160)
        if (art != null) {{
            views.setImageViewBitmap(R.id.widget_art, art)
        }} else {{
            views.setImageViewResource(R.id.widget_art, R.drawable.ic_widget_note)
            views.setInt(R.id.widget_art, "setColorFilter", accent)
        }}
        views.setImageViewResource(
            R.id.widget_play,
            if (playing) R.drawable.ic_widget_pause else R.drawable.ic_widget_play,
        )
        views.setInt(R.id.widget_play, "setColorFilter", accent)
        views.setOnClickPendingIntent(R.id.widget_root, openApp(context, null))
        views.setOnClickPendingIntent(R.id.widget_prev, mediaAction(context, "prev"))
        views.setOnClickPendingIntent(R.id.widget_play, mediaAction(context, "play_pause"))
        views.setOnClickPendingIntent(R.id.widget_next, mediaAction(context, "next"))
        return views
    }}
}}

/** Widget chico: atajos para empezar a escuchar de una. */
class ShortcutsWidget : AppWidgetProvider() {{
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {{
        val prefs = context.getSharedPreferences(MainActivity.PREFS, Context.MODE_PRIVATE)
        val accent = prefs.getInt("accent", MainActivity.DEFAULT_ACCENT)
        val views = RemoteViews(context.packageName, R.layout.widget_shortcuts)
        for ((id, action) in listOf(
            R.id.shortcut_resume to "resume",
            R.id.shortcut_shuffle to "shuffle",
            R.id.shortcut_favorites to "favorites",
            R.id.shortcut_search to "search",
        )) {{
            views.setOnClickPendingIntent(id, openApp(context, action))
            views.setInt(id, "setColorFilter", accent)
        }}
        for (id in appWidgetIds) appWidgetManager.updateAppWidget(id, views)
    }}
}}

/**
 * Pasa la orden del widget al reproductor conectándose al servicio de audio.
 * Se usa "bind" (y no "start") para que nunca pueda tumbar la app si el
 * servicio no está vivo: en ese caso simplemente no pasa nada.
 */
class WidgetActionReceiver : BroadcastReceiver() {{
    override fun onReceive(context: Context, intent: Intent) {{
        val action = intent.getStringExtra(EXTRA_MEDIA_ACTION) ?: return
        val result = goAsync()
        val appContext = context.applicationContext
        var finished = false
        var browser: MediaBrowserCompat? = null
        val handler = Handler(Looper.getMainLooper())

        fun finish() {{
            if (finished) return
            finished = true
            try {{
                browser?.disconnect()
            }} catch (error: Throwable) {{
                Log.w(TAG, "No se pudo cerrar la conexión", error)
            }}
            result.finish()
        }}

        val callback = object : MediaBrowserCompat.ConnectionCallback() {{
            override fun onConnected() {{
                try {{
                    val token = browser?.sessionToken ?: return
                    val controller = MediaControllerCompat(appContext, token)
                    val state = controller.playbackState?.state
                    when (action) {{
                        "play_pause" ->
                            if (state == PlaybackStateCompat.STATE_PLAYING) {{
                                controller.transportControls.pause()
                            }} else {{
                                controller.transportControls.play()
                            }}
                        "next" -> controller.transportControls.skipToNext()
                        "prev" -> controller.transportControls.skipToPrevious()
                    }}
                }} catch (error: Throwable) {{
                    Log.w(TAG, "No se pudo enviar la orden al reproductor", error)
                }}
                handler.postDelayed({{ finish() }}, 1200)
            }}

            override fun onConnectionFailed() = finish()

            override fun onConnectionSuspended() = finish()
        }}

        try {{
            browser = MediaBrowserCompat(
                appContext,
                ComponentName(appContext, "com.ryanheise.audioservice.AudioService"),
                callback,
                null,
            )
            browser.connect()
            // Red de seguridad: si el servicio nunca contesta, se corta igual.
            handler.postDelayed({{ finish() }}, 4000)
        }} catch (error: Throwable) {{
            Log.w(TAG, "No se pudo conectar con el reproductor", error)
            finish()
        }}
    }}
}}
"""

WIDGET_LAYOUT_PLAYER = """<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/widget_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/widget_bg"
    android:gravity="center_vertical"
    android:orientation="horizontal"
    android:padding="12dp">

    <ImageView
        android:id="@+id/widget_art"
        android:layout_width="72dp"
        android:layout_height="72dp"
        android:contentDescription="Carátula"
        android:scaleType="centerCrop"
        android:src="@drawable/ic_widget_note" />

    <LinearLayout
        android:layout_width="0dp"
        android:layout_height="wrap_content"
        android:layout_marginStart="12dp"
        android:layout_weight="1"
        android:orientation="vertical">

        <TextView
            android:id="@+id/widget_title"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:ellipsize="end"
            android:maxLines="1"
            android:text="Resonar"
            android:textColor="#FFFFFFFF"
            android:textSize="15sp"
            android:textStyle="bold" />

        <TextView
            android:id="@+id/widget_artist"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:ellipsize="end"
            android:maxLines="1"
            android:text="Tocá para elegir música"
            android:textColor="#B3FFFFFF"
            android:textSize="12sp" />

        <LinearLayout
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="4dp"
            android:orientation="horizontal">

            <ImageView
                android:id="@+id/widget_prev"
                android:layout_width="40dp"
                android:layout_height="40dp"
                android:background="@drawable/widget_button_bg"
                android:contentDescription="Anterior"
                android:padding="8dp"
                android:src="@drawable/ic_widget_prev" />

            <ImageView
                android:id="@+id/widget_play"
                android:layout_width="44dp"
                android:layout_height="44dp"
                android:layout_marginStart="8dp"
                android:background="@drawable/widget_button_bg"
                android:contentDescription="Reproducir o pausar"
                android:padding="8dp"
                android:src="@drawable/ic_widget_play" />

            <ImageView
                android:id="@+id/widget_next"
                android:layout_width="40dp"
                android:layout_height="40dp"
                android:layout_marginStart="8dp"
                android:background="@drawable/widget_button_bg"
                android:contentDescription="Siguiente"
                android:padding="8dp"
                android:src="@drawable/ic_widget_next" />
        </LinearLayout>
    </LinearLayout>
</LinearLayout>
"""

SHORTCUT_ITEM = """    <ImageView
        android:id="@+id/{id}"
        android:layout_width="0dp"
        android:layout_height="48dp"
        android:layout_weight="1"
        android:background="@drawable/widget_button_bg"
        android:contentDescription="{label}"
        android:padding="12dp"
        android:src="@drawable/{icon}" />
"""

WIDGET_LAYOUT_SHORTCUTS = """<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/widget_bg"
    android:gravity="center_vertical"
    android:orientation="horizontal"
    android:padding="10dp">
{items}</LinearLayout>
"""

SHORTCUT_ITEMS = [
    ("shortcut_resume", "Seguir escuchando", "ic_widget_play"),
    ("shortcut_shuffle", "Todo al azar", "ic_widget_shuffle"),
    ("shortcut_favorites", "Favoritas al azar", "ic_widget_heart"),
    ("shortcut_search", "Buscar", "ic_widget_search"),
]

WIDGET_INFO = """<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:initialLayout="@layout/{layout}"
    android:minHeight="{height}dp"
    android:minWidth="250dp"
    android:resizeMode="horizontal|vertical"
    android:updatePeriodMillis="0"
    android:widgetCategory="home_screen" />
"""

WIDGET_BG = """<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="#E6121212" />
    <corners android:radius="22dp" />
</shape>
"""

WIDGET_BUTTON_BG = """<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="oval">
    <solid android:color="#1FFFFFFF" />
</shape>
"""

WIDGET_ICONS = {
    "ic_widget_play": "M8,5v14l11,-7z",
    "ic_widget_pause": "M6,19h4V5H6v14zM14,5v14h4V5h-4z",
    "ic_widget_prev": "M6,6h2v12H6zM9.5,12l8.5,6V6z",
    "ic_widget_next": "M6,18l8.5,-6L6,6v12zM16,6v12h2V6h-2z",
    "ic_widget_note": "M12,3v10.55c-0.59,-0.34 -1.27,-0.55 -2,-0.55 -2.21,0 -4,1.79 -4,4s1.79,4 4,4 4,-1.79 4,-4V7h4V3h-6z",
    "ic_widget_shuffle": "M10.59,9.17L5.41,4 4,5.41l5.17,5.17 1.42,-1.41zM14.5,4l2.04,2.04L4,18.59 5.41,20 17.96,7.46 20,9.5V4h-5.5zM14.83,13.41l-1.41,1.41 3.13,3.13L14.5,20H20v-5.5l-2.04,2.04 -3.13,-3.13z",
    "ic_widget_heart": "M12,21.35l-1.45,-1.32C5.4,15.36 2,12.28 2,8.5 2,5.42 4.42,3 7.5,3c1.74,0 3.41,0.81 4.5,2.09C13.09,3.81 14.76,3 16.5,3 19.58,3 22,5.42 22,8.5c0,3.78 -3.4,6.86 -8.55,11.54L12,21.35z",
    "ic_widget_search": "M15.5,14h-0.79l-0.28,-0.27C15.41,12.59 16,11.11 16,9.5 16,5.91 13.09,3 9.5,3S3,5.91 3,9.5 5.91,16 9.5,16c1.61,0 3.09,-0.59 4.23,-1.57l0.27,0.28v0.79l5,4.99L20.49,19l-4.99,-5zM9.5,14C7.01,14 5,11.99 5,9.5S7.01,5 9.5,5 14,7.01 14,9.5 11.99,14 9.5,14z",
}


def write_widget_resources(package):
    """Widgets de pantalla de inicio: reproductor y atajos."""
    main = os.path.join(ANDROID, "app", "src", "main")
    kotlin_dir = os.path.join(main, "kotlin", *package.split("."))
    os.makedirs(kotlin_dir, exist_ok=True)
    java_activity = os.path.join(main, "java", *package.split("."), "MainActivity.java")
    if os.path.exists(java_activity):
        os.remove(java_activity)
    with open(os.path.join(kotlin_dir, "MainActivity.kt"), "w", encoding="utf-8") as f:
        f.write(MAIN_ACTIVITY.format(package=package))
    with open(os.path.join(kotlin_dir, "ResonarWidgets.kt"), "w", encoding="utf-8") as f:
        f.write(WIDGETS_KT.format(package=package))

    res = os.path.join(main, "res")
    layout = os.path.join(res, "layout")
    xml = os.path.join(res, "xml")
    drawable = os.path.join(res, "drawable")
    for folder in (layout, xml, drawable):
        os.makedirs(folder, exist_ok=True)

    with open(os.path.join(layout, "widget_player.xml"), "w", encoding="utf-8") as f:
        f.write(WIDGET_LAYOUT_PLAYER)
    items = "".join(
        SHORTCUT_ITEM.format(id=i, label=label, icon=icon)
        for i, label, icon in SHORTCUT_ITEMS
    )
    with open(os.path.join(layout, "widget_shortcuts.xml"), "w", encoding="utf-8") as f:
        f.write(WIDGET_LAYOUT_SHORTCUTS.format(items=items))
    with open(os.path.join(xml, "widget_player_info.xml"), "w", encoding="utf-8") as f:
        f.write(WIDGET_INFO.format(layout="widget_player", height="110"))
    with open(os.path.join(xml, "widget_shortcuts_info.xml"), "w", encoding="utf-8") as f:
        f.write(WIDGET_INFO.format(layout="widget_shortcuts", height="70"))
    with open(os.path.join(drawable, "widget_bg.xml"), "w", encoding="utf-8") as f:
        f.write(WIDGET_BG)
    with open(os.path.join(drawable, "widget_button_bg.xml"), "w", encoding="utf-8") as f:
        f.write(WIDGET_BUTTON_BG)
    for name, path in WIDGET_ICONS.items():
        with open(os.path.join(drawable, name + ".xml"), "w", encoding="utf-8") as f:
            f.write(VECTOR.format(path=path))
    print("Widgets escritos (reproductor y atajos).")


def find_package():
    """Paquete de la app, leído de la MainActivity generada por Flutter."""
    for root, _, files in os.walk(os.path.join(ANDROID, "app", "src", "main")):
        for name in files:
            if name not in ("MainActivity.kt", "MainActivity.java"):
                continue
            text = open(os.path.join(root, name), encoding="utf-8").read()
            match = re.search(r"^package\s+([\w.]+)", text, re.M)
            if match:
                return match.group(1)
    return "com.b3njamingc.play_music_app"


def patch_gradle_dependencies():
    """androidx.media: lo necesitan los widgets para hablar con el reproductor."""
    kts = os.path.join(ANDROID, "app", "build.gradle.kts")
    groovy = os.path.join(ANDROID, "app", "build.gradle")
    path = kts if os.path.exists(kts) else groovy if os.path.exists(groovy) else None
    if path is None:
        print("::warning::No encontré build.gradle(.kts) de la app.")
        return
    text = open(path, encoding="utf-8").read()
    if "androidx.media:media" in text:
        print("Dependencias: androidx.media ya estaba.")
        return
    line = (
        '    implementation("androidx.media:media:1.7.0")'
        if path.endswith(".kts")
        else "    implementation 'androidx.media:media:1.7.0'"
    )
    match = re.search(r"^dependencies\s*\{", text, re.M)
    if match:
        text = text[: match.end()] + "\n" + line + text[match.end():]
    else:
        text = text.rstrip() + "\n\ndependencies {\n" + line + "\n}\n"
    open(path, "w", encoding="utf-8").write(text)
    print("Dependencias: androidx.media añadida.")


if __name__ == "__main__":
    generated = generate_android()
    if not os.path.exists(MANIFEST):
        print("::error::No se encontró", MANIFEST)
        sys.exit(1)
    if generated:
        apply_branding()
    patch_manifest()
    write_notification_resources()
    write_widget_resources(find_package())
    patch_gradle_dependencies()
    patch_signing()
