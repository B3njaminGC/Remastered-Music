/// Novedades de cada versión, para la pantalla "Qué hay de nuevo".
///
/// Al publicar una compilación nueva se agrega su entrada arriba de todo.
/// Si un build no trae nada para contar (un arreglo interno, un retoque del
/// CI) simplemente no se lista.
class ChangelogEntry {
  const ChangelogEntry({
    required this.build,
    required this.title,
    this.news = const [],
    this.fixes = const [],
  });

  final int build;

  /// Resumen corto de la versión.
  final String title;

  /// Cosas nuevas.
  final List<String> news;

  /// Arreglos.
  final List<String> fixes;
}

class Changelog {
  Changelog._();

  /// De la más nueva a la más vieja.
  static const List<ChangelogEntry> entries = [
    ChangelogEntry(
      build: 47,
      title: 'Novedades y avisos más seguidos',
      news: [
        'Esta pantalla: tocá la versión en Ajustes para ver qué cambió.',
        'Al instalar una versión nueva, las novedades aparecen solas.',
      ],
      fixes: [
        'El aviso de actualización se fija casi en cada arranque; antes '
            'esperaba seis horas y te enterabas tarde.',
      ],
    ),
    ChangelogEntry(
      build: 44,
      title: 'Volumen y versión',
      news: [
        'La música se pausa si bajás el volumen del todo.',
        'Al darle a reproducir con el volumen en cero, sube una rayita.',
        'Apartado "Acerca de" en Ajustes con la versión instalada.',
      ],
    ),
    ChangelogEntry(
      build: 43,
      title: 'Ecualizador propio',
      news: [
        'Ecualizador adentro de la app, con bandas, curvas listas '
            '(Graves, Voces, Agudos…) y refuerzo de volumen.',
      ],
      fixes: [
        'Antes abría el del sistema y hay teléfonos que no traen ninguno.',
      ],
    ),
    ChangelogEntry(
      build: 42,
      title: 'Botón de anterior',
      news: [
        'Pasados 5 segundos, "anterior" reinicia la canción; dentro de los '
            'primeros 5, salta a la pista de antes.',
      ],
    ),
    ChangelogEntry(
      build: 41,
      title: 'Auriculares y notificación',
      news: [
        'Ajuste para invertir siguiente y anterior de los auriculares.',
        'El ■ de la notificación ahora también cierra la app.',
      ],
    ),
    ChangelogEntry(
      build: 39,
      title: 'Aleatorio que no se vuelve loco',
      fixes: [
        'El aleatorio mezcla la cola una sola vez y respeta ese orden. '
            'Antes elegía al azar en cada salto y había canciones que no '
            'sonaban nunca.',
        'La cola que ves es la que va a sonar, y la podés reordenar.',
      ],
    ),
    ChangelogEntry(
      build: 38,
      title: 'Selección más clara',
      fixes: [
        'Al elegir canciones, la tilde va a la derecha y la carátula queda '
            'a la vista.',
      ],
    ),
    ChangelogEntry(
      build: 37,
      title: 'Listas con opciones',
      news: [
        'Mantené apretada una canción de una lista para elegir varias.',
        'Menú por canción: reproducir a continuación, a la cola, a otra '
            'lista, favorita, género, mover al principio o al final, quitar.',
      ],
    ),
    ChangelogEntry(
      build: 35,
      title: 'Widgets presentables',
      fixes: [
        'La carátula del widget salía como un cuadrado de color sólido.',
        'Botones al costado del texto: entra bien en dos celdas.',
      ],
    ),
    ChangelogEntry(
      build: 34,
      title: 'Widgets a tu color',
      fixes: [
        'Los widgets ignoraban el color de acento y quedaban naranjas.',
        'Vista previa de verdad en el selector de widgets de Android.',
      ],
    ),
    ChangelogEntry(
      build: 33,
      title: 'Descargas que avisan',
      fixes: [
        'La descarga de actualizaciones se quedaba colgada sin decir nada. '
            'Ahora muestra los MB, el motivo si falla, y deja reintentar.',
      ],
    ),
    ChangelogEntry(
      build: 32,
      title: 'Widgets a gusto',
      news: [
        'Fondo del widget oscuro, claro, de acento o con la carátula, con '
            'la opacidad que quieras.',
      ],
      fixes: [
        'Si una canción se trababa en el último segundo, ahora pasa sola.',
      ],
    ),
    ChangelogEntry(
      build: 30,
      title: 'Widgets de pantalla de inicio',
      news: [
        'Widget con carátula y controles, y otro con atajos: seguir, todo '
            'al azar, favoritas y buscar.',
      ],
    ),
    ChangelogEntry(
      build: 29,
      title: 'Arreglo del cierre al abrir',
      fixes: [
        'La app se cerraba al abrirla por una librería de carátulas que '
            'pedía permisos de fotos y videos que no hacían falta.',
      ],
    ),
    ChangelogEntry(
      build: 25,
      title: 'Temas, Sonando y resumen',
      news: [
        'Temas claro, oscuro y AMOLED, con ocho colores de acento.',
        '"Sonando" toma el color de la carátula; se desliza para cambiar de '
            'canción y la letra se abre a pantalla completa.',
        'Listas automáticas: Más escuchadas, Agregadas recientemente y '
            'Redescubrí, más "Tu resumen" de escucha.',
        'Fundido entre canciones.',
      ],
    ),
    ChangelogEntry(
      build: 19,
      title: 'Listas y actualizaciones',
      news: [
        'Cambiarle el nombre a una lista.',
        'Las actualizaciones se descargan e instalan desde la app.',
      ],
    ),
  ];

  static int get latestBuild => entries.isEmpty ? 0 : entries.first.build;
}
