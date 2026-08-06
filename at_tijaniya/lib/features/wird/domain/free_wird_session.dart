/// Modèle d'état du Wird libre — un compteur que le disciple paramètre
/// lui-même (nom libre + cible de répétitions), distinct des trois wirds au
/// contenu fixe et validé (`wird_models.dart`).
///
/// Pas de texte arabe/translittération/traduction ici : [label] est saisi
/// et privé au disciple, jamais publié ni suggéré par l'app — voir la
/// règle "contenu religieux" de CLAUDE.md, qui ne s'applique qu'au contenu
/// fourni par l'app elle-même.
///
/// Persisté localement (voir `free_wird_store.dart`) pour permettre la
/// reprise du compteur en cours, même principe que `TasbihSession`. Un seul
/// compteur libre en cours à la fois (pas de suffixe par id).
library;

import 'tasbih_session.dart' show TasbihMode;

class FreeWirdSession {
  const FreeWirdSession({
    required this.label,
    required this.target,
    required this.currentCount,
    required this.mode,
    required this.updatedAt,
  });

  factory FreeWirdSession.initial({required String label, required int target}) => FreeWirdSession(
        label: label,
        target: target,
        currentCount: 0,
        mode: TasbihMode.manual,
        updatedAt: DateTime.now(),
      );

  /// Nom libre de ce qui est récité (ex. "Istighfar personnel"). Peut être
  /// vide — l'écran affiche alors un intitulé générique.
  final String label;

  /// Cible de répétitions, fixée par le disciple. Toujours > 0.
  final int target;

  final int currentCount;

  final TasbihMode mode;

  final DateTime updatedAt;

  FreeWirdSession copyWith({
    int? currentCount,
    TasbihMode? mode,
  }) {
    return FreeWirdSession(
      label: label,
      target: target,
      currentCount: currentCount ?? this.currentCount,
      mode: mode ?? this.mode,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'target': target,
        'currentCount': currentCount,
        'mode': mode.name,
        'updatedAt': updatedAt.toIso8601String(),
      };

  static FreeWirdSession? tryFromJson(Map<String, dynamic> json) {
    try {
      final target = json['target'] as int;
      if (target <= 0) return null;
      return FreeWirdSession(
        label: json['label'] as String,
        target: target,
        currentCount: json['currentCount'] as int,
        mode: TasbihMode.values.byName(json['mode'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
    } catch (_) {
      // Format inattendu (ancienne version du store, corruption locale...) :
      // on repart sur un formulaire neuf plutôt que de planter l'écran.
      return null;
    }
  }
}
