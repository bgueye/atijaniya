// Onglet Zawiyas refait d'après sa maquette (`docs/maquettes/ecran-zawiyas.html`,
// 2026-11-03) : en-tête (direct, prochain rendez-vous), vue Lieux (recherche,
// types, carte schématique par pays, groupes, « Près de moi ») et vue Agenda.
// Reprend aussi les garde-fous de l'audit Zawiyas du 2026-10-25 (recherche,
// cibles de 48 dp, puces justifiées, hors ligne, arabe). Lieux, rendez-vous et
// position factices, locaux au test ; aucun réseau.

import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:at_tijaniya/core/location/location_service.dart';
import 'package:at_tijaniya/core/theme/app_colors.dart';
import 'package:at_tijaniya/features/khadara/domain/khadara_models.dart';
import 'package:at_tijaniya/features/khadara/domain/zawiyas_overview.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_providers.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_screen.dart';
import 'package:at_tijaniya/features/khadara/presentation/live_stream_providers.dart';
import 'package:at_tijaniya/features/khadara/presentation/zawiyas_widgets.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

const _zawiyas = [
  Zawiya(
    id: 'a',
    name: 'Zawiya de Médina Baye (Kaolack)',
    addressText: 'Médina Baye, Kaolack, Sénégal',
    country: 'SN',
    latitude: 14.152,
    longitude: -16.073,
  ),
  Zawiya(
    id: 'b',
    name: 'Zawiya de Ségou (Mali)',
    addressText: 'Ségou, Mali',
    country: 'ML',
    latitude: 13.43,
    longitude: -6.22,
    coordinatesApproximate: true,
  ),
  Zawiya(
    id: 'c',
    name: 'Lieu saint de test',
    kind: ZawiyaKind.holyPlace,
    addressText: 'Village de test, Sénégal',
    country: 'SN',
  ),
];

/// Sept lieux au Sénégal : au-delà de six, le groupe se replie à cinq.
final _manySenegal = [
  for (var i = 1; i <= 7; i++) Zawiya(id: 's$i', name: 'Zawiya sénégalaise $i', country: 'SN'),
  const Zawiya(id: 'm', name: 'Zawiya malienne', country: 'ML'),
];

KhadaraEvent _event(String id, String title, int inDays, {String? zawiyaId, bool approximate = false}) {
  final now = DateTime.now();
  return KhadaraEvent(
    id: id,
    zawiyaId: zawiyaId,
    zawiyaName: zawiyaId == null ? null : _zawiyas.firstWhere((z) => z.id == zawiyaId).name,
    title: title,
    type: KhadaraEventType.ziyara,
    startsAt: DateTime(now.year, now.month, now.day + inDays, 9),
    isDateApproximate: approximate,
  );
}

final _events = [
  _event('e1', 'Ziarra de Médina Baye', 10, zawiyaId: 'a'),
  _event('e2', 'Ziarra du lieu saint', 40, zawiyaId: 'c', approximate: true),
];

class _FakeLocationService extends LocationService {
  _FakeLocationService({this.failure});

  final LocationFailure? failure;

  /// Position d'exemple à Dakar, comme dans la maquette.
  static const latitude = 14.69;
  static const longitude = -17.44;
  int requests = 0;
  int appSettingsOpened = 0;

  @override
  Future<LocationResult> getCurrentPosition() async {
    requests++;
    if (failure != null) return LocationResult(failure: failure);
    return LocationResult(
      position: Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime(2026, 11, 3),
        accuracy: 100,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ),
    );
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened++;
    return true;
  }
}

// Fournisseurs surchargés : leurs valeurs par défaut appellent Supabase, non
// initialisé dans ce test. [loadError] : erreur levée par le chargement des
// lieux, à la place de la liste.
Widget _wrap({
  Locale locale = const Locale('fr'),
  double textScale = 1.0,
  Object? loadError,
  List<Zawiya> zawiyas = _zawiyas,
  List<KhadaraEvent>? events,
  List<LiveStream> live = const [],
  List<StreamReplay> replays = const [],
  bool admin = false,
  LocationService? location,
}) {
  return ProviderScope(
    overrides: [
      isAdminProvider.overrideWithValue(admin),
      canCreateEventProvider.overrideWithValue(admin),
      currentUserIdProvider.overrideWithValue(null),
      zawiyasProvider.overrideWith((ref) async {
        if (loadError != null) throw loadError;
        return zawiyas;
      }),
      upcomingEventsProvider.overrideWith((ref) async => events ?? _events),
      allLiveStreamsProvider.overrideWith((ref) async => live),
      streamReplaysProvider.overrideWith((ref) async => replays),
      zawiyaLinkCountsProvider.overrideWith(
        (ref) async => const ZawiyaLinkCounts(succession: {'a': 5}, figures: {'a': 6, 'b': 1}),
      ),
      locationServiceProvider.overrideWithValue(location ?? _FakeLocationService()),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      locale: locale,
      supportedLocales: const [Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(body: KhadaraScreen()),
    ),
  );
}

/// Nom d'un lieu dans une carte de lieu : la carte « Prochain rendez-vous »
/// et l'Agenda citent aussi le lieu, sous le titre du rendez-vous.
Finder _place(String name) => find.descendant(of: find.byType(PlaceCard), matching: find.text(name));

/// Écran haut : la liste (paresseuse) construit tout, carte comprise.
void _tall(WidgetTester tester, {double width = 412}) {
  tester.view.physicalSize = Size(width, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('en-tête', () {
    testWidgets('prochain rendez-vous : titre, lieu, compte à rebours et itinéraire', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('PROCHAIN RENDEZ-VOUS'), findsOneWidget);
      expect(find.text('Ziarra de Médina Baye'), findsOneWidget);
      expect(find.text('Dans 10 jours'), findsOneWidget);
      // Le lieu a des coordonnées : « Itinéraire » proposé.
      expect(find.text('Itinéraire'), findsOneWidget);
      expect(find.text('Voir'), findsOneWidget);
    });

    testWidgets('date approximative : « environ », la mention, et pas d\'itinéraire sans coordonnées', (tester) async {
      _tall(tester);
      await tester
          .pumpWidget(_wrap(events: [_event('e2', 'Ziarra du lieu saint', 40, zawiyaId: 'c', approximate: true)]));
      await tester.pumpAndSettle();

      expect(find.text('Dans environ 40 jours'), findsOneWidget);
      expect(find.text('Date approximative'), findsOneWidget);
      expect(find.text('Itinéraire'), findsNothing);
    });

    testWidgets('le bandeau du direct n\'apparaît que pendant un direct', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Regarder'), findsNothing);
    });

    testWidgets('pendant un direct : bandeau avec son titre et « Regarder »', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap(live: const [
        LiveStream(
          id: 'l1',
          eventTitle: 'Ziarra générale',
          sourceType: LiveStreamSourceType.youtube,
          status: LiveStreamStatus.live,
        ),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('En direct · Ziarra générale'), findsOneWidget);
      expect(find.text('Regarder'), findsOneWidget);
    });

    testWidgets('deux vues, Lieux par défaut, avec leur nombre', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('Lieux'), findsOneWidget);
      expect(find.text('Agenda'), findsOneWidget);
      // Vue Lieux ouverte : la recherche est là.
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('Lieux', () {
    testWidgets('groupés par pays, du plus fourni au moins fourni, avec ce que chaque lieu contient', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final senegal = tester.getTopLeft(find.text('Sénégal'));
      final mali = tester.getTopLeft(find.text('Mali'));
      expect(senegal.dy, lessThan(mali.dy));
      expect(find.text('2 lieux'), findsOneWidget);
      expect(find.text('1 lieu'), findsOneWidget);
      expect(find.text('1 rendez-vous à venir'), findsNWidgets(2));
      expect(find.text('Succession · 5'), findsOneWidget);
      expect(find.text('6 figures'), findsOneWidget);
      expect(find.text('1 figure'), findsOneWidget);
      expect(find.text('Comprendre la Zawiya'), findsOneWidget);
    });

    testWidgets('carte : toucher un pays filtre la liste, la puce du pays retire le filtre', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('La Tariqa · 2 pays'), findsOneWidget);
      // Le nœud du lecteur d'écran laisse passer le doigt au détecteur de la
      // carte, qui choisit le point le plus proche : pas de « cible manquée ».
      await tester.tap(find.bySemanticsLabel('Mali · 1 lieu'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_place('Zawiya de Ségou (Mali)'), findsOneWidget);
      expect(_place('Zawiya de Médina Baye (Kaolack)'), findsNothing);

      await tester.tap(find.byTooltip('Afficher tous les pays'));
      await tester.pumpAndSettle();
      expect(_place('Zawiya de Médina Baye (Kaolack)'), findsOneWidget);
    });

    // Vu sur capture : la zone tactile de la Guinée, voisine, recouvrait le
    // point du Mali ; le toucher va désormais au point le plus proche.
    testWidgets('carte : toucher le point du Mali choisit le Mali, même avec la Guinée voisine', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap(zawiyas: const [
        Zawiya(id: 'm1', name: 'Lieu malien 1', country: 'ML'),
        Zawiya(id: 'm2', name: 'Lieu malien 2', country: 'ML'),
        Zawiya(id: 'g', name: 'Lieu guinéen', country: 'GN'),
      ], events: const []));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Mali · 2 lieux'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_place('Lieu malien 1'), findsOneWidget);
      expect(_place('Lieu guinéen'), findsNothing);
    });

    // Audit des écrans refaits du 2026-11-03 : sous `IgnorePointer`, les
    // nœuds de la carte n'avaient pas d'action pour le lecteur d'écran ; un
    // vrai toucher passait, pas le double toucher de TalkBack.
    testWidgets("carte : l'action du lecteur d'écran sur un pays filtre la liste", (tester) async {
      _tall(tester);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      tester.semantics.tap(find.semantics.byLabel('Mali · 1 lieu'));
      await tester.pumpAndSettle();
      expect(_place('Zawiya de Ségou (Mali)'), findsOneWidget);
      expect(_place('Zawiya de Médina Baye (Kaolack)'), findsNothing);
      semantics.dispose();
    });

    testWidgets('un grand groupe se replie à cinq lieux, « Voir les N autres » le déplie', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap(zawiyas: _manySenegal, events: const []));
      await tester.pumpAndSettle();

      expect(find.text('Zawiya sénégalaise 5'), findsOneWidget);
      expect(find.text('Zawiya sénégalaise 6'), findsNothing);
      await tester.tap(find.text('Voir les 2 autres'));
      await tester.pumpAndSettle();
      expect(find.text('Zawiya sénégalaise 7'), findsOneWidget);
    });

    testWidgets('lieu sans pays : groupe « Pays non renseigné », en dernier', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap(zawiyas: const [
        Zawiya(id: 'x', name: 'Lieu sans pays'),
        Zawiya(id: 'y', name: 'Lieu malien', country: 'ML'),
      ], events: const []));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Mali')).dy, lessThan(tester.getTopLeft(find.text('Pays non renseigné')).dy));
    });

    // Audit Zawiyas du 2026-10-25 (P2-1) : recherche par nom ou adresse.
    testWidgets("la recherche filtre l'annuaire par nom ou par adresse", (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'kaolack');
      await tester.pump();
      expect(_place('Zawiya de Médina Baye (Kaolack)'), findsOneWidget);
      expect(_place('Zawiya de Ségou (Mali)'), findsNothing);

      await tester.enterText(find.byType(TextField), 'introuvable');
      await tester.pump();
      expect(find.text('Aucun lieu ne correspond à « introuvable ».'), findsOneWidget);
      // Texte d'état en encre secondaire, pas en bronze (P2-6).
      expect(tester.widget<Text>(find.text('Aucun lieu ne correspond à « introuvable ».')).style?.color,
          AppColors.secondaryInk);

      await tester.tap(find.byTooltip('Effacer la recherche'));
      await tester.pump();
      expect(_place('Zawiya de Ségou (Mali)'), findsOneWidget);
    });

    testWidgets('la recherche se combine au filtre par type, qui affiche son nombre', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, 'Tous · 3'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'senegal');
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Lieux saints · 1'));
      await tester.pump();
      expect(_place('Lieu saint de test'), findsOneWidget);
      expect(_place('Zawiya de Médina Baye (Kaolack)'), findsNothing);
    });

    // Largeur de 900 : la police des tests (Ahem) donne à chaque caractère la
    // largeur de la taille du texte, et les libellés avec leur nombre
    // (« Lieux saints · 1 ») n'y tenaient plus sur 800.
    testWidgets('les puces de type tiennent sur une ligne justifiée', (tester) async {
      _tall(tester, width: 900);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final labels = find.descendant(of: find.byType(ChoiceChip), matching: find.byType(Text));
      final rects = [for (final element in labels.evaluate()) tester.getRect(find.byWidget(element.widget))];
      expect(rects.map((r) => r.top).toSet(), hasLength(1));
      expect(rects.map((r) => r.left).reduce((a, b) => a < b ? a : b), moreOrLessEquals(16 + 11, epsilon: 1));
      expect(rects.map((r) => r.right).reduce((a, b) => a > b ? a : b), moreOrLessEquals(900 - 16 - 11, epsilon: 1));
    });

    testWidgets('texte très agrandi : les puces passent à la ligne, sans être réduites ni tronquées', (tester) async {
      _tall(tester, width: 800);
      await tester.pumpWidget(_wrap(textScale: 3.0));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final tops = {
        for (final element in find.byType(ChoiceChip).evaluate()) tester.getRect(find.byWidget(element.widget)).top,
      };
      expect(tops.length, greaterThan(1));
      expect(find.text('Lieux saints · 1'), findsOneWidget);
    });

    testWidgets("les cibles tactiles de l'écran atteignent 48 dp", (tester) async {
      _tall(tester);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      semantics.dispose();
    });

    // Audit Zawiyas du 2026-10-25 (P3-3) : hors ligne distingué d'une autre
    // erreur, avec « Réessayer » dans les deux cas.
    testWidgets("hors ligne : message de connexion et « Réessayer »", (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap(loadError: const SocketException('Failed host lookup')));
      await tester.pumpAndSettle();
      expect(find.text('Pas de connexion internet. Vérifiez la connexion, puis réessayez.'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('autre erreur : message de chargement générique', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap(loadError: StateError('inattendu')));
      await tester.pumpAndSettle();
      expect(find.text('Impossible de charger les données.'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('bouton « Ajouter un lieu » pour l\'admin seulement, sur la vue Lieux', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap(admin: true));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Ajouter un lieu'), findsOneWidget);
      // Vue Agenda : le bouton devient « Créer un évènement ».
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      expect(find.text('Ajouter un lieu'), findsNothing);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });

  group('Près de moi', () {
    testWidgets('classe les lieux localisés par distance et dit combien ne le sont pas', (tester) async {
      _tall(tester);
      final location = _FakeLocationService();
      await tester.pumpWidget(_wrap(location: location));
      await tester.pumpAndSettle();
      // La position n'est demandée qu'au toucher du filtre.
      expect(location.requests, 0);

      await tester.tap(find.text('Près de moi'));
      await tester.pumpAndSettle();
      expect(location.requests, 1);
      expect(find.text('Les plus proches'), findsOneWidget);
      // Depuis Dakar : Médina Baye avant Ségou ; « ~ » devant une distance
      // calculée sur des coordonnées approximatives.
      expect(tester.getTopLeft(_place('Zawiya de Médina Baye (Kaolack)')).dy,
          lessThan(tester.getTopLeft(_place('Zawiya de Ségou (Mali)')).dy));
      expect(find.textContaining('~'), findsWidgets);
      expect(find.text('1 lieu sans coordonnées n\'est pas classé.'), findsOneWidget);
      expect(_place('Lieu saint de test'), findsNothing);
    });

    testWidgets('refus définitif : bouton vers les réglages, en plus de « Réessayer »', (tester) async {
      _tall(tester);
      final location = _FakeLocationService(failure: LocationFailure.permissionDeniedForever);
      await tester.pumpWidget(_wrap(location: location));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Près de moi'));
      await tester.pumpAndSettle();

      expect(find.textContaining('classer les lieux par distance'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      await tester.tap(find.text('Ouvrir les réglages'));
      await tester.pump();
      expect(location.appSettingsOpened, 1);
    });
  });

  group('Agenda', () {
    testWidgets('rendez-vous par mois, type, date approximative et compte à rebours', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();

      expect(find.textContaining('rendez-vous'), findsWidgets);
      expect(find.text('Ziyara'), findsNWidgets(2));
      expect(find.text('dans 10 j'), findsOneWidget);
      expect(find.text('environ dans 40 j'), findsOneWidget);
      // Pas de section « Rediffusions » sans rediffusion.
      expect(find.text('Rediffusions'), findsNothing);
      // Pas de bouton de création pour un disciple.
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('les rediffusions apparaissent en bas, seulement s\'il y en a', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap(replays: [
        StreamReplay(
          id: 'r1',
          streamId: 'l1',
          eventTitle: 'Gamou',
          videoUrl: 'https://example.org/v',
          createdAt: DateTime(2026, 11, 1),
        ),
      ]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      expect(find.text('Rediffusions'), findsOneWidget);
    });

    testWidgets('sans rendez-vous : message vide, sans carte « Prochain rendez-vous »', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap(events: const []));
      await tester.pumpAndSettle();
      expect(find.text('PROCHAIN RENDEZ-VOUS'), findsNothing);
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      expect(find.text('Aucun évènement à venir pour le moment.'), findsOneWidget);
    });
  });

  // Interface en arabe : libellés traduits, recherche et filtres en miroir,
  // noms des lieux (en français) inchangés, pays traduits.
  testWidgets('en arabe : écran traduit, sans débordement', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_wrap(locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('ابحث عن مكان أو مدينة أو بلد'), findsOneWidget);
    expect(_place('Zawiya de Ségou (Mali)'), findsOneWidget);
    expect(find.text('السنغال'), findsOneWidget);
    expect(find.text('الموعد القادم'.toUpperCase()), findsOneWidget);
    final all = tester.getRect(find.widgetWithText(ChoiceChip, 'الكل · 3'));
    final mosques = tester.getRect(find.widgetWithText(ChoiceChip, 'المساجد · 0'));
    expect(all.left, greaterThan(mosques.left));

    await tester.tap(find.text('المواعيد'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
