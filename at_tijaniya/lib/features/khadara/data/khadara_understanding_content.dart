/// At-Tijaniya — contenu pédagogique "Comprendre la Khadara".
///
/// RÈGLE IMPÉRATIVE (CLAUDE.md, docs/01-perimetre-fonctionnel.md § 8) : ce
/// fichier est la SEULE source de ce contenu dans l'app, au même titre que
/// `wirds_content.dart` pour le module Wirds ou `figures_content.dart` pour
/// le module Figures. Expliquer le déroulement, la signification ou la
/// pratique de la Khadara est un contenu religieux/pratique — il ne figure
/// pas dans le tableau de validation de docs/01 § 8 (seul le module Wirds y
/// est "Validé"). Cette liste reste donc VIDE tant que le porteur de projet
/// n'a pas fourni un document explicitement marqué "validé". Ne jamais y
/// ajouter un texte inventé ou déduit par le modèle, même à partir des
/// descriptions déjà présentes ailleurs dans les documents du projet (ex.
/// docs/01 § 5.2 ne fait qu'esquisser le module, ce n'est pas un contenu
/// pédagogique validé pour un nouveau disciple).
library;

class KhadaraUnderstandingSection {
  const KhadaraUnderstandingSection({required this.title, required this.body});

  final String title;
  final String body;
}

const List<KhadaraUnderstandingSection> validatedKhadaraUnderstanding = [];
