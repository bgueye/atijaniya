/// Numéros de téléphone et adresses e-mail repérés dans le contact d'un lieu
/// (audit Zawiyas du 2026-10-25, P3-1). Le champ `zawiyas.contact_info` est un
/// texte libre (« hiccnyc@gmail.com · +1 332-223-0579 (d'après un annuaire en
/// ligne, à vérifier) ») : sans décision sur sa structure, l'app y repère ce
/// qui peut s'appeler ou recevoir un message, et propose un bouton pour
/// chacun. Le texte reste affiché en entier, remarques comprises.
///
/// Les liens sont construits ici (`tel:`, `mailto:`), jamais repris tels
/// quels du texte : aucun autre schéma ne peut en sortir.
library;

enum ContactLinkKind { phone, email }

class ContactLink {
  const ContactLink({required this.kind, required this.label, required this.uri});

  final ContactLinkKind kind;

  /// Tel qu'écrit dans le contact, pour le libellé du bouton.
  final String label;
  final Uri uri;
}

final _emailPattern = RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+');

/// Un « + » facultatif, un chiffre, puis chiffres, espaces, points, tirets ou
/// parenthèses, et un chiffre final : au moins 8 chiffres au total (voir
/// [extractContactLinks]), pour ne pas prendre une année ou un numéro de rue.
final _phonePattern = RegExp(r'\+?\d[\d\s().-]{6,}\d');

/// Liens repérés dans [text], dans leur ordre d'apparition.
List<ContactLink> extractContactLinks(String text) {
  final found = <(int, ContactLink)>[];
  for (final match in _emailPattern.allMatches(text)) {
    final email = match.group(0)!;
    found.add(
        (match.start, ContactLink(kind: ContactLinkKind.email, label: email, uri: Uri(scheme: 'mailto', path: email))));
  }
  for (final match in _phonePattern.allMatches(text)) {
    final raw = match.group(0)!.trim();
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) continue;
    final number = raw.startsWith('+') ? '+$digits' : digits;
    found.add(
        (match.start, ContactLink(kind: ContactLinkKind.phone, label: raw, uri: Uri(scheme: 'tel', path: number))));
  }
  found.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (_, link) in found) link];
}
