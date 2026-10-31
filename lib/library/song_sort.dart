/// Orden de la lista de canciones.
enum SongSort {
  title('Título'),
  artist('Artista'),
  recent('Añadidas recientemente'),
  source('Origen (Snaptube, NewPipe…)');

  const SongSort(this.label);

  final String label;

  static SongSort fromName(Object? name) {
    for (final value in SongSort.values) {
      if (value.name == name) return value;
    }
    return SongSort.title;
  }
}
