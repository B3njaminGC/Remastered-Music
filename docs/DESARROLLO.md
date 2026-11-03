# Guía de desarrollo

## Compilar el APK

Cada push a `main` compila el APK con GitHub Actions (≈ 7 min) y lo publica en **Releases** como `Resonar-build-N.apk`
(`N` = número de ejecución, que también es el `versionCode`). También se puede lanzar a mano: *Actions → Build APK → Run workflow*.
Con un tag `v*` se publica con ese nombre.

El repo no incluye `android/`: `tools/ci/prepare_android.py` la genera con `flutter create` y le aplica
ícono, nombre ("Resonar"), paquete (`com.b3njamingc.play_music_app`), permisos, el servicio de audio, `MainActivity`
(`AudioServiceActivity`), los íconos de la notificación y la firma. Si algún día subís tu propia `android/`, se respeta
y solo se completa lo que falte.

El APK se compila solo para **arm64** (`--target-platform android-arm64`): pesa la mitad que el universal.
Para teléfonos de 32 bits, quitá esa opción del paso *Compilar APK*.

## Firma estable

Sin configurar nada, cada compilación se firma con una clave distinta y Android no deja actualizar encima.
Para evitarlo, generá un keystore una vez y guardalo como *secret* del repo:

```bash
keytool -genkey -v -keystore debug.keystore -storepass android -alias androiddebugkey \
  -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
base64 -w0 debug.keystore      # en macOS: base64 -i debug.keystore
```

Pegá el resultado en *Settings → Secrets and variables → Actions* con el nombre `DEBUG_KEYSTORE_BASE64`.
Guardá `debug.keystore` en un lugar seguro y **no lo subas al repo**.

## Ícono

`tools/ci/icon/` contiene los recursos generados; se regeneran con `python3 tools/ci/make_icons.py`.

## Permisos

El script de CI añade (solo en la copia de compilación) los que falten: `INTERNET` (letras y avisos de versión),
`READ_MEDIA_AUDIO`, `READ_EXTERNAL_STORAGE` (hasta Android 12), `WAKE_LOCK`, `FOREGROUND_SERVICE`,
`FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `POST_NOTIFICATIONS` y `REQUEST_INSTALL_PACKAGES` (instalar las actualizaciones descargadas desde la app).

## Avisos de actualización

Al abrir la app (máx. una vez cada 6 h) se consulta `releases/latest` del repo; si el `build-N` publicado es mayor
que el instalado, se muestra un aviso (*Descargar / Más tarde / Omitir esta*). El build instalado se inyecta al compilar con
`--dart-define=BUILD_NUMBER=N` (lo hace el workflow). El código está en `lib/update/` y se puede copiar a otra app:
cambiá `owner`/`repo` en `update_checker.dart`.

## Donaciones

`lib/core/donation_config.dart` guarda el alias o link de Mercado Pago que muestra la pantalla de apoyo.
No pongas credenciales ahí: el repo es público.

## Estructura de `lib/`

```
main.dart            arranque, tema y navegación
core/                reproductor (audio_service, player_handler), carátulas, ajustes, widgets
library/             escaneo de carpetas, índice de etiquetas, favoritas, géneros, M3U, orígenes
features/local/      pestañas de la biblioteca, listas, cola, búsqueda, selección múltiple, diálogos
lyrics/              letras (ID3/M4A, .lrc, lrclib.net) y panel sincronizado
update/              aviso de versiones nuevas
screens/             Sonando, Ajustes, Bienvenida, Apoyar el proyecto
theme/               colores y tema
```

## Si algo falla

- `pub get` se queja de la versión de Dart: fijá `flutter-version` en `build-apk.yml` (paso *subosito/flutter-action*).
- Error de compilación: abrí el log del paso *Compilar APK*.
- El paso *Análisis estático* es informativo: sus avisos no detienen el APK.
