/// Modèles du workflow "Statut Mouqaddam vérifié" (§5.4.2) : "Devenir
/// Mouqaddam", "Demandes de parrainage", "Rechercher un parrain", "Ma
/// silsila d'ijaza".
///
/// RAPPEL IMPÉRATIF (CLAUDE.md) : ce statut n'est jamais auto-proclamé — il
/// ne peut être obtenu que par parrainage accepté (`respond_to_sponsorship`,
/// fonction Postgres `SECURITY DEFINER`) ou par validation manuelle du
/// porteur de projet. Aucun modèle ni écran ici ne permet de définir
/// `MouqaddamVerificationStatus.verified` autrement qu'en le lisant depuis
/// la base.
library;

enum MouqaddamVerificationStatus { none, pending, verified, revoked }

MouqaddamVerificationStatus _statusFromDb(String value) {
  return MouqaddamVerificationStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => MouqaddamVerificationStatus.none,
  );
}

class MouqaddamStatus {
  const MouqaddamStatus({required this.status, required this.isFounder, this.verifiedAt});

  final MouqaddamVerificationStatus status;
  final bool isFounder;
  final DateTime? verifiedAt;

  bool get isVerified => status == MouqaddamVerificationStatus.verified;

  factory MouqaddamStatus.fromRow(Map<String, dynamic> row) {
    return MouqaddamStatus(
      status: _statusFromDb(row['status'] as String),
      isFounder: row['is_founder'] as bool,
      verifiedAt: row['verified_at'] != null ? DateTime.parse(row['verified_at'] as String) : null,
    );
  }
}

enum SponsorshipRequestStatus { pending, accepted, rejected }

SponsorshipRequestStatus _requestStatusFromDb(String value) {
  return SponsorshipRequestStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => SponsorshipRequestStatus.pending,
  );
}

/// Une demande de parrainage — vue côté candidat ("Devenir Mouqaddam") ou
/// côté parrain ("Demandes de parrainage"). `candidateName`/`sponsorName`
/// sont résolus séparément via `profiles` : `mouqaddam_sponsorships` n'a pas
/// de FK directe vers `profiles` (même limite que `posts.author_user_id`,
/// cf. `community_models.dart`), donc jamais embarqués par PostgREST.
class SponsorshipRequest {
  const SponsorshipRequest({
    required this.id,
    required this.candidateUserId,
    required this.sponsorUserId,
    this.ijazaYear,
    required this.status,
    required this.requestedAt,
    this.candidateName,
    this.sponsorName,
  });

  final String id;
  final String candidateUserId;
  final String sponsorUserId;
  final int? ijazaYear;
  final SponsorshipRequestStatus status;
  final DateTime requestedAt;
  final String? candidateName;
  final String? sponsorName;

  SponsorshipRequest withNames({String? candidateName, String? sponsorName}) {
    return SponsorshipRequest(
      id: id,
      candidateUserId: candidateUserId,
      sponsorUserId: sponsorUserId,
      ijazaYear: ijazaYear,
      status: status,
      requestedAt: requestedAt,
      candidateName: candidateName ?? this.candidateName,
      sponsorName: sponsorName ?? this.sponsorName,
    );
  }

  factory SponsorshipRequest.fromRow(Map<String, dynamic> row) {
    return SponsorshipRequest(
      id: row['id'] as String,
      candidateUserId: row['candidate_user_id'] as String,
      sponsorUserId: row['sponsor_user_id'] as String,
      ijazaYear: row['ijaza_year'] as int?,
      status: _requestStatusFromDb(row['status'] as String),
      requestedAt: DateTime.parse(row['requested_at'] as String).toLocal(),
    );
  }
}

/// Un mouqaddam vérifié "disponible comme parrain"
/// (`search_available_sponsors`, fonction `SECURITY DEFINER` — ne renvoie
/// jamais que ces trois champs, jamais la silsila ni aucune autre donnée).
class AvailableSponsor {
  const AvailableSponsor({required this.userId, required this.displayName, this.zawiyaName});

  final String userId;
  final String displayName;
  final String? zawiyaName;

  factory AvailableSponsor.fromRow(Map<String, dynamic> row) {
    return AvailableSponsor(
      userId: row['user_id'] as String,
      displayName: row['display_name'] as String,
      zawiyaName: row['zawiya_name'] as String?,
    );
  }
}

/// Un maillon de la silsila d'ijaza (`get_ijaza_chain`) — automatique
/// (`isManual = false` : `userId` renseigné, nom résolu séparément via
/// `profiles`) ou complément manuel en texte libre au-delà de l'app
/// (`isManual = true` : `nameText` déjà en base, saisi par le dernier
/// mouqaddam connu de la chaîne).
class IjazaChainLink {
  const IjazaChainLink({
    required this.depth,
    this.userId,
    this.ijazaYear,
    required this.isManual,
    this.nameText,
    this.yearText,
    this.resolvedName,
    this.isUltimateSource = false,
  });

  final int depth;
  final String? userId;
  final int? ijazaYear;
  final bool isManual;
  final String? nameText;
  final String? yearText;
  final String? resolvedName;

  /// Coché explicitement par le mouqaddam qui a saisi ce maillon manuel
  /// ("Cette personne est-elle Cheikh Ahmed Tijani, à l'origine de la
  /// tarikha ?") — option A retenue dans `docs/08-spec-animation-silsila.md`
  /// §6 : jamais déduit d'une comparaison de texte sur le nom, fragile
  /// aux variantes orthographiques déjà documentées comme risque. Toujours
  /// `false` pour un maillon automatique (`isManual = false`).
  final bool isUltimateSource;

  String displayName(String fallback) => isManual ? (nameText ?? fallback) : (resolvedName ?? fallback);

  IjazaChainLink withResolvedName(String? resolvedName) {
    return IjazaChainLink(
      depth: depth,
      userId: userId,
      ijazaYear: ijazaYear,
      isManual: isManual,
      nameText: nameText,
      yearText: yearText,
      resolvedName: resolvedName,
      isUltimateSource: isUltimateSource,
    );
  }

  factory IjazaChainLink.fromRow(Map<String, dynamic> row) {
    return IjazaChainLink(
      depth: row['depth'] as int,
      userId: row['user_id'] as String?,
      ijazaYear: row['ijaza_year'] as int?,
      isManual: row['is_manual'] as bool,
      nameText: row['name_text'] as String?,
      yearText: row['year_text'] as String?,
      isUltimateSource: row['is_ultimate_source'] as bool? ?? false,
    );
  }
}
