# Textos para pegar en GitHub

Estos cambios se hacen desde la web y no se pueden hacer desde el repositorio,
así que quedan acá listos para copiar y pegar.

---

## 1. Descripción del repositorio

*Dónde:* página del repo → engranaje ⚙ al lado de "About" → campo
**Description**.

```
Reproductor de música offline para Android: biblioteca local, listas M3U, letras sincronizadas, ecualizador y widgets.
```

Versión más corta, por si queda mejor:

```
Reproductor de música offline para Android, hecho en Flutter.
```

En el mismo panel conviene:

- **Website:** dejarlo vacío (no hay sitio) o poner el link a Releases:
  `https://github.com/B3njaminGC/Remastered-Music/releases/latest`
- Tildar **Releases** para que se vean en la portada.
- Destildar **Packages** y **Deployments**, que no se usan.

---

## 2. Topics

*Dónde:* mismo engranaje ⚙ de "About" → campo **Topics**.

```
android
flutter
dart
music-player
offline
mp3-player
audio-player
lrc-lyrics
material-design
foss
```

---

## 3. Notas de los releases

*Dónde:* Releases → entrás a uno → **Edit release** → campo de descripción.

Las notas actuales son la línea del último commit, que no se entiende de afuera.
Abajo está el texto para las versiones que valen la pena. No hace falta editar
todas: con las últimas y las que marcan un hito alcanza.

### build-55 (la actual)

```markdown
## Resonar build-55

### Corregido
- En **Listas**, los dos botones flotantes tapaban el menú de cada lista. Ahora hay uno solo que abre un menú con *Crear lista* e *Importar lista (.m3u)*.
- Las listas y los géneros tienen espacio abajo para que el botón no pise la última fila.
- La compilación fallaba por el análisis interno de una librería de terceros.

**Instalación:** descargá `Resonar-build-55.apk` y abrilo desde el celular. Se instala encima de la versión anterior sin perder listas ni ajustes.
```

### build-53

```markdown
## Resonar build-53

### Añadido
- El **aleatorio y el bucle se mantienen** al cerrar y volver a abrir la app. Antes arrancaban siempre apagados.
- También se guarda el orden original de la cola, así que apagar el aleatorio la devuelve a como estaba.
```

### build-52

```markdown
## Resonar build-52

### Cambiado
- La opción de **invertir los botones de siguiente y anterior** de los auriculares ahora se elige **por dispositivo**. Se aplica solo a los auriculares que lo necesitan; un parlante bluetooth que anda bien queda intacto.

> Si el ajuste estaba activado de antes, hay que volver a marcarlo: *Ajustes → Sonido → Configuración avanzada → Invertir botones de los auriculares*.
```

### build-50

```markdown
## Resonar build-50

### Corregido
- Al abrir la app desde cero no se buscaban canciones nuevas hasta pasados dos minutos: lo que hubieras descargado con la app cerrada no aparecía. Ahora se busca apenas arranca.

### Cambiado
- La detección de canciones nuevas dejó de ser una opción: siempre está activa.
```

### build-49

```markdown
## Resonar build-49

### Añadido
- **La biblioteca se actualiza sola.** Descargás una canción en otra app, volvés a Resonar y ya está. También revisa cada dos minutos mientras la usás, y avisa cuántas canciones nuevas encontró.
```

### build-47

```markdown
## Resonar build-47

### Añadido
- Pantalla **"Qué hay de nuevo"**: tocá la versión en *Ajustes* y ves qué trajo cada compilación, separado en novedades y arreglos. Después de actualizar aparece sola.

### Corregido
- El aviso de versión nueva solo consultaba una vez cada seis horas, así que te enterabas tarde. Ahora se fija prácticamente en cada arranque.
```

### build-44

```markdown
## Resonar build-44

### Añadido
- La música **se pausa si bajás el volumen del teléfono a cero**.
- Al darle a reproducir con el volumen en cero, lo sube un paso y muestra la barra del sistema, así los botones de volumen controlan la música y no el timbre.
- Apartado **Acerca de** en Ajustes con la versión instalada.
```

### build-43

```markdown
## Resonar build-43

### Añadido
- **Ecualizador propio de la app**: bandas con sus frecuencias, curvas listas (Normal, Graves, Voces, Agudos, Fiesta, Suave) y refuerzo de volumen de hasta +10 dB.

### Corregido
- El ecualizador anterior abría el del sistema, y hay teléfonos que directamente no traen uno.

> Las bandas aparecen recién cuando hay una canción sonando: es Android el que las entrega.
```

### build-39

```markdown
## Resonar build-39

### Corregido
- **El aleatorio dejó de repartir mal.** Antes elegía una pista al azar en cada salto con un orden interno propio, y había canciones que no sonaban nunca. Ahora la cola se mezcla **una sola vez** y ese orden se respeta.
- Como consecuencia, la cola que ves es la que va a sonar, y la podés reordenar a mano.
- Al terminar la cola con el aleatorio puesto, se baraja de nuevo y sigue.
```

### build-32

```markdown
## Resonar build-32

### Añadido
- **Widgets configurables**: fondo oscuro, claro, del color de acento o con la carátula de lo que suena, con la opacidad que elijas.

### Corregido
- Si una canción se trababa en el último segundo (pasa con descargas que traen mal la duración), ahora pasa sola a la siguiente.
```

### build-30

```markdown
## Resonar build-30

### Añadido
- **Widgets de pantalla de inicio**: uno con la carátula y los controles, y otro con atajos (seguir escuchando, todo al azar, favoritas al azar y buscar).
```

### build-29

```markdown
## Resonar build-29

### Corregido
- **La app se cerraba al abrirla.** La causa era una librería de carátulas que se caía cuando no tenía los permisos de fotos y videos, que habíamos quitado por innecesarios. Se sacó la librería: las carátulas ahora se leen directo de las etiquetas del archivo.

> Esta versión hay que instalarla a mano desde acá. A partir de ella, las actualizaciones se bajan desde la propia app.
```

### build-25

```markdown
## Resonar build-25

### Añadido
- **Temas**: claro, oscuro, AMOLED o el del sistema, con ocho colores de acento.
- **Sonando** renovado: toma el color de la carátula, la portada se anima, se desliza para cambiar de canción y la letra se abre a pantalla completa.
- **Listas automáticas**: Más escuchadas, Agregadas recientemente y Redescubrí.
- **Tu resumen**: artistas, canciones y géneros más escuchados, calculado solo en tu teléfono.
- **Fundido entre canciones**, configurable de 0 a 8 segundos.

### Corregido
- Se quitaron los permisos de fotos y videos, que pedía una librería y la app no necesita.
```

### build-16

```markdown
## Resonar build-16

### Añadido
- **Notificación y pantalla de bloqueo** con carátula, progreso, favorita y controles.
- **Selección múltiple** de canciones: mantené apretado para elegir varias.
- **Importar y exportar listas .m3u** para pasarlas desde o hacia otro reproductor.
- **Guardar la cola actual** como lista con nombre.
- **Géneros**: automáticos según las etiquetas, o propios con un código corto (CB para Cumbia).
- **Aviso de versión nueva** al abrir la app.

### Corregido
- Títulos ilegibles en los archivos descargados con Snaptube.
```

### build-1

```markdown
## Primera versión

Reproductor offline con biblioteca local, favoritas, listas, artistas, álbumes y orígenes de descarga. El APK se compila y publica solo desde GitHub Actions.
```

---

## 4. Opcional: ordenar la lista de Releases

Hay muchas versiones publicadas. Si querés dejar solo las que cuentan la
historia, estas son las que vale la pena conservar:

`build-1` (la primera) · `build-9` (primera con el nombre Resonar) ·
`build-16` · `build-25` · `build-29` · `build-39` · `build-43` · `build-49` ·
`build-55` (la actual)

Para borrar una: Releases → entrás a una → **Delete** arriba a la derecha.
Conviene borrar también su tag cuando lo pregunte.
