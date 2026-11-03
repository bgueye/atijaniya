// Captures du parcours d'entrée refait (2026-11-03), pour chaque étape de sa
// maquette (`docs/maquettes/parcours-entree.html`) : démarrage, langue,
// découverte (trois écrans), rappels, entrée, compte (création et
// connexion), boîte mail et nouveau mot de passe, en français et en arabe,
// avec les vraies polices. Adresse e-mail et nom d'exemple, comme dans la
// maquette ; les rendez-vous de l'aperçu Zawiyas sont ceux de la base au
// 2026-11-03.
//
// Ignoré sans KIT_FONTS_DIR et KIT_CAPTURES_DIR (voir `capture_support.dart`).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/core/theme/locale_controller.dart';
import 'package:at_tijaniya/features/auth/presentation/auth_screen.dart';
import 'package:at_tijaniya/features/auth/presentation/reset_password_screen.dart';
import 'package:at_tijaniya/features/auth/presentation/welcome_screen.dart';
import 'package:at_tijaniya/features/khadara/domain/khadara_models.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_providers.dart';
import 'package:at_tijaniya/features/onboarding/presentation/language_selection_screen.dart';
import 'package:at_tijaniya/features/onboarding/presentation/onboarding_reminders_screen.dart';
import 'package:at_tijaniya/features/onboarding/presentation/onboarding_screen.dart';
import 'package:at_tijaniya/features/splash/presentation/splash_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

import 'capture_support.dart';

KhadaraEvent _event(String id, String title, DateTime date) => KhadaraEvent(
      id: id,
      zawiyaId: 'z1',
      zawiyaName: 'Zawiya',
      title: title,
      type: KhadaraEventType.ziyara,
      startsAt: date,
      isDateApproximate: true,
    );

final _events = [
  _event('e1', 'Ziarra de Taïba Niassène 2026', DateTime(2026, 12, 25, 9)),
  _event('e2', 'Ziarra générale de Tivaouane 2027', DateTime(2027, 4, 4, 9)),
  _event('e3', 'Gamou (Mawlid) de Tivaouane 2027', DateTime(2027, 8, 14, 9)),
];

/// Assets lus depuis le dépôt : `flutter test` ne fournit pas le catalogue
/// des assets (AssetManifest.bin), et les logos (PNG, SVG) restaient vides.
/// Le catalogue est reconstruit pour les seuls fichiers du dossier de marque.
class _DiskAssetBundle extends CachingAssetBundle {
  static const _brandingDir = 'assets/branding';

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      final files =
          Directory(_brandingDir).listSync().whereType<File>().map((f) => '$_brandingDir/${f.uri.pathSegments.last}');
      final manifest = {
        for (final path in files)
          path: [
            {'asset': path},
          ],
      };
      return const StandardMessageCodec().encodeMessage(manifest)!;
    }
    // Lecture synchrone : une lecture asynchrone lancée sous l'horloge
    // simulée du test (pendant `pumpWidget`) ne se terminait jamais.
    return ByteData.sublistView(File(key).readAsBytesSync());
  }
}

Widget _withAssets(Widget child) => DefaultAssetBundle(bundle: _DiskAssetBundle(), child: child);

Widget _app(Widget home, Locale locale) => ProviderScope(
      overrides: [
        initialLocaleProvider.overrideWithValue(null),
        upcomingEventsProvider.overrideWith((ref) async => _events),
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
        home: home,
      ),
    );

/// Étapes à capturer : nom → (écran, préparation après le premier rendu).
typedef _Prepare = Future<void> Function(WidgetTester tester);

Future<void> _none(WidgetTester tester) async {}

Future<void> _swipe(WidgetTester tester, int pages) async {
  for (var i = 0; i < pages; i++) {
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
  }
}

void main() {
  final skip = captureSkipReason;

  setUpAll(() async {
    if (skip == null) await setUpCaptureFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final states = <String, (Widget Function(), _Prepare)>{
    'demarrage': (() => SplashScreen(onFinished: () {}), _none),
    'langue': (() => const LanguageSelectionScreen(), _none),
    'langue_arabe': (
      () => const LanguageSelectionScreen(),
      (tester) async {
        await tester.tap(find.text('العربية'));
        await tester.pumpAndSettle();
      }
    ),
    'decouverte_1': (() => OnboardingScreen(onFinished: () {}), _none),
    'decouverte_2': (() => OnboardingScreen(onFinished: () {}), (tester) => _swipe(tester, 1)),
    'decouverte_3': (() => OnboardingScreen(onFinished: () {}), (tester) => _swipe(tester, 2)),
    'rappels': (() => OnboardingRemindersScreen(onFinished: () {}), _none),
    'entree': (() => WelcomeScreen(onCreateAccount: () {}, onSignIn: () {}, onGuest: () {}), _none),
    'compte_creation': (
      () => AuthScreen(onAuthenticated: () {}, onBack: () {}, initialSignUp: true),
      (tester) async {
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'Bocar');
        await tester.enterText(fields.at(1), 'bocar@exemple.sn');
        await tester.enterText(fields.at(2), 'tijani2026');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      }
    ),
    'compte_connexion': (() => AuthScreen(onAuthenticated: () {}, onBack: () {}), _none),
    'boite_mail': (
      () => Scaffold(
            backgroundColor: const Color(0xFFF7F2E7),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
                child: SignupCheckEmailPanel(
                  email: 'bocar@exemple.sn',
                  resending: false,
                  resendSecondsLeft: 45,
                  onGoToLogin: () {},
                  onResend: () {},
                  onEditEmail: () {},
                ),
              ),
            ),
          ),
      _none
    ),
    'nouveau_mot_de_passe': (
      () => ResetPasswordScreen(onDone: () {}, onCancel: () {}),
      (tester) async {
        await tester.enterText(find.byType(TextFormField).first, 'tijani2026');
        await tester.enterText(find.byType(TextFormField).last, 'tijani2026');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      }
    ),
  };

  for (final locale in const [Locale('fr'), Locale('ar')]) {
    for (final entry in states.entries) {
      final (build, prepare) = entry.value;
      testWidgets('capture parcours ${entry.key} (${locale.languageCode})', skip: skip != null, (tester) async {
        // Taille d'un téléphone courant (412 × 892 dp).
        tester.view.physicalSize = const Size(412, 892);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(key: key, child: _withAssets(_app(build(), locale))));
        // Logos (PNG et SVG) : décodés hors de l'horloge simulée.
        await tester.runAsync(() async {
          for (final element in find.byType(Image).evaluate()) {
            final image = element.widget as Image;
            await precacheImage(image.image, element);
          }
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        await prepare(tester);
        await tester.pumpAndSettle();
        await captureToFile(tester, find.byKey(key), 'parcours_${entry.key}_${locale.languageCode}');
        // Le splash programme son minuteur de sortie : il est vidé ici.
        await tester.pump(const Duration(seconds: 1));
        SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      });
    }
  }
}
