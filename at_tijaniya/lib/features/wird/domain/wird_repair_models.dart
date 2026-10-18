/// Modèles de « Rattraper son wird » : que faire après un oubli, une erreur ou
/// une interruption du Lazim, de la Wazifa ou de la Hadratou-l-Jouma.
///
/// IMPORTANT (CLAUDE.md — contenu religieux ; docs/01-perimetre-fonctionnel.md
/// § 8) : contrairement au guide des wirds (`wirds_content.dart`, corpus
/// validé embarqué dans l'app), ce contenu vient des tables Supabase
/// `wird_repair_cases` et `wird_repair_notes` (migration
/// `2026-10-17_wird_repair.sql`). Chaque ligne naît en `brouillon` et n'est
/// servie aux disciples qu'une fois passée à `valide` après relecture par le
/// moqaddam référent. Rien ici ne doit être complété ou reformulé côté app :
/// on affiche les lignes telles qu'elles sont en base.
///
/// Le français et l'arabe vivent dans la même ligne (`*_fr` / `*_ar`), comme
/// pour `tariqa_conditions` : l'écran choisit la colonne selon la langue de
/// l'interface, via les accesseurs `…For(isArabic)`.
library;

/// Wird concerné par un cas ou une note. [all] : règle commune, affichée
/// quel que soit le wird choisi par le disciple.
enum RepairWird { all, lazim, wazifa, hadra }

/// Type de situation, qui sert de filtre dans l'écran (« Que s'est-il
/// passé ? »). Les valeurs en base sont les noms de l'enum.
enum RepairKind { manque, erreur, interruption, empechement }

/// Nature d'une note : le texte qui encadre les cas d'un wird.
enum RepairNoteType { intro, quickAnswer, timing, warning, askMoqaddam }

RepairWird _wirdFromDb(String value) => RepairWird.values.byName(value);

RepairKind _kindFromDb(String value) => RepairKind.values.byName(value);

RepairNoteType _noteTypeFromDb(String value) {
  return switch (value) {
    'intro' => RepairNoteType.intro,
    'quick_answer' => RepairNoteType.quickAnswer,
    'timing' => RepairNoteType.timing,
    'warning' => RepairNoteType.warning,
    'ask_moqaddam' => RepairNoteType.askMoqaddam,
    // La contrainte `check` de la table interdit toute autre valeur : un
    // échec ici signale une migration non reportée dans l'app.
    _ => throw ArgumentError.value(value, 'note_type', 'type de note inconnu'),
  };
}

bool _isValid(Map<String, dynamic> row) => row['content_status'] == 'valide';

/// Un cas : une situation et ce qu'il faut faire, avec sa source.
class WirdRepairCase {
  const WirdRepairCase({
    required this.id,
    required this.orderIndex,
    required this.wird,
    required this.kind,
    required this.situationFr,
    required this.situationAr,
    required this.actionFr,
    required this.actionAr,
    this.sourceFr,
    this.sourceAr,
    required this.isValid,
  });

  final String id;
  final int orderIndex;
  final RepairWird wird;
  final RepairKind kind;
  final String situationFr;
  final String situationAr;
  final String actionFr;
  final String actionAr;
  final String? sourceFr;
  final String? sourceAr;

  /// `false` pour un brouillon — visible seulement par l'admin (RLS).
  final bool isValid;

  String situationFor(bool isArabic) => isArabic ? situationAr : situationFr;
  String actionFor(bool isArabic) => isArabic ? actionAr : actionFr;
  String? sourceFor(bool isArabic) => isArabic ? sourceAr : sourceFr;

  factory WirdRepairCase.fromRow(Map<String, dynamic> row) {
    return WirdRepairCase(
      id: row['id'] as String,
      orderIndex: row['order_index'] as int,
      wird: _wirdFromDb(row['wird'] as String),
      kind: _kindFromDb(row['kind'] as String),
      situationFr: row['situation_fr'] as String,
      situationAr: row['situation_ar'] as String,
      actionFr: row['action_fr'] as String,
      actionAr: row['action_ar'] as String,
      sourceFr: row['source_fr'] as String?,
      sourceAr: row['source_ar'] as String?,
      isValid: _isValid(row),
    );
  }
}

/// Une note : introduction, réponse rapide, horaire (avec un libellé), mise
/// en garde ou question à poser au moqaddam.
class WirdRepairNote {
  const WirdRepairNote({
    required this.id,
    required this.wird,
    required this.type,
    required this.orderIndex,
    this.labelFr,
    this.labelAr,
    required this.textFr,
    required this.textAr,
    required this.isValid,
  });

  final String id;
  final RepairWird wird;
  final RepairNoteType type;
  final int orderIndex;
  final String? labelFr;
  final String? labelAr;
  final String textFr;
  final String textAr;
  final bool isValid;

  String? labelFor(bool isArabic) => isArabic ? labelAr : labelFr;
  String textFor(bool isArabic) => isArabic ? textAr : textFr;

  /// Réponse rapide négative (« Ne se rattrape pas ») : l'écran la dessine
  /// autrement que « Se rattrape », pour qu'on ne confonde pas les deux d'un
  /// coup d'œil (audit de présentation du 2026-10-18). Lue sur le texte
  /// français, qui existe toujours, plutôt que sur le wird : c'est le contenu
  /// validé qui décide de la réponse, pas l'app.
  bool get isNegativeAnswer => type == RepairNoteType.quickAnswer && textFr.trimLeft().startsWith('Ne ');

  factory WirdRepairNote.fromRow(Map<String, dynamic> row) {
    return WirdRepairNote(
      id: row['id'] as String,
      wird: _wirdFromDb(row['wird'] as String),
      type: _noteTypeFromDb(row['note_type'] as String),
      orderIndex: row['order_index'] as int,
      labelFr: row['label_fr'] as String?,
      labelAr: row['label_ar'] as String?,
      textFr: row['text_fr'] as String,
      textAr: row['text_ar'] as String,
      isValid: _isValid(row),
    );
  }
}

/// Tout le contenu de la page, avec les règles de sélection de l'écran.
/// Gardées ici, hors des widgets, pour être testées sans interface.
class WirdRepairContent {
  WirdRepairContent({required List<WirdRepairCase> cases, required List<WirdRepairNote> notes})
    : cases = [...cases]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)),
      notes = [...notes]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

  final List<WirdRepairCase> cases;
  final List<WirdRepairNote> notes;

  /// Sans aucun cas, la page n'a rien à dire : la carte d'accès est masquée
  /// (cas d'un disciple tant que rien n'est validé).
  bool get isEmpty => cases.isEmpty;

  /// Vrai si l'admin voit au moins une ligne encore en brouillon : l'écran
  /// l'en avertit, pour qu'il ne prenne pas sa vue pour celle des disciples.
  bool get hasDrafts => cases.any((c) => !c.isValid) || notes.any((n) => !n.isValid);

  /// Les cas à montrer pour [wird] : les siens et les règles communes
  /// ([RepairWird.all]), dans l'ordre de la base — les règles communes
  /// d'abord, puisqu'elles portent les plus petits `order_index`. [kind] nul :
  /// tous les types.
  List<WirdRepairCase> casesFor(RepairWird wird, {RepairKind? kind}) {
    return cases
        .where((c) => c.wird == wird || c.wird == RepairWird.all)
        .where((c) => kind == null || c.kind == kind)
        .toList();
  }

  /// Les cas rattachés exactement à [wird], sans les règles communes — pour
  /// la lecture complète, section par section, et pour la vue par situation,
  /// qui montre d'abord les cas du wird choisi puis les règles communes.
  /// [kind] nul : tous les types.
  List<WirdRepairCase> casesOnlyFor(RepairWird wird, {RepairKind? kind}) =>
      cases.where((c) => c.wird == wird && (kind == null || c.kind == kind)).toList();

  List<WirdRepairNote> notesFor(RepairWird wird, RepairNoteType type) {
    return notes.where((n) => n.wird == wird && n.type == type).toList();
  }

  WirdRepairNote? noteFor(RepairWird wird, RepairNoteType type) {
    final found = notesFor(wird, type);
    return found.isEmpty ? null : found.first;
  }
}
