#!/usr/bin/env bash
# Prueba de arranque en emulador: instala app.apk con música de prueba, la abre,
# la reabre (restaurando sesión) y junta el registro de errores.
set -u
PKG=com.b3njamingc.play_music_app
OUT=smoke-out
mkdir -p "$OUT" music

for i in 1 2 3; do
  ffmpeg -loglevel error -y -f lavfi -i "sine=frequency=$((300 + i * 150)):duration=40" \
    -f lavfi -i "color=c=0x$((i * 3))a7f4$((i * 2)):s=300x300" \
    -frames:v 1 -map 0:a -map 1:v -c:a libmp3lame -c:v mjpeg -id3v2_version 3 \
    -metadata title="Tema de prueba $i" -metadata artist="Artista $i" \
    -metadata album="Álbum $i" -metadata genre="Rock" \
    "music/prueba$i.mp3" || echo "ffmpeg falló en $i"
done
ls -l music
adb push music /sdcard/Music/ >/dev/null
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Music/prueba1.mp3 >/dev/null

adb install -r app.apk
adb shell pm grant $PKG android.permission.READ_MEDIA_AUDIO || true
adb shell pm grant $PKG android.permission.POST_NOTIFICATIONS || true

launch() {
  adb logcat -c
  adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null
  sleep 25
  adb exec-out screencap -p > "$OUT/$1.png" || true
  adb logcat -d > "$OUT/$1.log"
  echo "=== $1: PID ==="; adb shell pidof $PKG || echo "SIN PROCESO (se cerró)"
}

launch primera
# Toca la primera canción de la lista y espera a que suene.
adb shell input tap 540 520
sleep 8
adb exec-out screencap -p > "$OUT/tocando.png" || true
adb shell am force-stop $PKG
launch segunda

for f in primera segunda; do
  echo "=== ERRORES $f ==="
  grep -E "FATAL EXCEPTION|AndroidRuntime: |Fatal signal|SIGSEGV|SIGABRT|E flutter|F DEBUG|has died|UnsatisfiedLink|Unhandled Exception" "$OUT/$f.log" | grep -v "RuntimeInit\|Using default boot\|lock profiling\|Calling main entry\|VM exiting" | cut -c1-300 | head -40
done
exit 0
