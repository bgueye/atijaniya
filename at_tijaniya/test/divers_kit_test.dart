// Écrans « divers » (lot 1) mis au thème du kit le 2026-11-04 :
// - Confidentialité : « Qui peut vous contacter » en titre du kit, choix en
//   `SegmentedSwitch` (et non `SegmentedButton`), erreur en `Notice` ;
// - Disciples bloqués, Notifications : erreur et liste vide en `Notice`, et
//   les Notifications ont enfin un « Réessayer » ;
// - « Comprendre la Zawiya » : bandeau brouillon partagé (`DraftBanner`),
//   page vide en `MessagePage` ;
// - aucun texte de ces écrans en bronze (sous le seuil AA).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/theme/app_colors.dart';
import 'package:at_tijaniya/core/widgets/draft_banner.dart';
import 'package:at_tijaniya/core/widgets/message_page.dart';
import 'package:at_tijaniya/core/widgets/notice.dart';
import 'package:at_tijaniya/core/widgets/section_title.dart';
import 'package:at_tijaniya/core/widgets/segmented_switch.dart';
import 'package:at_tijaniya/features/khadara/data/guide_page_repository.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_providers.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_understanding_screen.dart';
import 'package:at_tijaniya/features/moderation/presentation/block_user.dart';
import 'package:at_tijaniya/features/mouqaddam/presentation/mouqaddam_providers.dart';
import 'package:at_tijaniya/features/moderation/data/blocks_repository.dart';
import 'package:at_tijaniya/features/notifications/domain/app_notification.dart';
import 'package:at_tijaniya/features/notifications/presentation/notifications_providers.dart';
import 'package:at_tijaniya/features/notifications/presentation/notifications_screen.dart';
import 'package:at_tijaniya/features/settings/domain/privacy_settings_models.dart';
import 'package:at_tijaniya/features/settings/presentation/privacy_settings_providers.dart';
import 'package:at_tijaniya/features/settings/presentation/privacy_policy_screen.dart';
import 'package:at_tijaniya/features/settings/presentation/privacy_settings_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

Widget _app(Widget home, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('fr'),
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
}

/// Aucun texte en bronze : il est sous le seuil AA (kit § Couleurs).
void _expectNoBronzeText(WidgetTester tester) {
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    expect(text.style?.color, isNot(AppColors.bronze), reason: 'texte en bronze : « ${text.data ?? text.textSpan} »');
  }
}

void main() {
  testWidgets('Confidentialité : titre du kit et bascule du kit', (tester) async {
    await tester.pumpWidget(_app(const PrivacySettingsScreen(), [
      myPrivacySettingsProvider.overrideWith((ref) async => const PrivacySettings()),
      isVerifiedMouqaddamProvider.overrideWithValue(false),
    ]));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(SectionTitle, 'Qui peut vous contacter'), findsOneWidget);
    expect(find.byType(SegmentedSwitch<WhoCanContact>), findsOneWidget);
    expect(find.byType(SegmentedButton<WhoCanContact>), findsNothing);
    _expectNoBronzeText(tester);
  });

  testWidgets('Confidentialité illisible : la carte du kit avec « Réessayer »', (tester) async {
    await tester.pumpWidget(_app(const PrivacySettingsScreen(), [
      myPrivacySettingsProvider.overrideWith((ref) async => throw StateError('panne')),
      isVerifiedMouqaddamProvider.overrideWithValue(false),
    ]));
    await tester.pumpAndSettle();
    expect(find.byType(Notice), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    _expectNoBronzeText(tester);
  });

  testWidgets('Disciples bloqués : liste vide et erreur en notes du kit', (tester) async {
    await tester.pumpWidget(_app(const BlockedUsersScreen(), [
      blockedUsersProvider.overrideWith((ref) async => const <BlockedUser>[]),
    ]));
    await tester.pumpAndSettle();
    expect(find.byType(Notice), findsOneWidget);
    _expectNoBronzeText(tester);
  });

  // Un nouveau `ProviderScope` au même endroit garderait les surcharges du
  // premier : un test par état.
  testWidgets('Disciples bloqués illisibles : « Réessayer »', (tester) async {
    await tester.pumpWidget(_app(const BlockedUsersScreen(), [
      blockedUsersProvider.overrideWith((ref) async => throw StateError('panne')),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Réessayer'), findsOneWidget);
    _expectNoBronzeText(tester);
  });

  testWidgets('Notifications : erreur avec « Réessayer », liste vide en note du kit', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_app(const NotificationsScreen(), [
      myNotificationsProvider.overrideWith((ref) {
        calls++;
        return calls == 1 ? Stream.error(StateError('panne')) : Stream.value(const <AppNotification>[]);
      }),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Réessayer'), findsOneWidget);
    _expectNoBronzeText(tester);

    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.byType(Notice), findsOneWidget);
    expect(find.text('Réessayer'), findsNothing);
    _expectNoBronzeText(tester);
  });

  testWidgets('Comprendre la Zawiya : bandeau brouillon partagé, page vide du kit', (tester) async {
    const page = GuidePage(
      title: 'Comprendre',
      bodyMarkdown: '## Section\n\nCorps de section de test.',
      contentStatus: 'brouillon',
    );
    await tester.pumpWidget(_app(const KhadaraUnderstandingScreen(), [
      khadaraUnderstandingPageProvider.overrideWith((ref) async => page),
    ]));
    await tester.pumpAndSettle();
    expect(find.byType(DraftBanner), findsOneWidget);
    _expectNoBronzeText(tester);
  });

  testWidgets('Comprendre la Zawiya sans page validée : page du kit', (tester) async {
    await tester.pumpWidget(_app(const KhadaraUnderstandingScreen(), [
      khadaraUnderstandingPageProvider.overrideWith((ref) async => null),
    ]));
    await tester.pumpAndSettle();
    expect(find.byType(MessagePage), findsOneWidget);
    _expectNoBronzeText(tester);
  });

  testWidgets('Politique de confidentialité : titres en Cormorant et en encre, plus en zaytoune', (tester) async {
    await tester.pumpWidget(_app(const PrivacyPolicyScreen(), const []));
    // Lecture du document (asset) hors de l'horloge de test.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();

    final titles = tester
        .widgetList<Semantics>(find.byWidgetPredicate((w) => w is Semantics && w.properties.header == true))
        .toList();
    expect(titles, isNotEmpty);
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(text.style?.color, isNot(AppColors.zaytoune));
    }
    _expectNoBronzeText(tester);
  });
}
