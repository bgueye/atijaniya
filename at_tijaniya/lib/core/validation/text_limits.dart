/// Longueurs maximales des textes saisis par les disciples (audit Communauté
/// du 2026-10-26, P2-1). Les mêmes plafonds sont imposés en base par des
/// contraintes `check` (`database/migrations/2026-10-26_community_text_length_checks.sql`) :
/// les changer ici impose de changer la migration, et inversement.
///
/// Jusque-là, seuls les messages étaient limités, et seulement par l'écran :
/// un appel direct à l'API acceptait une publication de 200 000 caractères
/// ou un nom d'affichage illisible partout où il apparaît.
library;

abstract final class TextLimits {
  /// Publication du fil.
  static const post = 5000;

  /// Commentaire, message de groupe ou message privé (`MessageComposer`).
  static const message = 2000;

  static const groupName = 80;
  static const groupDescription = 1000;
  static const groupRegion = 120;

  /// Nom d'affichage, visible de tous.
  static const displayName = 60;
  static const bio = 500;

  /// Motif facultatif d'un signalement.
  static const reportReason = 1000;
}
