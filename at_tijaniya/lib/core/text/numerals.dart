/// Saisie de nombres dans les deux langues de l'app (audit du 2026-10-04).
///
/// Un clavier arabe produit des chiffres arabo-indiens (٠١٢٣٤٥٦٧٨٩) ou
/// persans (۰۱۲۳۴۵۶۷۸۹), que `int.tryParse` ne reconnaît pas : une année ou
/// un nombre de répétitions saisis ainsi étaient refusés comme invalides.
/// Ces fonctions les ramènent aux chiffres 0-9 avant de convertir.
library;

String toAsciiDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(rune - 0x0660 + 0x30);
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(rune - 0x06F0 + 0x30);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// Comme `int.tryParse`, en acceptant les chiffres arabo-indiens et persans.
int? parseLocalizedInt(String input) => int.tryParse(toAsciiDigits(input.trim()));

/// Comme `double.tryParse`, avec les mêmes chiffres ; la virgule décimale
/// (française ou arabe « ٫ ») est acceptée comme séparateur.
double? parseLocalizedDouble(String input) {
  return double.tryParse(toAsciiDigits(input.trim()).replaceAll(',', '.').replaceAll('٫', '.'));
}
