/// Modèle des réglages de confidentialité — table Supabase
/// `privacy_settings`. Priorité P0 (docs/03-architecture-ecrans.md,
/// "Paramètres de confidentialité").
///
/// RAPPEL SENSIBILITÉ (CLAUDE.md, docs/01 § 5.4.1 et § 5.4.2) :
/// `lineageVisible`, `mouqaddamStatusVisible` et `availableAsSponsor` sont
/// interprétés côté base par des fonctions Postgres `SECURITY DEFINER`
/// dédiées (`search_lineage_matches`, `mouqaddam_status_visible_to`,
/// `search_available_sponsors`) — jamais lus directement côté client pour
/// une décision de visibilité inter-utilisateurs.
library;

enum WhoCanContact { everyone, matchesOnly }

WhoCanContact whoCanContactFromString(String value) {
  return switch (value) {
    'everyone' => WhoCanContact.everyone,
    _ => WhoCanContact.matchesOnly,
  };
}

String whoCanContactToDbValue(WhoCanContact value) {
  return switch (value) {
    WhoCanContact.everyone => 'everyone',
    WhoCanContact.matchesOnly => 'matches_only',
  };
}

class PrivacySettings {
  const PrivacySettings({
    this.lineageVisible = false,
    this.mouqaddamStatusVisible = false,
    this.availableAsSponsor = false,
    this.whoCanContact = WhoCanContact.matchesOnly,
  });

  final bool lineageVisible;
  final bool mouqaddamStatusVisible;
  final bool availableAsSponsor;
  final WhoCanContact whoCanContact;

  /// Valeurs par défaut de la table si la ligne n'existe pas encore (cas
  /// limite : compte créé avant le trigger `handle_new_user`).
  factory PrivacySettings.fromRow(Map<String, dynamic>? row) {
    if (row == null) return const PrivacySettings();
    return PrivacySettings(
      lineageVisible: row['lineage_visible'] as bool? ?? false,
      mouqaddamStatusVisible: row['mouqaddam_status_visible'] as bool? ?? false,
      availableAsSponsor: row['available_as_sponsor'] as bool? ?? false,
      whoCanContact: whoCanContactFromString(row['who_can_contact'] as String? ?? 'matches_only'),
    );
  }

  PrivacySettings copyWith({
    bool? lineageVisible,
    bool? mouqaddamStatusVisible,
    bool? availableAsSponsor,
    WhoCanContact? whoCanContact,
  }) {
    return PrivacySettings(
      lineageVisible: lineageVisible ?? this.lineageVisible,
      mouqaddamStatusVisible: mouqaddamStatusVisible ?? this.mouqaddamStatusVisible,
      availableAsSponsor: availableAsSponsor ?? this.availableAsSponsor,
      whoCanContact: whoCanContact ?? this.whoCanContact,
    );
  }
}
