// Captures de l'onglet Zawiyas refait (2026-11-03), pour chaque état de sa
// maquette (`docs/maquettes/ecran-zawiyas.html`) : Lieux sans direct, avec un
// direct en cours, filtrés par pays depuis la carte, « Près de moi », et
// Agenda, en français et en arabe, avec les vraies polices.
//
// Lieux, pays, rendez-vous, successions et figures liées : ceux de la base au
// 2026-11-03 (fichier généré à partir de requêtes sur la base, adresses sans
// la mention « coordonnées approximatives », portée par la colonne). Le direct
// est un exemple, comme dans la maquette (aucun direct en cours en base) ; la
// position de « Près de moi » est à Dakar, comme dans la maquette.
//
// Les écrans longs (Lieux, Agenda) sont capturés sur toute leur hauteur, pour
// les comparer à la maquette défilée.
//
// Ignoré sans KIT_FONTS_DIR et KIT_CAPTURES_DIR (voir `capture_support.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:at_tijaniya/core/location/location_service.dart';
import 'package:at_tijaniya/features/khadara/domain/khadara_models.dart';
import 'package:at_tijaniya/features/khadara/domain/zawiyas_overview.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_providers.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_screen.dart';
import 'package:at_tijaniya/features/khadara/presentation/live_stream_providers.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

import 'capture_support.dart';

// ---- Fichier généré : lieux et rendez-vous de la base au 2026-11-03. ----
const _places = [
  Zawiya(
      id: 'fass',
      name: 'Fass-Diacksao',
      kind: ZawiyaKind.holyPlace,
      addressText: 'Fass-Diacksao, région de Thiès, Sénégal',
      country: 'SN'),
  Zawiya(
      id: 'halwar',
      name: 'Halwar, village natal d\'El Hadj Oumar Tall',
      kind: ZawiyaKind.holyPlace,
      addressText: 'Halwar, commune de Gamadji Saré, département de Podor, Sénégal',
      latitude: 16.55,
      longitude: -14.68,
      coordinatesApproximate: true,
      country: 'SN'),
  Zawiya(
      id: 'gaaya',
      name: 'Mosquée d\'El Hadj Malick Sy de Gaaya',
      kind: ZawiyaKind.mosque,
      addressText: 'Gaé (Gaaya), département de Dagana, Sénégal',
      latitude: 16.49,
      longitude: -15.6,
      coordinatesApproximate: true,
      country: 'SN'),
  Zawiya(
      id: 'ndiarnde',
      name: 'Ndiarndé',
      kind: ZawiyaKind.holyPlace,
      addressText: 'Ndiarndé, commune de Ngandiouf, département de Tivaouane, Sénégal',
      country: 'SN'),
  Zawiya(
      id: 'ainmadhi',
      name: 'Zawiya d\'Aïn Madhi',
      kind: ZawiyaKind.zawiya,
      addressText: 'Aïn Madhi, wilaya de Laghouat, Algérie',
      latitude: 33.6667,
      longitude: 2.1667,
      coordinatesApproximate: true,
      country: 'DZ'),
  Zawiya(
      id: 'bouss',
      name: 'Zawiya de Boussemghoun (Algérie)',
      kind: ZawiyaKind.holyPlace,
      addressText: 'Boussemghoun, wilaya d\'El Bayadh, Algérie',
      latitude: 32.87,
      longitude: 0.02,
      coordinatesApproximate: true,
      country: 'DZ'),
  Zawiya(
      id: 'dingui',
      name: 'Zawiya de Dinguiraye (Guinée)',
      kind: ZawiyaKind.zawiya,
      addressText: 'Dinguiraye, région de Faranah, Guinée',
      latitude: 11.3,
      longitude: -10.72,
      coordinatesApproximate: true,
      country: 'GN'),
  Zawiya(
      id: 'fes',
      name: 'Zawiya de Fès',
      kind: ZawiyaKind.zawiya,
      addressText: 'Médina de Fès, Maroc',
      latitude: 34.065,
      longitude: -4.975,
      coordinatesApproximate: true,
      country: 'MA'),
  Zawiya(
      id: 'keurmame',
      name: 'Zawiya de Keur Mame El Hadji, Thiès',
      kind: ZawiyaKind.zawiya,
      addressText: 'Quartier Keur Mame El Hadji, Thiès, Sénégal',
      latitude: 14.79,
      longitude: -16.93,
      coordinatesApproximate: true,
      country: 'SN'),
  Zawiya(
      id: 'kiota',
      name: 'Zawiya de Kiota (Niger)',
      kind: ZawiyaKind.zawiya,
      addressText: 'Kiota, département de Boboye, région de Dosso, Niger (environ 100 km de Niamey)',
      country: 'NE'),
  Zawiya(
      id: 'koki',
      name: 'Zawiya de Koki, Kano (Nigeria)',
      kind: ZawiyaKind.zawiya,
      addressText: 'Koki, Kano, État de Kano, Nigeria',
      latitude: 12.0,
      longitude: 8.52,
      coordinatesApproximate: true,
      country: 'NG'),
  Zawiya(
      id: 'kossi',
      name: 'Zawiya de Kossi',
      kind: ZawiyaKind.holyPlace,
      addressText: 'Kossi, près de Kaolack, Sénégal',
      country: 'SN'),
  Zawiya(
      id: 'latmingue',
      name: 'Zawiya de Latmingué',
      kind: ZawiyaKind.zawiya,
      addressText: 'Latmingué',
      latitude: 14.07,
      longitude: -15.93,
      country: 'SN'),
  Zawiya(
      id: 'medinabaye',
      name: 'Zawiya de Médina Baye (Kaolack)',
      kind: ZawiyaKind.zawiya,
      addressText: 'Médina Baye, Kaolack, Sénégal',
      latitude: 14.152,
      longitude: -16.073,
      country: 'SN'),
  Zawiya(
      id: 'gounass',
      name: 'Zawiya de Médina Gounass',
      kind: ZawiyaKind.zawiya,
      addressText: 'Médina Gounass, département de Vélingara, région de Kolda, Sénégal',
      latitude: 12.8,
      longitude: -14.35,
      country: 'SN'),
  Zawiya(
      id: 'nguidjilone',
      name: 'Zawiya de Nguidjilone',
      kind: ZawiyaKind.zawiya,
      addressText: 'Nguidjilone, à 35 km en aval de Matam, département et région de Matam, Sénégal',
      latitude: 15.83,
      longitude: -13.48,
      coordinatesApproximate: true,
      country: 'SN'),
  Zawiya(
      id: 'nioro',
      name: 'Zawiya de Nioro du Sahel (Mali)',
      kind: ZawiyaKind.zawiya,
      addressText: 'Nioro du Sahel, région de Kayes, Mali',
      latitude: 15.2306,
      longitude: -9.5929,
      coordinatesApproximate: true,
      country: 'ML'),
  Zawiya(
      id: 'prang',
      name: 'Zawiya de Prang (Ghana)',
      kind: ZawiyaKind.zawiya,
      addressText: 'Prang, district de Pru West, région de Bono East, Ghana',
      latitude: 8.03,
      longitude: -0.9,
      coordinatesApproximate: true,
      country: 'GH'),
  Zawiya(
      id: 'ramatoulaye',
      name: 'Zawiya de Ramatoulaye (Burkina Faso)',
      kind: ZawiyaKind.zawiya,
      addressText: 'Ramatoulaye, nord du Burkina Faso',
      country: 'BF'),
  Zawiya(
      id: 'segou',
      name: 'Zawiya de Ségou (Mali)',
      kind: ZawiyaKind.zawiya,
      addressText: 'Ségou, Mali',
      latitude: 13.4317,
      longitude: -6.2157,
      coordinatesApproximate: true,
      country: 'ML'),
  Zawiya(
      id: 'taiba',
      name: 'Zawiya de Taïba Niassène',
      kind: ZawiyaKind.holyPlace,
      addressText: 'Taïba Niassène, département de Nioro du Rip, région de Kaolack, Sénégal',
      country: 'SN'),
  Zawiya(
      id: 'temacine',
      name: 'Zawiya de Temacine (Algérie)',
      kind: ZawiyaKind.zawiya,
      addressText: 'Tamacine (Témacine), à 12 km de Touggourt, wilaya de Touggourt, Algérie',
      latitude: 33.0219,
      longitude: 6.0228,
      country: 'DZ'),
  Zawiya(
      id: 'thienaba',
      name: 'Zawiya de Thiénaba Seck',
      kind: ZawiyaKind.zawiya,
      addressText: 'Thiénaba, département de Thiès, Sénégal',
      latitude: 14.798,
      longitude: -16.86,
      coordinatesApproximate: true,
      country: 'SN'),
  Zawiya(
      id: 'tivaouane',
      name: 'Zawiya de Tivaouane',
      kind: ZawiyaKind.zawiya,
      addressText: 'Tivaouane, région de Thiès, Sénégal',
      latitude: 14.95,
      longitude: -16.8167,
      country: 'SN'),
  Zawiya(
      id: 'dakar',
      name: 'Zawiya El Hadj Malick Sy de Dakar',
      kind: ZawiyaKind.zawiya,
      addressText:
          'Carrefour des avenues Lamine Guèye, Amadou Assane Ndoye et Carnot, Plateau (Sandaga), Dakar, Sénégal',
      latitude: 14.6713,
      longitude: -17.4365,
      coordinatesApproximate: true,
      country: 'SN'),
  Zawiya(
      id: 'stlouis',
      name: 'Zawiya El Hadj Malick Sy de Saint-Louis',
      kind: ZawiyaKind.zawiya,
      addressText: 'Île de Saint-Louis (Ndar), Sénégal',
      latitude: 16.027,
      longitude: -16.504,
      coordinatesApproximate: true,
      country: 'SN'),
  Zawiya(
      id: 'hamawiyya',
      name: 'Zawiya Hamawiyya de Nioro du Sahel (Mali)',
      kind: ZawiyaKind.zawiya,
      addressText: 'Nioro du Sahel, région de Kayes, Mali',
      latitude: 15.2306,
      longitude: -9.5929,
      coordinatesApproximate: true,
      country: 'ML'),
  Zawiya(
      id: 'leona',
      name: 'Zawiya Niassène de Léona (Kaolack)',
      kind: ZawiyaKind.zawiya,
      addressText: 'Quartier Léona, Kaolack, Sénégal',
      latitude: 14.145,
      longitude: -16.07,
      country: 'SN'),
  Zawiya(
      id: 'omarienne',
      name: 'Zawiya Omarienne',
      kind: ZawiyaKind.zawiya,
      addressText: 'Mosquée omarienne, avenue El Hadji Malick Sy, angle Corniche Ouest, Dakar, Sénégal',
      latitude: 14.678,
      longitude: -17.46,
      coordinatesApproximate: true,
      country: 'SN'),
  Zawiya(
      id: 'louga',
      name: 'Zawiya Omarienne de Louga',
      kind: ZawiyaKind.zawiya,
      addressText: 'Louga, Sénégal',
      latitude: 15.6144,
      longitude: -16.224,
      coordinatesApproximate: true,
      country: 'SN'),
  Zawiya(
      id: 'newyork',
      name: 'Zawiya Seydi El Hadji Malick Sy de New York',
      kind: ZawiyaKind.zawiya,
      addressText: '108 East 128th Street, New York, NY 10035, États-Unis',
      latitude: 40.8066,
      longitude: -73.9382,
      country: 'US'),
  Zawiya(
      id: 'tunis',
      name: 'Zawiya Sidi Ibrahim Riahi de Tunis (Tunisie)',
      kind: ZawiyaKind.zawiya,
      addressText: 'Rue Sidi Brahim Riahi, médina de Tunis, Tunisie',
      latitude: 36.7985,
      longitude: 10.169,
      coordinatesApproximate: true,
      country: 'TN'),
  Zawiya(
      id: 'rabat',
      name: 'Zawiya Sidi Larbi Ben Sayeh de Rabat (Maroc)',
      kind: ZawiyaKind.zawiya,
      addressText: 'Rue Bab El Alou, médina de Rabat, Maroc',
      latitude: 34.0265,
      longitude: -6.8385,
      coordinatesApproximate: true,
      country: 'MA'),
  Zawiya(
      id: 'caire',
      name: 'Zawiya Tijaniyya d\'El Maghrabilin, Le Caire (Égypte)',
      kind: ZawiyaKind.zawiya,
      addressText: 'El Maghrabilin, quartier Darb al-Ahmar, Le Caire, Égypte',
      latitude: 30.042,
      longitude: 31.258,
      coordinatesApproximate: true,
      country: 'EG'),
];

final _events = [
  KhadaraEvent(
      id: 'e0',
      zawiyaId: 'taiba',
      zawiyaName: 'Zawiya de Taïba Niassène',
      title: 'Ziarra de Taïba Niassène 2026',
      type: KhadaraEventType.ziyara,
      startsAt: DateTime(2026, 12, 25, 9),
      isDateApproximate: true),
  KhadaraEvent(
      id: 'e1',
      zawiyaId: 'louga',
      zawiyaName: 'Zawiya Omarienne de Louga',
      title: 'Ziarra annuelle de Thierno Mountaga Daha Tall 2027 (63e édition)',
      type: KhadaraEventType.ziyara,
      startsAt: DateTime(2027, 1, 8, 9),
      isDateApproximate: true),
  KhadaraEvent(
      id: 'e2',
      zawiyaId: 'omarienne',
      zawiyaName: 'Zawiya Omarienne',
      title: 'Ziarra de la famille omarienne à Dakar 2027',
      type: KhadaraEventType.ziyara,
      startsAt: DateTime(2027, 1, 22, 9),
      isDateApproximate: true),
  KhadaraEvent(
      id: 'e3',
      zawiyaId: 'latmingue',
      zawiyaName: 'Zawiya de Latmingué',
      title: 'Ziarra annuelle de Thierno Siré Diop',
      type: KhadaraEventType.ziyara,
      startsAt: DateTime(2027, 1, 23, 9),
      isDateApproximate: false),
  KhadaraEvent(
      id: 'e4',
      zawiyaId: 'leona',
      zawiyaName: 'Zawiya Niassène de Léona (Kaolack)',
      title: 'Ziarra annuelle de Léona Niassène 2027',
      type: KhadaraEventType.ziyara,
      startsAt: DateTime(2027, 1, 30, 9),
      isDateApproximate: true),
  KhadaraEvent(
      id: 'e5',
      zawiyaId: 'halwar',
      zawiyaName: 'Halwar, village natal d\'El Hadj Oumar Tall',
      title: 'Célébration de la naissance d\'El Hadj Oumar Tall à Halwar 2027',
      type: KhadaraEventType.ziyara,
      startsAt: DateTime(2027, 2, 3, 9),
      isDateApproximate: true),
  KhadaraEvent(
      id: 'e6',
      zawiyaId: 'nguidjilone',
      zawiyaName: 'Zawiya de Nguidjilone',
      title: 'Ziarra de Thierno Aliou Thierno Yéro Baal Anne à Nguidjilone 2027',
      type: KhadaraEventType.ziyara,
      startsAt: DateTime(2027, 2, 6, 9),
      isDateApproximate: true),
  KhadaraEvent(
      id: 'e7',
      zawiyaId: 'prang',
      zawiyaName: 'Zawiya de Prang (Ghana)',
      title: 'Récitation annuelle du Coran pour la paix, Prang 2027',
      type: KhadaraEventType.other,
      startsAt: DateTime(2027, 3, 6, 9),
      isDateApproximate: true),
  KhadaraEvent(
      id: 'e8',
      zawiyaId: 'medinabaye',
      zawiyaName: 'Zawiya de Médina Baye (Kaolack)',
      title: 'Ziarra internationale Seydi Aliou Cissé 2027',
      type: KhadaraEventType.ziyara,
      startsAt: DateTime(2027, 3, 27, 9),
      isDateApproximate: true),
  KhadaraEvent(
      id: 'e9',
      zawiyaId: 'tivaouane',
      zawiyaName: 'Zawiya de Tivaouane',
      title: 'Ziarra générale de Tivaouane 2027',
      type: KhadaraEventType.ziyara,
      startsAt: DateTime(2027, 4, 4, 9),
      isDateApproximate: true),
  KhadaraEvent(
      id: 'e10',
      zawiyaId: 'gounass',
      zawiyaName: 'Zawiya de Médina Gounass',
      title: 'Daaka de Médina Gounass — 86e édition',
      type: KhadaraEventType.ziyara,
      startsAt: DateTime(2027, 4, 10, 9),
      isDateApproximate: false),
  KhadaraEvent(
      id: 'e11',
      zawiyaId: 'kiota',
      zawiyaName: 'Zawiya de Kiota (Niger)',
      title: 'Maouloud de Kiota 2027',
      type: KhadaraEventType.ziyara,
      startsAt: DateTime(2027, 8, 14, 9),
      isDateApproximate: true),
  KhadaraEvent(
      id: 'e12',
      zawiyaId: 'medinabaye',
      zawiyaName: 'Zawiya de Médina Baye (Kaolack)',
      title: 'Gamou (Mawlid) international de Médina Baye 2027',
      type: KhadaraEventType.ziyara,
      startsAt: DateTime(2027, 8, 14, 9),
      isDateApproximate: true),
  KhadaraEvent(
      id: 'e13',
      zawiyaId: 'keurmame',
      zawiyaName: 'Zawiya de Keur Mame El Hadji, Thiès',
      title: 'Gamou de Keur Mame El Hadji (Thiès) 2027',
      type: KhadaraEventType.ziyara,
      startsAt: DateTime(2027, 8, 14, 9),
      isDateApproximate: true),
  KhadaraEvent(
      id: 'e14',
      zawiyaId: 'tivaouane',
      zawiyaName: 'Zawiya de Tivaouane',
      title: 'Gamou (Mawlid) de Tivaouane 2027',
      type: KhadaraEventType.ziyara,
      startsAt: DateTime(2027, 8, 14, 9),
      isDateApproximate: true),
  KhadaraEvent(
      id: 'e15',
      zawiyaId: 'kossi',
      zawiyaName: 'Zawiya de Kossi',
      title: 'Gamouwaate de Kossi 2027',
      type: KhadaraEventType.ziyara,
      startsAt: DateTime(2027, 8, 21, 9),
      isDateApproximate: true),
  KhadaraEvent(
      id: 'e16',
      zawiyaId: 'hamawiyya',
      zawiyaName: 'Zawiya Hamawiyya de Nioro du Sahel (Mali)',
      title: 'Ismou de Nioro du Sahel 2027',
      type: KhadaraEventType.ziyara,
      startsAt: DateTime(2027, 8, 21, 9),
      isDateApproximate: true),
];

const _counts = ZawiyaLinkCounts(
  succession: {
    'ainmadhi': 12,
    'fes': 8,
    'latmingue': 1,
    'medinabaye': 5,
    'nguidjilone': 2,
    'nioro': 2,
    'segou': 2,
    'tivaouane': 7,
    'leona': 6,
    'omarienne': 4,
    'louga': 2
  },
  figures: {
    'fass': 1,
    'halwar': 1,
    'gaaya': 1,
    'ndiarnde': 1,
    'ainmadhi': 13,
    'fes': 14,
    'latmingue': 2,
    'medinabaye': 6,
    'gounass': 1,
    'nguidjilone': 3,
    'nioro': 3,
    'segou': 3,
    'thienaba': 1,
    'tivaouane': 8,
    'dakar': 1,
    'stlouis': 1,
    'leona': 7,
    'omarienne': 5,
    'louga': 3,
    'newyork': 1,
    'tunis': 1,
    'rabat': 1
  },
);
// ---- Fin des données générées. ----

const _live = LiveStream(
  id: 'live',
  eventTitle: 'Ziarra générale de Tivaouane',
  sourceType: LiveStreamSourceType.youtube,
  status: LiveStreamStatus.live,
);

/// Position d'exemple à Dakar, comme dans la maquette.
class _DakarLocation extends LocationService {
  const _DakarLocation();

  @override
  Future<LocationResult> getCurrentPosition() async => LocationResult(
        position: Position(
          latitude: 14.69,
          longitude: -17.44,
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

Widget _app(Locale locale, {bool live = false}) => ProviderScope(
      overrides: [
        isAdminProvider.overrideWithValue(false),
        canCreateEventProvider.overrideWithValue(false),
        currentUserIdProvider.overrideWithValue(null),
        zawiyasProvider.overrideWith((ref) async => _places),
        upcomingEventsProvider.overrideWith((ref) async => _events),
        allLiveStreamsProvider.overrideWith((ref) async => live ? const [_live] : const <LiveStream>[]),
        streamReplaysProvider.overrideWith((ref) async => const <StreamReplay>[]),
        zawiyaLinkCountsProvider.overrideWith((ref) async => _counts),
        locationServiceProvider.overrideWithValue(const _DakarLocation()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: captureTheme(),
        locale: locale,
        supportedLocales: const [Locale('fr'), Locale('ar')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Barre d'app de l'onglet, comme dans l'app (`home_shell.dart`).
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(title: Text(AppLocalizations.of(context)!.navKhadara)),
            body: const KhadaraScreen(),
          ),
        ),
      ),
    );

typedef _Prepare = Future<void> Function(WidgetTester tester, String language);

Future<void> _none(WidgetTester tester, String language) async {}

void main() {
  final skip = captureSkipReason;

  setUpAll(() async {
    if (skip == null) await setUpCaptureFonts();
  });

  // Nom → (hauteur de la capture, direct en cours, préparation).
  final states = <String, (double, bool, _Prepare)>{
    // Premier écran, à la taille d'un téléphone (412 × 892 dp).
    'ecran': (892, false, _none),
    'direct': (892, true, _none),
    // Vue Lieux entière, carte et groupes compris.
    'lieux': (
      3000,
      false,
      _none,
    ),
    'lieux_pays': (
      1500,
      false,
      (tester, language) async {
        // Le nœud du lecteur d'écran laisse passer le doigt au détecteur de la
        // carte, qui choisit le point le plus proche : pas de « cible manquée ».
        await tester.tap(find.bySemanticsLabel(RegExp(language == 'ar' ? '^مالي' : '^Mali')), warnIfMissed: false);
        await tester.pumpAndSettle();
      }
    ),
    'pres_de_moi': (
      3000,
      false,
      (tester, language) async {
        await tester.tap(find.text(language == 'ar' ? 'بالقرب مني' : 'Près de moi'));
        await tester.pumpAndSettle();
      }
    ),
    'agenda': (
      2400,
      false,
      (tester, language) async {
        await tester.tap(find.text(language == 'ar' ? 'المواعيد' : 'Agenda'));
        await tester.pumpAndSettle();
      }
    ),
  };

  for (final locale in const [Locale('fr'), Locale('ar')]) {
    for (final entry in states.entries) {
      final (height, live, prepare) = entry.value;
      testWidgets('capture zawiyas ${entry.key} (${locale.languageCode})', skip: skip != null, (tester) async {
        tester.view.physicalSize = Size(412, height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(key: key, child: _app(locale, live: live)));
        await tester.pumpAndSettle();
        await prepare(tester, locale.languageCode);
        await tester.pumpAndSettle();
        await captureToFile(tester, find.byKey(key), 'zawiyas_${entry.key}_${locale.languageCode}');
      });
    }
  }
}
