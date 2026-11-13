# Guía de desarrollo

Todo lo que no le sirve a quien solo quiere usar la app: cómo está armado el
código, cómo se compila, cómo se firma y cómo sale una versión.

## Requisitos

- Flutter en el canal `stable` (el CI usa el último).
- Java 17 para compilar en Android.
- Python 3 para los scripts de `tools/ci/`.

No hace falta instalar nada más: el proyecto no trae carpeta `android/` en el
repo, se genera sola (ver abajo).

## Trabajar en local

```bash
flutter pub get
flutter analyze --no-fatal-infos    # errores y advertencias frenan; los avisos informativos no
flutter test                        # pruebas de la lógica sin interfaz
dart format lib test                # el código todavía no está formateado por completo
```

Para correr la app en un teléfono conectado hay que generar primero la carpeta
de Android:

```bash
python3 tools/ci/prepare_android.py
flutter run
```

## Estructura de `lib/`

```
main.dart            arranque, tema y navegación
core/                reproductor (audio_service, player_handler), ecualizador,
                     carátulas, ajustes, puente con los widgets
library/             escaneo de carpetas, índice de etiquetas, favoritas,
                     géneros, M3U, orígenes de descarga, estadísticas
features/local/      pestañas de la biblioteca, listas, cola, búsqueda,
                     selección múltiple, diálogos
lyrics/              letras (ID3/M4A, .lrc, lrclib.net) y panel sincronizado
update/              aviso, descarga e instalación de versiones nuevas
screens/             Sonando, Ajustes, Ecualizador, Carpetas, Novedades,
                     Bienvenida, Apoyar el proyecto
theme/               colores, temas y color sacado de la carátula
```

## Pruebas

En `test/` hay pruebas de lo que se puede verificar sin interfaz, audio,
permisos ni red:

| Archivo | Qué cubre |
| --- | --- |
| `m3u_test.dart` | armar, leer y resolver listas `.m3u` (incluye rutas de otro teléfono) |
| `lyrics_test.dart` | formato LRC, orden de líneas y línea activa según el tiempo |
| `track_source_test.dart` | deducir la app de origen a partir de la ruta |
| `track_info_test.dart` | título desde la ruta, textos de respaldo y orden de canciones |
| `changelog_test.dart` | el historial de novedades está ordenado y completo |
| `presets_test.dart` | curvas del ecualizador, colores de acento y modos de tema |

**Lo que no está cubierto** y hay que probar a mano en un teléfono:
reproducción, notificación y pantalla de bloqueo, widgets, permisos, escaneo de
carpetas reales, lectura de etiquetas, ecualizador, Bluetooth y botones de
auriculares, y la descarga e instalación de actualizaciones.

## Compilar el APK

Cada push a `main` compila el APK con GitHub Actions (≈ 7 min) y lo publica en
**Releases** como `Resonar-build-N.apk` (`N` = número de ejecución, que también
es el `versionCode`). También se puede lanzar a mano desde *Actions → Build APK
→ Run workflow*. Con un tag `v*` se publica con ese nombre.

El repo no incluye `android/`: `tools/ci/prepare_android.py` la genera con
`flutter create` y le aplica ícono, nombre ("Resonar"), paquete
(`com.b3njamingc.play_music_app`), permisos, el servicio de audio,
`MainActivity`, los recursos de la notificación, los widgets y la firma. Si
alguna vez se sube una carpeta `android/` propia, se respeta y solo se completa
lo que falte.

El APK se compila solo para **arm64** (`--target-platform android-arm64`): pesa
la mitad que el universal. Para teléfonos de 32 bits hay que quitar esa opción
del paso *Compilar APK*.

El análisis de Android (lint) se desactiva desde el script: se cae leyendo
comentarios de librerías de terceros y no afecta al APK.

## Workflows

| Workflow | Cuándo corre | Qué hace |
| --- | --- | --- |
| `verify.yml` | cada push y cada pull request | `flutter analyze` y `flutter test` |
| `build-apk.yml` | push a `main` y tags `v*` | compila el APK y publica el release |
| `smoke-test.yml` | a mano | instala el APK en un emulador y revisa que abra sin cerrarse |

## Firma estable

Sin configurar nada, cada compilación se firma con una clave distinta y Android
no deja actualizar encima. Para evitarlo, generá un keystore una vez y guardalo
como *secret* del repositorio:

```bash
keytool -genkey -v -keystore release.keystore -storepass TU_CLAVE \
  -alias resonar -keypass TU_CLAVE -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Resonar,O=Resonar,C=AR"
base64 -w0 release.keystore      # en macOS: base64 -i release.keystore
```

Pegá el resultado en *Settings → Secrets and variables → Actions* con el nombre
`DEBUG_KEYSTORE_BASE64`. Guardá el archivo en un lugar seguro y **nunca lo subas
al repositorio**.

> El script usa hoy la clave `android` (la convención del keystore de
> depuración de Android). Alcanza para distribuir por tu cuenta, pero si alguna
> vez la app va a una tienda, conviene una clave propia y cambiarla también en
> `patch_signing()` dentro de `prepare_android.py`.

## Publicar una versión

1. Hacé los cambios y agregá su entrada en `lib/core/changelog.dart` (es lo que
   la app muestra en *Qué hay de nuevo*) y en `CHANGELOG.md`.
2. Subí a `main`. El workflow compila y crea el release `build-N` solo.
3. Esperá a que termine y probá el APK en un teléfono: lo que depende de audio,
   permisos y widgets no lo cubre ninguna prueba automática.
4. Si hace falta, editá las notas del release desde la web de GitHub.

## Widgets de pantalla de inicio

El código nativo también lo escribe `prepare_android.py`
(`write_widget_resources`): `MainActivity.kt` (con los canales
`resonar/widget` y `resonar/audio`), `ResonarWidgets.kt`, los layouts y los
íconos. Desde Dart, `lib/core/widget_bridge.dart` publica qué suena y recoge el
atajo con el que se abrió la app.

Los botones del widget hablan con el reproductor conectándose al servicio por
*bind* (`MediaBrowserCompat`), nunca con `startForegroundService`: así, si el
servicio no está vivo, el botón no hace nada en vez de tumbar la app.

Las vistas previas del selector de widgets son PNG generados con
`python3 tools/ci/make_widget_previews.py`.

## Ícono

`tools/ci/icon/` contiene los recursos generados; se regeneran con
`python3 tools/ci/make_icons.py`.

## Permisos

El script añade los que falten, solo en la copia de compilación: `INTERNET`
(letras y avisos de versión), `READ_MEDIA_AUDIO`, `READ_EXTERNAL_STORAGE`
(hasta Android 12), `WAKE_LOCK`, `FOREGROUND_SERVICE`,
`FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `POST_NOTIFICATIONS` y
`REQUEST_INSTALL_PACKAGES`.

También **quita** los de fotos y videos (`READ_MEDIA_IMAGES`,
`READ_MEDIA_VIDEO`) que alguna librería pueda declarar por su cuenta: la app no
los necesita.

## Avisos de actualización

Al abrir la app (como mucho una vez cada 15 minutos) se consulta
`releases/latest` del repositorio; si el `build-N` publicado es mayor que el
instalado, aparece el aviso. El build instalado se inyecta al compilar con
`--dart-define=BUILD_NUMBER=N`.

El código está en `lib/update/` y se puede copiar a otra app: alcanza con
cambiar `owner` y `repo` en `update_checker.dart`.

## Donaciones

`lib/core/donation_config.dart` guarda el alias o link de Mercado Pago que
muestra la pantalla de apoyo. No pongas credenciales ahí: el repositorio es
público, y un alias solo sirve para recibir.
