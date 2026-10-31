/// Formatos de audio que la biblioteca reconoce.
const Set<String> audioExtensions = {
  '.mp3',
  '.m4a',
  '.aac',
  '.flac',
  '.wav',
  '.ogg',
  '.opus',
};

bool isAudioPath(String path) {
  final lower = path.toLowerCase();
  return audioExtensions.any(lower.endsWith);
}
