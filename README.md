<div align="center">

<img src="tools/ci/icon/icon_1024.png" width="112" alt="Ícono de Resonar" />

# Resonar

**Reproductor de música para Android, sin conexión.**
Reproduce los archivos que ya tenés en el teléfono.

[![Verificación](https://github.com/B3njaminGC/Resonar/actions/workflows/verify.yml/badge.svg)](https://github.com/B3njaminGC/Resonar/actions/workflows/verify.yml)
[![Build APK](https://github.com/B3njaminGC/Resonar/actions/workflows/build-apk.yml/badge.svg)](https://github.com/B3njaminGC/Resonar/actions/workflows/build-apk.yml)
[![Licencia: MIT](https://img.shields.io/badge/licencia-MIT-green.svg)](LICENSE)

[**⬇ Descargar la última versión**](https://github.com/B3njaminGC/Resonar/releases/latest)

</div>

## Qué es

Un reproductor para la música que ya está guardada en tu teléfono: lo que
descargaste, lo que pasaste por cable o lo que te mandaron. Lee las carpetas que
le indiques y arma la biblioteca con las etiquetas de cada archivo.

## Qué no es

- **No es un servicio de streaming.** No tiene catálogo ni busca canciones en
  internet: reproduce únicamente archivos que ya estén en tu dispositivo.
- **No descarga música.** No baja nada de YouTube ni de ninguna otra parte.
- **No tiene cuentas ni sincronización.** Nada se guarda en un servidor, así que
  tus listas y favoritas no pasan solas a otro teléfono (se pueden exportar a
  mano en formato `.m3u`).
- **No está en Google Play.** Se instala desde el archivo APK de este
  repositorio.

## Qué puede hacer

**Biblioteca**
- Canciones, favoritas, listas, artistas, álbumes, géneros y orígenes de
  descarga (Snaptube, NewPipe, navegador…).
- Géneros automáticos según las etiquetas del archivo, o propios con un código
  corto (`CB` para Cumbia).
- Elegís qué carpetas se escanean y cuáles se ignoran.
- Las canciones nuevas aparecen solas: no hay que recargar nada.

**Reproducción**
- Controles en la notificación y en la pantalla de bloqueo, con carátula,
  progreso y botón de favorita.
- Cola editable, aleatorio que mezcla una sola vez, repetición, velocidad de
  0,5× a 2×, fundido entre canciones y temporizador de apagado.
- Ecualizador propio con bandas, curvas listas y refuerzo de volumen.
- Retoma la última canción donde la dejaste.

**Letras**
- Lee las letras del archivo o de un `.lrc` al lado. Si están sincronizadas, se
  resaltan al ritmo de la canción y se pueden ver a pantalla completa.
- Si no hay nada, puede buscarlas en [lrclib.net](https://lrclib.net) (opcional,
  se apaga en Ajustes).

**Listas**
- Crear, renombrar y reordenar; selección múltiple y menú por canción.
- Importar y exportar `.m3u` para pasar listas desde o hacia otro reproductor.
- Guardar la cola actual como lista.
- Listas automáticas: Más escuchadas, Agregadas recientemente y Redescubrí.

**Personalización**
- Temas claro, oscuro, AMOLED o el del sistema, con ocho colores de acento.
- "Sonando" puede tomar el color de la carátula.
- Dos widgets de pantalla de inicio (controles y atajos), con fondo y opacidad
  configurables.

## Instalación

1. Abrí [**Releases**](https://github.com/B3njaminGC/Resonar/releases/latest)
   desde el celular y descargá el archivo `Resonar-build-N.apk`.
2. Abrilo y permití instalar desde ese navegador si Android lo pide.
3. La primera vez, dale permiso para leer tu música y para mostrar
   notificaciones.

## Cómo actualizar

Al abrir la app se consulta si hay una versión nueva y, si la hay, aparece un
aviso. Desde ahí se descarga e instala sin salir de Resonar (Android pide una
vez el permiso de "instalar apps desconocidas").

Las versiones nuevas se instalan **encima** de la anterior: no se pierden listas
ni ajustes. También se puede bajar el APK a mano desde Releases.

El aviso se puede apagar en *Ajustes → Actualizaciones*.

## Privacidad

Todo queda en el dispositivo. La app usa internet solo para dos cosas
**opcionales**, las dos apagables en *Ajustes*:

- **Buscar letras**: envía el título y el artista a lrclib.net.
- **Avisar de versiones nuevas**: consulta los releases de este repositorio.

No hay analíticas, publicidad ni envío de datos a ningún otro lado.

## Limitaciones conocidas

- **Solo Android, y solo arm64.** El APK publicado no corre en teléfonos de
  32 bits ni hay versión de iOS, escritorio o web.
- **No busca música mientras está cerrada.** Revisa al abrirla y mientras la
  usás; no corre un servicio en segundo plano para eso.
- **Depende de las etiquetas del archivo.** Si un MP3 viene sin artista, álbum o
  género, aparece como desconocido hasta que se lo asignes a mano.
- **Las letras por internet no siempre existen.** lrclib.net no tiene todo, y
  menos en canciones poco conocidas o editadas (versiones aceleradas, remixes).
- **El ecualizador es de Android.** La cantidad de bandas la decide el sistema,
  y las bandas recién están disponibles cuando hay audio sonando.
- **La inversión de botones de auriculares** se engancha a la forma más común en
  que los auriculares mandan "siguiente"; con algunos modelos puede no tener
  efecto.
- **Los widgets quedan cacheados por el lanzador.** Después de actualizar, a
  veces hay que reiniciar el teléfono para ver la vista previa nueva.

## Desarrollo

Este proyecto se desarrolla con **Claude (Anthropic) como asistente de
programación**, y no se oculta: los commits llevan sus líneas de atribución y el
historial queda como está.

Cómo se verifica lo que entra:

- **Pruebas automáticas** en cada push, sobre la lógica que se puede comprobar
  sin interfaz ni hardware: listas M3U, letras LRC, origen de descarga por ruta,
  orden de canciones y valores fijos de temas y ecualizador.
- **Análisis estático** (`flutter analyze`) como barrera: si hay errores o
  advertencias, el push no pasa.
- **Prueba en un teléfono real** antes de dar por buena una versión. Todo lo que
  depende de audio, permisos, notificación, widgets o Bluetooth se verifica a
  mano, porque no hay forma razonable de automatizarlo.

Para compilar, firmar y publicar una versión: [`docs/desarrollo.md`](docs/desarrollo.md).
Para proponer cambios: [`CONTRIBUTING.md`](CONTRIBUTING.md).
Historial de versiones: [`CHANGELOG.md`](CHANGELOG.md).

## Licencia

[MIT](LICENSE)
