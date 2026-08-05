/// At-Tijaniya — contenu du module Figures et enseignements.
///
/// RÈGLE IMPÉRATIVE (CLAUDE.md, docs/01-perimetre-fonctionnel.md § 8) : ce
/// fichier est la SEULE source de biographies dans l'app, au même titre que
/// `wirds_content.dart` pour le module Wirds. Contrairement au module Wirds,
/// AUCUNE biographie n'est encore validée à ce jour :
///
/// | Contenu                          | Statut     |
/// |-----------------------------------|-----------|
/// | Biographies figures fondatrices   | À valider — compilation à mener |
/// | Biographies familles religieuses  | À valider — sensible, compilation par foyer |
///
/// Cette liste reste donc VIDE tant que le porteur de projet n'a pas fourni
/// un document explicitement marqué "validé" pour une figure donnée. Ne
/// jamais y ajouter un nom, une date, une filiation ou un enseignement
/// inventé ou déduit par le modèle — y compris des figures ou familles par
/// ailleurs mentionnées dans d'autres documents du projet (ex. les foyers
/// Tivaouane / Kaolack / Médina Baye cités comme simples choix de formulaire
/// dans docs/01 § 5.4.1 ne constituent pas une validation de contenu
/// biographique).
library;

import '../domain/figure_models.dart';

const List<Figure> validatedFigures = [];
