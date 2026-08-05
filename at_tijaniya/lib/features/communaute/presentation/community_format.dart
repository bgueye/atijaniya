/// Formatage numérique volontairement neutre — même choix que
/// `khadara_format.dart` (pas d'initialisation `intl` par locale).
String formatCommunityDateTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} — ${two(dt.hour)}:${two(dt.minute)}';
}
