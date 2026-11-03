# Resonar — música 100 % offline

Reproductor de música para Android que lee los archivos de tu dispositivo. Sin cuentas ni servidores; funciona sin internet (la búsqueda de letras en línea es opcional).

## Funciones
- Biblioteca con pestañas: **Canciones · Favoritas · Listas · Artistas · Álbumes · Géneros · Orígenes** (agrupados por las etiquetas del archivo).
- **Géneros**: se arman solos con el género de las etiquetas (entiende los números ID3 como `(13)`); las canciones sin género van a *Sin género*. También podés crear tus propios géneros con un código corto (p. ej. `CB` = Cumbia), agregar canciones a mano desde el género (*Agregar canciones*) o desde el menú ⋮ de cualquier canción → *Cambiar género* (escribís el código o el nombre). Lo manual manda sobre la etiqueta.
- **Origen de la descarga**: pestaña *Orígenes* y orden por origen (Snaptube, NewPipe, Vidmate, TubeMate, Telegram, WhatsApp, Chrome…). Se deduce de la carpeta del archivo; lo que está en *Descargas* sin carpeta propia aparece como "Descargas del navegador" y el resto se agrupa por nombre de carpeta. Para agregar más apps, edita `lib/library/track_source.dart`.
- Orden por título, artista o fecha de incorporación; reproducción aleatoria.
- Favoritas (♥), listas propias (crear, reordenar, quitar canciones, eliminar).
- Cola de reproducción: *reproducir a continuación*, *añadir a la cola*, reordenar y quitar deslizando.
- Reproductor con carátula, **temporizador de apagado**, **velocidad** (0.5x–2x), repetir y aleatorio.
- Notificación y controles en segundo plano; pausa al desconectar auriculares; ecualizador del sistema.
- **Letras** debajo del reproductor, sincronizadas tipo Spotify: se toman del archivo (ID3 USLT / M4A), de un `.lrc` junto a la canción o, si hay internet y está activado en Ajustes, de [lrclib.net](https://lrclib.net) (solo se envían título y artista; se guardan en el dispositivo). Sin letra: "Esta canción no contiene letra".
- **Retoma** la última canción, cola y posición al reabrir; la biblioteca se guarda en caché y abre completa al instante.
- Búsqueda por título, artista o álbum; modo oscuro (se recuerda).
- Pantalla **Colaborá con el proyecto** (menú lateral) con alias y link de Mercado Pago.
- Formatos: mp3, m4a, aac, flac, wav, ogg, opus.

## Qué cambió respecto a la versión con módulo online
- Se eliminó todo el módulo online (Invidious/YouTube, descargas, importador de listas) y las dependencias
  `youtube_player_flutter`, `http` y `haudiotagger`. La app ya no necesita internet.
- Las etiquetas (título/artista/álbum) se leen una vez, en segundo plano, y se guardan en un índice en memoria;
  antes cada fila las releía en cada redibujado.
- Las carátulas se extraen por lotes a una caché; antes se lanzaba un proceso por cada canción de la cola al reproducir.
- El ajuste "pausar al desconectar auriculares" y el modo oscuro ahora se aplican al arrancar (antes se perdían).
- Quitados los restos sin uso: pantalla de inicio con datos de ejemplo, letra "no disponible" y archivos de reexportación.

## Cómo obtener el APK
Cada push a `main` compila el APK automáticamente con GitHub Actions (5–10 min):
1. Abre la pestaña **Actions** del repositorio y espera a que *Build APK* termine en verde.
2. Ve a **Releases**: ahí está `reproductor-offline-build-N.apk`. Descárgalo desde el celular e instálalo
   (permite "instalar apps de orígenes desconocidos" para tu navegador).
3. También puedes lanzarlo a mano: Actions → *Build APK* → *Run workflow*.

Para publicar una versión con nombre, crea un tag `v1.1.0` (Releases → *Draft a new release* → nuevo tag).

> Si el repo no tiene carpeta `android/`, el workflow la genera solo (`tools/ci/prepare_android.py`) y le añade
> los permisos y el servicio de audio. Si algún día subes tu propia `android/`, se respeta y solo se completa lo que falte.
> Sin tu `android/` original no existe el ecualizador del sistema (Ajustes avisa que no hay uno compatible).

### Avisos de actualización
Al abrir la app (máx. una vez cada 6 h) consulta `releases/latest` de este repo; si el `build-N` publicado es mayor que el
`versionCode` instalado, muestra un aviso con **Descargar** (abre el APK en el navegador), **Más tarde** u **Omitir esta**.
Se puede apagar o forzar la búsqueda en *Ajustes → Actualizaciones*. La lógica está en `lib/update/` y es reutilizable en
otra app: copiá `update_checker.dart` y `update_prompt.dart`, cambiá `owner`/`repo` y agregá `package_info_plus`.

### Nombre, ícono y paquete
Cuando el workflow genera `android/`, aplica el ícono propio (`tools/ci/icon/`, regenerable con `tools/ci/make_icons.py`),
el nombre "Resonar" y el paquete `com.b3njamingc.play_music_app` (distinto del de las pruebas anteriores,
`com.example.play_music_app`, así que conviven sin conflicto de firma). Cada build sube el `versionCode` con el número de ejecución.

### Firma estable (recomendado)
Sin configurar nada, cada compilación en GitHub se firma con una clave nueva, y Android **no deja actualizar encima**
de una versión firmada con otra (hay que desinstalar antes). Para evitarlo:
```bash
keytool -genkey -v -keystore debug.keystore -storepass android -alias androiddebugkey \
  -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
base64 -w0 debug.keystore      # en macOS: base64 -i debug.keystore
```
Pega el resultado como *secret* del repo con el nombre `DEBUG_KEYSTORE_BASE64`
(Settings → Secrets and variables → Actions). Guarda el archivo `debug.keystore` en un lugar seguro y **no lo subas al repo**.
Esto asume que `android/app/build.gradle` firma `release` con la configuración `debug` (lo que hace la plantilla por defecto, y también el `android/` que genera el workflow).
Si no puedes usar una PC, el keystore se puede generar en cualquier lado y pegarse como secret en base64 desde el navegador del celular.

### Configurar las donaciones
Editá `lib/core/donation_config.dart` y completá `mercadoPagoAlias` y/o `mercadoPagoLink` (y opcionalmente `holderName`).
Lo que dejes vacío no se muestra; si están los dos vacíos, la pantalla dice "Próximamente".

### Permisos
El script de CI comprueba el `AndroidManifest.xml` y, solo en la copia de CI, añade los que falten:
`READ_MEDIA_AUDIO`, `READ_EXTERNAL_STORAGE` (hasta Android 12), `WAKE_LOCK`, `FOREGROUND_SERVICE`,
`FOREGROUND_SERVICE_MEDIA_PLAYBACK` y `POST_NOTIFICATIONS`. Ya no hace falta el permiso `INTERNET`; puedes quitarlo
de tu manifest (en modo debug Flutter lo necesita, en release no).

### Si algo falla
- `pub get` se queja de la versión de Dart: fija `flutter-version` en `build-apk.yml` (paso *subosito/flutter-action*).
- Error de compilación: abre el log del paso *Compilar APK* y pásamelo.
- El paso *Análisis estático* es informativo: sus avisos no detienen el APK.

## Estructura de `lib/`
```
main.dart                      arranque, tema, navegación
core/                          audio_service (reproductor), artwork_cache, app_settings, widgets
library/                       library_repository (carpetas/escaneo), track_index (etiquetas), favorites_repository
features/local/                pestañas de la biblioteca, listas, cola, búsqueda, diálogos
screens/                       Sonando, Ajustes, Bienvenida
```

## Licencia
MIT.

---
Última actualización: build con firma fija.
