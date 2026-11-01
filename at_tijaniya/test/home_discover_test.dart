// Refonte de l'accueil du 2026-11-01 : carrousel « Comprendre et rattraper ».
// Choix des cartes (logique pure) et affichage (réponse entière dans la
// feuille, filtres, carte contextuelle). Textes repris des lignes validées en
// base le 2026-11-01.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/core/date/current_day.dart';
import 'package:at_tijaniya/features/figures/presentation/figures_providers.dart';
import 'package:at_tijaniya/features/home/domain/home_discover.dart';
import 'package:at_tijaniya/features/home/presentation/home_screen.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_providers.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/features/tariqa_benefits/domain/tariqa_benefits_models.dart';
import 'package:at_tijaniya/features/tariqa_conditions/domain/tariqa_condition_models.dart';
import 'package:at_tijaniya/features/wird/data/wirds_content.dart';
import 'package:at_tijaniya/features/wird/domain/wird_repair_models.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

import 'home_test_overrides.dart';

Map<String, dynamic> _case(int order, String situationFr, String situationAr, String actionFr,
        {String wird = 'all', String kind = 'erreur', String status = 'valide'}) =>
    {
      'id': 'c$order',
      'order_index': order,
      'wird': wird,
      'kind': kind,
      'situation_fr': situationFr,
      'situation_ar': situationAr,
      'action_fr': actionFr,
      'action_ar': 'جواب $order',
      'source_fr': 'al-Durra al-Kharida, t. 4, p. 9',
      'source_ar': 'الدرة الخريدة',
      'content_status': status,
    };

Map<String, dynamic> _quick(String wird, String fr, String ar) => {
      'id': 'n$wird',
      'wird': wird,
      'note_type': 'quick_answer',
      'order_index': 1,
      'text_fr': fr,
      'text_ar': ar,
      'content_status': 'valide',
    };

final _repair = WirdRepairContent(
  cases: [
    _case(1, 'Doute sur le nombre de répétitions', 'الشك في عدد الأذكار',
        "On construit sur le nombre le plus bas, celui dont on est sûr. Une fois le wird terminé, on répare par 100 fois « Astaghfirou-llah » avec l'intention de réparer."),
    _case(2, 'Absence de présence du cœur (houdour)', 'غياب الحضور', 'Réponse 2'),
    _case(3, 'Cas réservé à la Wazifa', 'حالة الوظيفة', 'Réponse 3', wird: 'wazifa', kind: 'manque'),
    _case(4, 'Brouillon jamais montré', 'مسودة', 'Réponse 4', status: 'brouillon'),
  ].map(WirdRepairCase.fromRow).toList(),
  notes: [
    _quick('lazim', 'Se rattrape, sans tarder', 'يُقضى عاجلا'),
    _quick('wazifa', 'Se rattrape', 'تُقضى'),
    _quick('hadra', 'Ne se rattrape pas', 'لا تُقضى'),
  ].map(WirdRepairNote.fromRow).toList(),
);

final _conditions = [
  TariqaCondition.fromRow(const {
    'id': 'k1',
    'order_index': 5,
    'category': 'compagnonnage',
    'text_fr': "Aimer le Cheikh d'un amour constant et sans interruption jusqu'à la mort, ainsi que son khalife après lui.",
    'text_ar': 'دوام محبة الشيخ بلا انقطاع الى الممات ،و خليفة الشيخ من بعده',
  }),
];

TariqaBenefitsContent _benefits() => TariqaBenefitsContent.fromRows(
      sectionRows: const [
        {'slug': 'wazifa', 'order_index': 1, 'number': '3', 'title_fr': 'La Wazifa', 'content_status': 'valide'},
        {'slug': 'hadra', 'order_index': 2, 'number': '4', 'title_fr': 'La Hadratou-l-Jouma', 'content_status': 'valide'},
      ],
      cardRows: const [
        {
          'section_slug': 'wazifa',
          'order_index': 1,
          'title_fr': "Effacer les fautes d'une Wazifa à l'autre",
          'blocks_fr': [],
          'content_status': 'valide',
        },
        {
          'section_slug': 'hadra',
          'order_index': 2,
          'title_fr': 'La présence du Prophète ﷺ et un bien immense',
          'blocks_fr': [],
          'content_status': 'valide',
        },
      ],
      isArabic: false,
    );

final _wazifa = validatedWirds.firstWhere((w) => w.id == 'wazifa');

void main() {
  final sunday = DateTime(2026, 11, 1, 17);
  final friday = DateTime(2026, 11, 6, 10);

  group('buildForYouCards', () {
    final sources = DiscoverSources(repair: _repair, conditions: _conditions, benefits: _benefits(), isArabic: false);

    test('wird d\'hier non marqué : sa réponse courte en tête, puis un cas de ce wird ou commun', () {
      final cards = buildForYouCards(sources, now: sunday, unmarkedYesterday: [_wazifa]);
      final first = cards.first as DiscoverContextCard;
      expect(first.wird, RepairWird.wazifa);
      expect(first.answer.textFr, 'Se rattrape');
      expect(first.reason, DiscoverContextReason.unmarkedYesterday);
      final cases = cards.whereType<DiscoverCaseCard>().map((c) => c.repairCase.wird);
      expect(cases, everyElement(anyOf(RepairWird.wazifa, RepairWird.all)));
    });

    test('rien de manqué : pas de carte contextuelle ; les quatre familles sont mélangées', () {
      final cards = buildForYouCards(sources, now: sunday);
      expect(cards.whereType<DiscoverContextCard>(), isEmpty);
      expect(cards.whereType<DiscoverCaseCard>(), hasLength(2));
      expect(cards.whereType<DiscoverConditionCard>(), hasLength(1));
      expect(cards.whereType<DiscoverBenefitCard>(), hasLength(1));
    });

    test('vendredi, Hadratou-l-Jouma à faire : « Ne se rattrape pas » et un bienfait de la Hadra', () {
      final cards = buildForYouCards(sources, now: friday, hadraPendingToday: true);
      final first = cards.first as DiscoverContextCard;
      expect(first.wird, RepairWird.hadra);
      expect(first.reason, DiscoverContextReason.friday);
      expect(cards.whereType<DiscoverBenefitCard>().single.card.sectionSlug, 'hadra');
    });

    test('vendredi, Hadratou-l-Jouma déjà faite : pas de rappel', () {
      final cards = buildForYouCards(sources, now: friday);
      expect(cards.whereType<DiscoverContextCard>(), isEmpty);
    });

    test('un brouillon n\'est jamais retenu', () {
      for (var day = 0; day < 10; day++) {
        final cards = buildFamilyCards(sources, DiscoverFamily.repair, now: sunday.add(Duration(days: day)));
        expect(cards.map((c) => (c as DiscoverCaseCard).repairCase.isValid), everyElement(isTrue));
      }
    });

    test('en arabe : pas de bienfait tant que leur texte arabe n\'existe pas', () {
      final arabic = DiscoverSources(repair: _repair, conditions: _conditions, benefits: _benefits(), isArabic: true);
      expect(buildForYouCards(arabic, now: sunday).whereType<DiscoverBenefitCard>(), isEmpty);
      expect(buildFamilyCards(arabic, DiscoverFamily.benefit, now: sunday), isEmpty);
    });

    test('rotation : identique toute la journée, différente le lendemain', () {
      String firstCase(DateTime now) =>
          buildForYouCards(sources, now: now).whereType<DiscoverCaseCard>().first.repairCase.id;
      expect(firstCase(DateTime(2026, 11, 1, 6)), firstCase(DateTime(2026, 11, 1, 23)));
      expect(firstCase(DateTime(2026, 11, 1)), isNot(firstCase(DateTime(2026, 11, 2))));
    });

    test('sources absentes (hors ligne) : aucune carte, sans erreur', () {
      expect(buildForYouCards(const DiscoverSources(isArabic: false), now: sunday, unmarkedYesterday: [_wazifa]), isEmpty);
    });
  });

  group('affichage', () {
    Widget app({Locale locale = const Locale('fr'), Map<String, Object> prefs = const {}}) {
      SharedPreferences.setMockInitialValues(prefs);
      return ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(() => sunday),
          currentUserIdProvider.overrideWithValue(null),
          upcomingEventsProvider.overrideWith((ref) async => const []),
          featuredFigureProvider.overrideWith((ref) async => null),
          ...homeContentOverrides(repair: _repair, conditions: _conditions),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('fr'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: HomeScreen()),
        ),
      );
    }

    testWidgets('Wazifa d\'hier non marquée : carte de rattrapage en tête du carrousel', (tester) async {
      await tester.pumpWidget(app(prefs: {
        'wird_completions_lazim::guest': ['2026-10-30', '2026-10-31'],
        'wird_completions_wazifa::guest': ['2026-10-30'],
      }));
      await tester.pumpAndSettle();
      expect(find.text('WAZIFA : RIEN DE MARQUÉ HIER'), findsOneWidget);
      expect(find.text('Se rattrape'), findsOneWidget);
      expect(find.text('تُقضى'), findsOneWidget);
    });

    testWidgets('la réponse s\'ouvre en entier, avec sa source', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final card = find.text('Voir la réponse  →').first;
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.textContaining('Source : al-Durra al-Kharida'), findsOneWidget);
      expect(find.text('Ouvrir la page complète'), findsOneWidget);
    });

    testWidgets('filtre « Conditions » : seules les conditions restent', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conditions'));
      await tester.pumpAndSettle();
      expect(find.text('CONDITION · COMPAGNONNAGE ENVERS LE CHEIKH'), findsOneWidget);
      expect(find.text('Voir la réponse  →'), findsNothing);
    });

    testWidgets('en arabe : la situation est donnée en arabe seulement', (tester) async {
      await tester.pumpWidget(app(locale: const Locale('ar')));
      await tester.pumpAndSettle();
      expect(find.textContaining(RegExp('Doute|Absence')), findsNothing);
      expect(find.text('الشك في عدد الأذكار').evaluate().length + find.text('غياب الحضور').evaluate().length,
          greaterThan(0));
    });
  });
}
