// Captures des écrans « divers » (lot 1) mis au thème du kit le 2026-11-04 :
// Confidentialité, À propos, Notifications,
// Faire un don, « Comprendre la Zawiya » (brouillon et page vide), en français
// et en arabe, avec les vraies polices. La Politique de confidentialité n'y est
// pas : ces tests servent les polices par le canal des assets, ce qui empêche
// de lire son texte ; `divers_kit_test.dart` vérifie ses titres.
//
// Ignoré sans KIT_FONTS_DIR et KIT_CAPTURES_DIR (voir `capture_support.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/donation/presentation/donation_screen.dart';
import 'package:at_tijaniya/features/khadara/data/guide_page_repository.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_providers.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_understanding_screen.dart';
import 'package:at_tijaniya/features/mouqaddam/presentation/mouqaddam_providers.dart';
import 'package:at_tijaniya/features/notifications/domain/app_notification.dart';
import 'package:at_tijaniya/features/notifications/presentation/notifications_providers.dart';
import 'package:at_tijaniya/features/notifications/presentation/notifications_screen.dart';
import 'package:at_tijaniya/features/settings/domain/privacy_settings_models.dart';
import 'package:at_tijaniya/features/settings/presentation/about_screen.dart';
import 'package:at_tijaniya/features/settings/presentation/privacy_settings_providers.dart';
import 'package:at_tijaniya/features/settings/presentation/privacy_settings_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

import 'capture_support.dart';

void main() {
  final skip = captureSkipReason;

  setUpAll(() async {
    if (skip == null) await setUpCaptureFonts();
  });

  Future<void> capture(
    WidgetTester tester,
    String name,
    Locale locale,
    Widget screen, {
    List<Override> overrides = const [],
    double height = 1200,
  }) async {
    tester.view.physicalSize = Size(400, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: RepaintBoundary(
        key: key,
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
          home: screen,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await captureToFile(tester, find.byKey(key), '${name}_${locale.languageCode}');
  }

  for (final locale in const [Locale('fr'), Locale('ar')]) {
    final lang = locale.languageCode;

    testWidgets('capture confidentialité ($lang)', skip: skip != null, (tester) async {
      await capture(tester, 'divers_confidentialite', locale, const PrivacySettingsScreen(), overrides: [
        myPrivacySettingsProvider.overrideWith((ref) async => const PrivacySettings(lineageVisible: true)),
        isVerifiedMouqaddamProvider.overrideWithValue(false),
      ]);
    });

    testWidgets('capture à propos ($lang)', skip: skip != null, (tester) async {
      await capture(tester, 'divers_a_propos', locale, const AboutScreen(), height: 2400);
    });

    testWidgets('capture notifications ($lang)', skip: skip != null, (tester) async {
      await capture(tester, 'divers_notifications', locale, const NotificationsScreen(), overrides: [
        myNotificationsProvider.overrideWith((ref) => Stream.value([
              AppNotification(
                id: 'n1',
                type: AppNotificationType.directMessage,
                payload: const {},
                readAt: null,
                createdAt: DateTime(2026, 11, 3, 18, 30),
              ),
              AppNotification(
                id: 'n2',
                type: AppNotificationType.postComment,
                payload: const {},
                readAt: DateTime(2026, 11, 2),
                createdAt: DateTime(2026, 11, 2, 9, 5),
              ),
            ])),
      ]);
    });

    testWidgets('capture notifications en erreur ($lang)', skip: skip != null, (tester) async {
      await capture(tester, 'divers_notifications_erreur', locale, const NotificationsScreen(),
          overrides: [myNotificationsProvider.overrideWith((ref) => Stream.error(StateError('panne')))], height: 500);
    });

    testWidgets('capture don ($lang)', skip: skip != null, (tester) async {
      await capture(tester, 'divers_don', locale, const DonationScreen());
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      await captureToFile(tester, find.byType(RepaintBoundary).first, 'divers_don_choisi_$lang');
    });

    testWidgets('capture comprendre brouillon ($lang)', skip: skip != null, (tester) async {
      await capture(tester, 'divers_comprendre', locale, const KhadaraUnderstandingScreen(), overrides: [
        khadaraUnderstandingPageProvider.overrideWith((ref) async => const GuidePage(
              title: 'Exemple',
              bodyMarkdown: '## Section d’exemple\n\nTexte d’exemple.',
              contentStatus: 'brouillon',
            )),
      ]);
    });

    testWidgets('capture comprendre vide ($lang)', skip: skip != null, (tester) async {
      await capture(tester, 'divers_comprendre_vide', locale, const KhadaraUnderstandingScreen(), overrides: [
        khadaraUnderstandingPageProvider.overrideWith((ref) async => null),
      ]);
    });
  }
}
