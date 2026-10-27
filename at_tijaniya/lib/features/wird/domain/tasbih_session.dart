/// Modèle d'état du Tasbih digital (écran "Tasbih digital", P0 —
/// docs/03-architecture-ecrans.md : "Tape manuel, reconnaissance vocale,
/// reprise de session").
///
/// Persisté sur l'appareil (voir `tasbih_session_store.dart`) pour permettre
/// la reprise de session, comme le reste de la pratique (la politique de
/// confidentialité l'annonce). Le schéma `tasbih_sessions` de
/// `database/schema.sql` (mode manual/voice, current_count, target_count,
/// wird_id, step_id) reste prévu pour une éventuelle synchronisation, non
/// décidée.
library;

enum TasbihMode { manual, voice }

class TasbihSession {
  const TasbihSession({
    required this.wirdId,
    required this.pillarIndex,
    required this.currentCount,
    required this.mode,
    required this.updatedAt,
    this.useAlternative = false,
  });

  factory TasbihSession.initial(String wirdId) => TasbihSession(
        wirdId: wirdId,
        pillarIndex: 0,
        currentCount: 0,
        mode: TasbihMode.manual,
        updatedAt: DateTime.now(),
      );

  final String wirdId;

  /// Index du pilier en cours dans `Wird.pillars`.
  final int pillarIndex;

  /// Compte courant pour ce pilier (repart à 0 à chaque changement de pilier).
  final int currentCount;

  final TasbihMode mode;

  final DateTime updatedAt;

  /// `true` quand le disciple a choisi de réciter [WirdPillar.alternative]
  /// à la place du pilier courant (ex. 20 Salatoul Fatihi plutôt que
  /// Jawharatoul Kamal) — remis à `false` à chaque changement de pilier.
  final bool useAlternative;

  TasbihSession copyWith({
    int? pillarIndex,
    int? currentCount,
    TasbihMode? mode,
    bool? useAlternative,
  }) {
    return TasbihSession(
      wirdId: wirdId,
      pillarIndex: pillarIndex ?? this.pillarIndex,
      currentCount: currentCount ?? this.currentCount,
      mode: mode ?? this.mode,
      updatedAt: DateTime.now(),
      useAlternative: useAlternative ?? this.useAlternative,
    );
  }

  Map<String, dynamic> toJson() => {
        'wirdId': wirdId,
        'pillarIndex': pillarIndex,
        'currentCount': currentCount,
        'mode': mode.name,
        'updatedAt': updatedAt.toIso8601String(),
        'useAlternative': useAlternative,
      };

  static TasbihSession? tryFromJson(Map<String, dynamic> json) {
    try {
      return TasbihSession(
        wirdId: json['wirdId'] as String,
        pillarIndex: json['pillarIndex'] as int,
        currentCount: json['currentCount'] as int,
        mode: TasbihMode.values.byName(json['mode'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        // Absent des sessions sauvegardées avant l'ajout de ce champ :
        // retombe sur `false` plutôt que de faire échouer la reprise.
        useAlternative: json['useAlternative'] as bool? ?? false,
      );
    } catch (_) {
      // Format inattendu (ancienne version du store, corruption locale...) :
      // on repart sur une session neuve plutôt que de planter l'écran.
      return null;
    }
  }
}
