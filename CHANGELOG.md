# Historial de cambios

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).

Las versiones publicadas se numeran por compilación (`build-N`), que es lo que
aparece en los [releases](https://github.com/B3njaminGC/Remastered-Music/releases)
y en *Ajustes → Qué hay de nuevo* dentro de la app. Entre paréntesis va la
versión de la app.

## [build-55] - 2026-11-11 (1.3.0)

### Corregido
- En Listas había dos botones flotantes que tapaban el menú de cada lista.
  Ahora es uno solo y adentro están crear e importar.
- La compilación fallaba por el análisis de Android (lint) de una librería de
  terceros; se desactivó porque no afecta al APK.

## [build-53] - 2026-11-11

### Añadido
- El aleatorio y el bucle se mantienen al cerrar y volver a abrir la app.

## [build-52] - 2026-11-09

### Cambiado
- La inversión de los botones de siguiente y anterior se configura por
  dispositivo: se aplica solo a los auriculares que la necesitan.

## [build-50] - 2026-11-09

### Corregido
- Al abrir la app desde cero no se buscaban canciones nuevas hasta pasados dos
  minutos. Ahora se busca al arrancar.

### Cambiado
- La detección de canciones nuevas dejó de ser opcional: siempre está activa.

## [build-49] - 2026-11-09

### Añadido
- La biblioteca se actualiza sola al volver de otra app y cada dos minutos
  mientras Resonar está abierta.

## [build-48] - 2026-11-07

### Cambiado
- Ajustes reorganizado: en Sonido quedan las opciones de siempre y el resto en
  "Configuración avanzada".
- Las carpetas incluidas e ignoradas pasaron a una pantalla propia con pestañas.

## [build-47] - 2026-11-07

### Añadido
- Pantalla "Qué hay de nuevo" con lo que trajo cada versión, que además
  aparece sola después de actualizar.

### Corregido
- El aviso de actualización solo consultaba una vez cada seis horas.

## [build-44] - 2026-11-07

### Añadido
- La música se pausa al bajar el volumen del teléfono a cero.
- Al reproducir con el volumen en cero, se sube un paso.
- Apartado "Acerca de" con la versión instalada.

## [build-43] - 2026-11-07

### Añadido
- Ecualizador propio de la app: bandas, curvas listas y refuerzo de volumen.

### Corregido
- El ecualizador anterior dependía de que el teléfono trajera uno del sistema,
  y hay modelos que no.

## [build-42] - 2026-11-07

### Cambiado
- El botón de anterior reinicia la canción salvo en los primeros 5 segundos.

## [build-41] - 2026-11-07

### Añadido
- Opción para invertir los botones de siguiente y anterior de los auriculares.
- El botón de detener de la notificación también cierra la app.

## [build-39] - 2026-11-07

### Corregido
- El modo aleatorio elegía una pista al azar en cada salto y había canciones
  que no sonaban nunca. Ahora la cola se mezcla una sola vez y ese orden se
  respeta.

## [build-38] - 2026-11-07

### Cambiado
- Al seleccionar canciones, la marca de selección va a la derecha y la carátula
  queda visible.

## [build-37] - 2026-11-07

### Añadido
- Selección múltiple dentro de una lista y menú de opciones por canción.

## [build-35] - 2026-11-07

### Corregido
- La carátula del widget aparecía como un cuadrado de color sólido.
- El widget se rediseñó para entrar en dos celdas de alto.

## [build-34] - 2026-11-06

### Corregido
- Los widgets ignoraban el color de acento elegido.
- Vista previa real en el selector de widgets de Android.
- El ecualizador del sistema llamaba a un canal nativo que no existía.

## [build-33] - 2026-11-06

### Corregido
- La descarga de actualizaciones podía quedarse colgada sin avisar. Ahora
  muestra el progreso, explica el motivo del fallo y permite reintentar.

## [build-32] - 2026-11-05 (1.3.0)

### Añadido
- Fondo de los widgets configurable: oscuro, claro, de acento o con la carátula,
  con opacidad regulable.

### Corregido
- Si una canción se trababa en el último segundo, ahora pasa sola a la
  siguiente.

## [build-30] - 2026-11-05

### Añadido
- Widgets de pantalla de inicio: uno con carátula y controles, otro con atajos.

## [build-29] - 2026-11-05

### Corregido
- La app se cerraba al abrirla por una librería de carátulas que exigía
  permisos de fotos y videos innecesarios. Se quitó la librería y los permisos.

## [build-25] - 2026-11-04 (1.2.0)

### Añadido
- Temas claro, oscuro y AMOLED con ocho colores de acento.
- "Sonando" toma el color de la carátula, con gestos y letra a pantalla
  completa.
- Listas automáticas (Más escuchadas, Agregadas recientemente, Redescubrí) y
  pantalla "Tu resumen".
- Fundido entre canciones.

## [build-19] - 2026-11-03

### Añadido
- Cambiar el nombre de una lista de reproducción.
- Las actualizaciones se descargan e instalan desde la propia app.

## [build-17] - 2026-11-03

### Cambiado
- Repositorio ordenado: README más corto, licencia MIT y guía de desarrollo
  aparte.

## [build-16] - 2026-11-03

### Añadido
- Notificación del reproductor con carátula, progreso, favorita y controles.
- Selección múltiple de canciones en la biblioteca.
- Importar y exportar listas en formato M3U.
- Guardar la cola actual como lista.
- Géneros automáticos por etiqueta y propios con código corto.
- Aviso de versión nueva desde GitHub.

### Corregido
- Títulos ilegibles en archivos descargados con Snaptube.

## [build-9] - 2026-11-03

### Cambiado
- La app pasó a llamarse **Resonar**.

## [build-1] - 2026-10-31 (1.1.0)

### Añadido
- Primera versión publicada: biblioteca local, favoritas, listas, artistas,
  álbumes y orígenes de descarga, con compilación automática del APK.
