// Audit des écrans refaits du 2026-11-03 (P3) : un rappel restait affiché
// « actif » alors que les notifications de l'app étaient coupées dans les
// réglages du téléphone. L'écran des rappels le dit.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/features/wird/data/wird_reminder_store.dart';
import 'package:at_tijaniya/features/wird/data/wirds_content.dart';
import 'package:at_tijaniya/features/wird/domain/wird_reminder.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_reminders_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

Widget _app({required bool notificationsOn}) => ProviderScope(
      overrides: [notificationsEnabledProvider.overrideWith((ref) async => notificationsOn)],
      child: const MaterialApp(
        locale: Locale('fr'),
        supportedLocales: [Locale('fr'), Locale('ar')],
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: WirdRemindersScreen(wird: lazim),
      ),
    );

const _message =
    "Les notifications d'At-Tijaniya sont coupées dans les réglages du téléphone : ces rappels ne sonneront pas tant qu'elles n'y sont pas autorisées.";

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await const WirdReminderStore().save(lazim.id, const [
      WirdReminderSetting(slotId: 'lazim_morning', enabled: true, hour: 7, minute: 0),
    ]);
  });

  testWidgets('notifications coupées, rappel activé : l\'écran le dit', (tester) async {
    await tester.pumpWidget(_app(notificationsOn: false));
    await tester.pumpAndSettle();
    expect(find.text(_message), findsOneWidget);
  });

  testWidgets('notifications autorisées : pas d\'avertissement', (tester) async {
    await tester.pumpWidget(_app(notificationsOn: true));
    await tester.pumpAndSettle();
    expect(find.text(_message), findsNothing);
  });
}
