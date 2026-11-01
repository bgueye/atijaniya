/// Carrousel « Comprendre et rattraper » de l'accueil (refonte du
/// 2026-11-01, proposition B retenue par le porteur de projet) : quelles
/// cartes montrer, dans quel ordre, à partir du contenu des trois pages de
/// l'onglet Wird — « Rattraper son wird », « Conditions de la Tariqa » et
/// « Bienfaits de la Tijaniyya ».
///
/// IMPORTANT (contenu religieux, `CLAUDE.md`) : ce fichier ne produit aucun
/// texte. Il choisit des lignes déjà validées en base et les rend telles
/// quelles ; un brouillon (visible de l'admin seul sur les pages complètes)
/// n'est jamais retenu ici, l'accueil étant la vitrine des disciples.
///
/// Logique pure, sans Riverpod ni widget, pour être testée seule — même
/// principe que `home_dashboard.dart`.
library;

import '../../tariqa_benefits/domain/tariqa_benefits_models.dart';
import '../../tariqa_conditions/domain/tariqa_condition_models.dart';
import '../../wird/domain/wird_models.dart';
import '../../wird/domain/wird_repair_models.dart';

enum DiscoverFamily { repair, condition, benefit }

/// Pourquoi une carte de rattrapage est mise en tête du carrousel.
enum DiscoverContextReason {
  /// Le wird quotidien de la veille n'a pas été marqué.
  unmarkedYesterday,

  /// Vendredi, Hadratou-l-Jouma pas encore faite.
  friday,
}

sealed class DiscoverCard {
  const DiscoverCard();

  DiscoverFamily get family;
}

/// Carte contextuelle : la réponse courte validée (`quick_answer`) pour un
/// wird, par exemple « Se rattrape » ou « Ne se rattrape pas ».
class DiscoverContextCard extends DiscoverCard {
  const DiscoverContextCard({required this.wird, required this.answer, required this.reason});

  final RepairWird wird;
  final WirdRepairNote answer;
  final DiscoverContextReason reason;

  @override
  DiscoverFamily get family => DiscoverFamily.repair;
}

class DiscoverCaseCard extends DiscoverCard {
  const DiscoverCaseCard(this.repairCase);

  final WirdRepairCase repairCase;

  @override
  DiscoverFamily get family => DiscoverFamily.repair;
}

class DiscoverConditionCard extends DiscoverCard {
  const DiscoverConditionCard(this.condition);

  final TariqaCondition condition;

  @override
  DiscoverFamily get family => DiscoverFamily.condition;
}

class DiscoverBenefitCard extends DiscoverCard {
  const DiscoverBenefitCard({required this.card, required this.sectionTitle});

  final BenefitCard card;
  final String sectionTitle;

  @override
  DiscoverFamily get family => DiscoverFamily.benefit;
}

/// Wird du corpus validé → wird de « Rattraper son wird ».
RepairWird? repairWirdOf(Wird wird) => switch (wird.id) {
      'lazim' => RepairWird.lazim,
      'wazifa' => RepairWird.wazifa,
      'hadratou_jouma' => RepairWird.hadra,
      _ => null,
    };

/// Numéro du jour civil, pour une rotation qui change chaque jour et reste la
/// même toute la journée (même principe que la figure de la semaine).
int discoverDayIndex(DateTime now) => DateTime.utc(now.year, now.month, now.day).difference(DateTime.utc(2024)).inDays;

/// [count] éléments de [items] à partir de la position du jour, en boucle,
/// sans doublon.
List<T> rotate<T>(List<T> items, int dayIndex, int count) {
  if (items.isEmpty) return const [];
  final n = count.clamp(0, items.length);
  final start = dayIndex % items.length;
  return [for (var i = 0; i < n; i++) items[(start + i) % items.length]];
}

/// Le contenu disponible, chaque source pouvant manquer (chargement, échec
/// réseau) sans empêcher les autres de s'afficher.
class DiscoverSources {
  const DiscoverSources({this.repair, this.conditions, this.benefits, required this.isArabic});

  final WirdRepairContent? repair;
  final List<TariqaCondition>? conditions;

  /// Construit en français (`TariqaBenefitsContent.fromRows(isArabic: false)`).
  final TariqaBenefitsContent? benefits;
  final bool isArabic;

  List<WirdRepairCase> get validCases => [for (final c in repair?.cases ?? const <WirdRepairCase>[]) if (c.isValid) c];

  List<TariqaCondition> get validConditions => [
        for (final c in conditions ?? const <TariqaCondition>[])
          if (!isArabic || (c.textAr?.trim().isNotEmpty ?? false)) c,
      ];

  /// Les bienfaits n'existent qu'en français (vérifié en base le 2026-11-01) :
  /// dans l'app en arabe, ils restent hors du carrousel tant que leur texte
  /// arabe n'est pas saisi et validé, plutôt qu'une carte en français au
  /// milieu de cartes en arabe. La page complète, elle, reste accessible.
  List<DiscoverBenefitCard> get validBenefits {
    final content = benefits;
    if (content == null || isArabic) return const [];
    return [
      for (final section in content.sections)
        if (!section.isDraft)
          for (final card in section.cards)
            if (!card.isDraft && (card.title?.trim().isNotEmpty ?? false))
              DiscoverBenefitCard(card: card, sectionTitle: section.title),
    ];
  }

  WirdRepairNote? quickAnswer(RepairWird wird) {
    final note = repair?.noteFor(wird, RepairNoteType.quickAnswer);
    return note != null && note.isValid ? note : null;
  }
}

/// Cartes de l'onglet « Pour vous », dans l'ordre :
/// 1. une carte de rattrapage par wird quotidien non marqué la veille
///    ([unmarkedYesterday]), puis celle de Hadratou-l-Jouma le vendredi
///    tant qu'elle n'est pas faite ([hadraPendingToday]) ;
/// 2. un cas de rattrapage (de préférence du wird de la carte 1) ;
/// 3. un bienfait (de la section Hadra le vendredi) ;
/// 4. une condition ;
/// 5. un second cas.
List<DiscoverCard> buildForYouCards(
  DiscoverSources sources, {
  required DateTime now,
  List<Wird> unmarkedYesterday = const [],
  bool hadraPendingToday = false,
}) {
  final day = discoverDayIndex(now);
  final cards = <DiscoverCard>[];

  RepairWird? preferred;
  for (final wird in unmarkedYesterday) {
    final repairWird = repairWirdOf(wird);
    if (repairWird == null) continue;
    final answer = sources.quickAnswer(repairWird);
    if (answer == null) continue;
    preferred ??= repairWird;
    cards.add(DiscoverContextCard(wird: repairWird, answer: answer, reason: DiscoverContextReason.unmarkedYesterday));
  }
  final isFriday = now.weekday == DateTime.friday;
  if (isFriday && hadraPendingToday) {
    final answer = sources.quickAnswer(RepairWird.hadra);
    if (answer != null) {
      cards.add(DiscoverContextCard(wird: RepairWird.hadra, answer: answer, reason: DiscoverContextReason.friday));
    }
  }

  final allCases = sources.validCases;
  final preferredCases =
      preferred == null ? allCases : [for (final c in allCases) if (c.wird == preferred || c.wird == RepairWird.all) c];
  final cases = rotate(preferredCases.isNotEmpty ? preferredCases : allCases, day, 2);

  final benefits = sources.validBenefits;
  final fridayBenefits = [for (final b in benefits) if (b.card.sectionSlug == 'hadra') b];
  final benefit = rotate(isFriday && fridayBenefits.isNotEmpty ? fridayBenefits : benefits, day, 1);

  final condition = rotate(sources.validConditions, day, 1);

  if (cases.isNotEmpty) cards.add(DiscoverCaseCard(cases.first));
  cards.addAll(benefit);
  cards.addAll(condition.map(DiscoverConditionCard.new));
  if (cases.length > 1) cards.add(DiscoverCaseCard(cases[1]));
  return cards;
}

/// Cartes d'une seule famille (filtres « Rattraper », « Conditions »,
/// « Bienfaits ») : [count] éléments à partir de la position du jour.
List<DiscoverCard> buildFamilyCards(DiscoverSources sources, DiscoverFamily family, {required DateTime now, int count = 6}) {
  final day = discoverDayIndex(now);
  return switch (family) {
    DiscoverFamily.repair => rotate(sources.validCases, day, count).map(DiscoverCaseCard.new).toList(),
    DiscoverFamily.condition => rotate(sources.validConditions, day, count).map(DiscoverConditionCard.new).toList(),
    DiscoverFamily.benefit => rotate(sources.validBenefits, day, count),
  };
}
