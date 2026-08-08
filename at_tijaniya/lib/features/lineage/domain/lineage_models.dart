/// Modèle de la lignée spirituelle du disciple — table Supabase
/// `lineage_declarations`. Priorité P1 (docs/03-architecture-ecrans.md,
/// "Renseigner ma lignée spirituelle").
///
/// RAPPEL SENSIBILITÉ (CLAUDE.md, docs/01 § 5.4.1) : donnée personnelle
/// strictement privée. La policy RLS déployée (`lineage_owner_only`,
/// `for all using (auth.uid() = user_id)`) n'autorise aucune lecture
/// inter-utilisateurs — ce modèle et son repository ne doivent donc jamais
/// exposer de requête cross-utilisateur (ex. suggestions de noms saisis par
/// d'autres disciples : nécessiterait une fonction Postgres dédiée,
/// inexistante dans le schéma actuel).
///
/// `moqaddam_name_normalized` est volontairement absent de ce modèle :
/// maintenu par trigger serveur (`normalize_moqaddam_name`), jamais lu ni
/// écrit depuis le client (CLAUDE.md).
library;

enum Foyer { tivaouane, kaolack, medinaBaye, autre }

Foyer foyerFromString(String value) {
  return switch (value) {
    'tivaouane' => Foyer.tivaouane,
    'kaolack' => Foyer.kaolack,
    'medina_baye' => Foyer.medinaBaye,
    _ => Foyer.autre,
  };
}

String foyerToDbValue(Foyer foyer) {
  return switch (foyer) {
    Foyer.tivaouane => 'tivaouane',
    Foyer.kaolack => 'kaolack',
    Foyer.medinaBaye => 'medina_baye',
    Foyer.autre => 'autre',
  };
}

class LineageDeclaration {
  const LineageDeclaration({
    required this.foyer,
    this.foyerAutreText,
    required this.moqaddamNameText,
    this.transmissionYear,
    this.zawiyaText,
  });

  final Foyer foyer;
  final String? foyerAutreText;
  final String moqaddamNameText;
  final int? transmissionYear;
  final String? zawiyaText;

  factory LineageDeclaration.fromRow(Map<String, dynamic> row) {
    return LineageDeclaration(
      foyer: foyerFromString(row['foyer'] as String),
      foyerAutreText: row['foyer_autre_text'] as String?,
      moqaddamNameText: row['moqaddam_name_text'] as String,
      transmissionYear: row['transmission_year'] as int?,
      zawiyaText: row['zawiya_text'] as String?,
    );
  }
}

/// Un disciple correspondant à la lignée du disciple connecté
/// (`search_lineage_matches`, fonction `SECURITY DEFINER` — voir
/// `lineage_repository.dart`). Aperçu minimal volontaire (docs/01 §5.4.1) :
/// jamais le nom du moqaddam ni la zawiya de l'autre disciple, seulement de
/// quoi le reconnaître.
class LineageMatch {
  const LineageMatch({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.transmissionYear,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int? transmissionYear;

  factory LineageMatch.fromRow(Map<String, dynamic> row) {
    return LineageMatch(
      userId: row['user_id'] as String,
      displayName: row['display_name'] as String,
      avatarUrl: row['avatar_url'] as String?,
      transmissionYear: row['transmission_year'] as int?,
    );
  }
}

enum LineageConnectionStatus { pending, accepted, declined }

LineageConnectionStatus _connectionStatusFromDb(String value) {
  return LineageConnectionStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => LineageConnectionStatus.pending,
  );
}

/// Une demande de mise en relation — `otherUserName` résolu séparément via
/// `profiles` (pas de FK directe, même limite que
/// `mouqaddam_models.SponsorshipRequest`).
class LineageConnectionRequest {
  const LineageConnectionRequest({
    required this.id,
    required this.requesterId,
    required this.recipientId,
    required this.status,
    required this.createdAt,
    this.otherUserName,
  });

  final String id;
  final String requesterId;
  final String recipientId;
  final LineageConnectionStatus status;
  final DateTime createdAt;
  final String? otherUserName;

  LineageConnectionRequest withOtherUserName(String? name) {
    return LineageConnectionRequest(
      id: id,
      requesterId: requesterId,
      recipientId: recipientId,
      status: status,
      createdAt: createdAt,
      otherUserName: name,
    );
  }

  factory LineageConnectionRequest.fromRow(Map<String, dynamic> row) {
    return LineageConnectionRequest(
      id: row['id'] as String,
      requesterId: row['requester_id'] as String,
      recipientId: row['recipient_id'] as String,
      status: _connectionStatusFromDb(row['status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }
}
