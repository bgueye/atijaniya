// Refonte du parcours d'entrée (2026-11-03, maquette
// `docs/maquettes/parcours-entree.html`, décisions validées le 2026-11-02 et
// le 2026-11-03) : langue choisie avant d'être enregistrée, trois écrans de
// découverte avec aperçu, étape « Rappels » facultative, écran d'entrée à
// trois choix, « Nom affiché », règles du mot de passe cochées en direct,
// renvoi de l'e-mail avec un délai visible.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:at_tijaniya/core/theme/locale_controller.dart';
import 'package:at_tijaniya/features/auth/presentation/auth_screen.dart';
import 'package:at_tijaniya/features/auth/presentation/auth_widgets.dart';
import 'package:at_tijaniya/features/auth/presentation/reset_password_screen.dart';
import 'package:at_tijaniya/features/auth/presentation/welcome_screen.dart';
import 'package:at_tijaniya/features/khadara/domain/khadara_models.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_providers.dart';
import 'package:at_tijaniya/features/onboarding/presentation/language_selection_screen.dart';
import 'package:at_tijaniya/features/onboarding/presentation/onboarding_reminders_screen.dart';
import 'package:at_tijaniya/features/onboarding/presentation/onboarding_screen.dart';
import 'package:at_tijaniya/features/wird/data/wird_notification_service.dart';
import 'package:at_tijaniya/features/wird/data/wird_reminder_bulk.dart';
import 'package:at_tijaniya/features/wird/data/wird_reminder_slots.dart';
import 'package:at_tijaniya/features/wird/data/wirds_content.dart';
import 'package:at_tijaniya/features/wird/domain/wird_models.dart';
import 'package:at_tijaniya/features/wird/domain/wird_reminder.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

Widget _app(Widget home, {Locale locale = const Locale('fr'), List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
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
}

KhadaraEvent _event(String id, String title, {bool recurring = false}) => KhadaraEvent(
      id: id,
      zawiyaId: 'z1',
      zawiyaName: 'Zawiya de test',
      title: title,
      type: KhadaraEventType.ziyara,
      startsAt: DateTime(2026, 12, 25, 9),
      isRecurring: recurring,
    );

/// Service de notifications sans plateforme : autorisation et échecs à la
/// demande, créneaux programmés relevés.
class _FakeNotifications implements WirdNotificationService {
  bool granted = true;
  int permissionRequests = 0;
  final scheduled = <String, ({int hour, int minute})>{};

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted;
  }

  @override
  Future<void> scheduleReminder({
    required WirdReminderSlot slot,
    required WirdReminderSetting setting,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async {
    if (setting.enabled) scheduled[slot.id] = (hour: setting.hour, minute: setting.minute);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Client d'authentification sans serveur : l'inscription réussit sans
/// session (confirmation par e-mail activée), les renvois sont relevés.
class _FakeAuth extends Fake implements GoTrueClient {
  final resent = <String>[];
  Map<String, dynamic>? signUpData;

  @override
  Future<AuthResponse> signUp({
    String? email,
    String? phone,
    required String password,
    String? emailRedirectTo,
    Map<String, dynamic>? data,
    String? captchaToken,
    OtpChannel channel = OtpChannel.sms,
  }) async {
    signUpData = data;
    return AuthResponse();
  }

  @override
  Future<ResendResponse> resend({
    String? email,
    String? phone,
    required OtpType type,
    String? emailRedirectTo,
    String? captchaToken,
  }) async {
    resent.add(email ?? '');
    return ResendResponse();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('heures par défaut des rappels (validées le 2026-11-03)', () {
    test('Lazim 07:00 et 19:00, Wazifa 18:00, Hadratou-l-Jouma 17:00', () {
      final hours = {
        for (final slots in wirdReminderSlots.values)
          for (final slot in slots) slot.id: WirdReminderSetting.defaultFor(slot).hour,
      };
      expect(hours, {'lazim_morning': 7, 'lazim_evening': 19, 'wazifa_daily': 18, 'hadratou_jouma_weekly': 17});
    });
  });

  group('langue', () {
    testWidgets("toucher l'arabe le sélectionne et passe l'écran en arabe, sans rien enregistrer", (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(_app(Consumer(builder: (context, ref, _) {
        container = ProviderScope.containerOf(context);
        return const LanguageSelectionScreen();
      }), overrides: [initialLocaleProvider.overrideWithValue(null)]));
      await tester.pumpAndSettle();
      // Titre dans les deux langues, phrase de l'app sous chaque langue.
      expect(find.text('Choisissez votre langue'), findsOneWidget);
      expect(find.text('اختر لغتك'), findsOneWidget);
      expect(find.text('Vos wirds, guidés pas à pas'), findsOneWidget);
      expect(find.text('أورادك، خطوة بخطوة'), findsOneWidget);
      expect(find.text('Vous pourrez la changer à tout moment depuis le Profil.'), findsOneWidget);

      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();
      expect(container.read(localeControllerProvider), isNull);
      expect(find.text('استمرار'), findsOneWidget);
      expect(Directionality.of(tester.element(find.text('استمرار'))), TextDirection.rtl);

      await tester.tap(find.text('استمرار'));
      await tester.pumpAndSettle();
      expect(container.read(localeControllerProvider), const Locale('ar'));
    });
  });

  group('découverte', () {
    testWidgets('trois écrans, le dernier mène à la suite par « Continuer »', (tester) async {
      var finished = 0;
      await tester.pumpWidget(_app(OnboardingScreen(onFinished: () => finished++),
          overrides: [upcomingEventsProvider.overrideWith((ref) async => const [])]));
      await tester.pumpAndSettle();
      expect(find.text('BIENVENUE SUR AT-TIJANIYA'), findsOneWidget); // Eyebrow du kit, en capitales
      expect(find.text('Vos wirds, guidés pas à pas'), findsOneWidget);
      // Aperçu : les bandeaux des trois wirds.
      expect(find.text('Lazim'), findsOneWidget);
      expect(find.text('Hadratou-l-Jouma'), findsOneWidget);

      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
      expect(find.text('Une communauté de disciples'), findsOneWidget);
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(finished, 1);
    });

    testWidgets('aperçu Zawiyas : les prochains rendez-vous de la base, sans les hebdomadaires', (tester) async {
      await tester.pumpWidget(_app(OnboardingScreen(onFinished: () {}), overrides: [
        upcomingEventsProvider.overrideWith((ref) async => [
              _event('w', 'Wazifa du vendredi', recurring: true),
              _event('a', 'Ziarra de test'),
              _event('b', 'Gamou de test'),
            ]),
      ]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
      expect(find.text('Ziarra de test'), findsOneWidget);
      expect(find.text('Gamou de test'), findsOneWidget);
      expect(find.text('Wazifa du vendredi'), findsNothing);
    });

    // Audit des écrans refaits du 2026-11-03 (P3) : le retour système
    // fermait l'app depuis la deuxième page.
    testWidgets('retour système : la page précédente de la découverte', (tester) async {
      await tester.pumpWidget(_app(OnboardingScreen(onFinished: () {}),
          overrides: [upcomingEventsProvider.overrideWith((ref) async => const [])]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
      expect(find.text('Vos wirds, guidés pas à pas'), findsNothing);

      final popped = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(popped, isTrue, reason: "l'app ne doit pas se fermer");
      expect(find.text('Vos wirds, guidés pas à pas'), findsOneWidget);
    });

    testWidgets('« Passer » mène aussi à la suite', (tester) async {
      var finished = 0;
      await tester.pumpWidget(_app(OnboardingScreen(onFinished: () => finished++),
          overrides: [upcomingEventsProvider.overrideWith((ref) async => const [])]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Passer'));
      await tester.pumpAndSettle();
      expect(finished, 1);
    });
  });

  group('rappels', () {
    testWidgets('quotidiens cochés par défaut ; « Activer » passe les créneaux choisis', (tester) async {
      Set<String>? asked;
      var finished = 0;
      await tester.pumpWidget(_app(OnboardingRemindersScreen(
        onFinished: () => finished++,
        enable: ({required List<Wird> wirds, required Set<String> slotIds, required Locale locale}) async {
          asked = slotIds;
          return BulkReminderOutcome.done;
        },
      )));
      await tester.pumpAndSettle();
      expect(find.text('19:00'), findsOneWidget);
      expect(find.text('Activer 3 rappels'), findsOneWidget);

      await tester.tap(find.text('Rappel du vendredi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activer 4 rappels'));
      await tester.pumpAndSettle();
      expect(asked, {'lazim_morning', 'lazim_evening', 'wazifa_daily', 'hadratou_jouma_weekly'});
      expect(finished, 1);
    });

    testWidgets('« Plus tard » passe sans rien activer', (tester) async {
      var enabled = 0;
      var finished = 0;
      await tester.pumpWidget(_app(OnboardingRemindersScreen(
        onFinished: () => finished++,
        enable: ({required List<Wird> wirds, required Set<String> slotIds, required Locale locale}) async {
          enabled++;
          return BulkReminderOutcome.done;
        },
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();
      expect(enabled, 0);
      expect(finished, 1);
    });

    testWidgets('notifications refusées : le parcours continue et le dit', (tester) async {
      var finished = 0;
      await tester.pumpWidget(_app(OnboardingRemindersScreen(
        onFinished: () => finished++,
        enable: ({required List<Wird> wirds, required Set<String> slotIds, required Locale locale}) async =>
            BulkReminderOutcome.permissionDenied,
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activer 3 rappels'));
      await tester.pumpAndSettle();
      expect(finished, 1);
      expect(find.text('Autorisez les notifications dans les réglages du téléphone pour activer ces rappels.'),
          findsOneWidget);
    });

    test('activation groupée : une seule demande, heures par défaut, réglages relus par le guide', () async {
      final notifications = _FakeNotifications();
      final outcome = await enableWirdReminders(
        wirds: const [lazim, wazifa, hadratouJouma],
        slotIds: {'lazim_evening', 'wazifa_daily'},
        locale: const Locale('fr'),
        notifications: notifications,
      );
      expect(outcome, BulkReminderOutcome.done);
      expect(notifications.permissionRequests, 1);
      expect(notifications.scheduled, {'lazim_evening': (hour: 19, minute: 0), 'wazifa_daily': (hour: 18, minute: 0)});
      final prefs = await SharedPreferences.getInstance();
      final lazimSaved = jsonDecode(prefs.getString('wird_reminders_lazim')!) as List<dynamic>;
      expect(lazimSaved.single, {'slotId': 'lazim_evening', 'enabled': true, 'hour': 19, 'minute': 0});
      expect(prefs.getString('wird_reminders_hadratou_jouma'), isNull);
    });

    test('activation groupée refusée : rien de programmé ni d\'enregistré', () async {
      final notifications = _FakeNotifications()..granted = false;
      final outcome = await enableWirdReminders(
        wirds: const [lazim],
        slotIds: {'lazim_morning'},
        locale: const Locale('fr'),
        notifications: notifications,
      );
      expect(outcome, BulkReminderOutcome.permissionDenied);
      expect(notifications.scheduled, isEmpty);
      expect((await SharedPreferences.getInstance()).getString('wird_reminders_lazim'), isNull);
    });
  });

  testWidgets("entrée : trois choix, dont « Découvrir sans compte », et ce qu'un compte apporte", (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_app(WelcomeScreen(
      onCreateAccount: () => calls.add('signup'),
      onSignIn: () => calls.add('login'),
      onGuest: () => calls.add('guest'),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Retrouver vos condisciples, en privé et seulement si vous l\'acceptez'), findsOneWidget);
    expect(find.textContaining('reste sur ce téléphone'), findsOneWidget);
    await tester.tap(find.text('Créer un compte'));
    await tester.tap(find.text('Découvrir sans compte'));
    await tester.tap(find.text("J'ai déjà un compte · Se connecter"));
    expect(calls, ['signup', 'guest', 'login']);
  });

  group('compte', () {
    testWidgets('« Nom affiché » et sa mention ; bouton grisé sous 8 caractères ; règles cochées', (tester) async {
      await tester.pumpWidget(_app(AuthScreen(onAuthenticated: () {}, onBack: () {}, initialSignUp: true)));
      await tester.pumpAndSettle();
      expect(find.text('Nom affiché'), findsOneWidget);
      expect(find.text('Visible par la communauté sur vos publications. Un prénom suffit.'), findsOneWidget);
      expect(find.text('Nom complet'), findsNothing);

      ElevatedButton button() => tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Créer un compte'));
      expect(button().onPressed, isNull);

      final handle = tester.ensureSemantics();
      await tester.enterText(find.byType(TextFormField).last, 'abcdefg1');
      await tester.pump();
      expect(button().onPressed, isNotNull);
      expect(find.bySemanticsLabel('8 caractères minimum, respectée'), findsOneWidget);
      expect(find.bySemanticsLabel('Des lettres et au moins un chiffre (conseillé), respectée'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('« Retour » et le retour système ramènent en arrière', (tester) async {
      var back = 0;
      await tester.pumpWidget(_app(AuthScreen(onAuthenticated: () {}, onBack: () => back++)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();
      expect(back, 1);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(back, 2);
    });

    testWidgets("boîte mail : l'adresse, et le renvoi qui attend son délai", (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = _FakeAuth();
      await tester.pumpWidget(_app(AuthScreen(
        onAuthenticated: () {},
        onBack: () {},
        initialSignUp: true,
        resendCooldown: const Duration(seconds: 3),
        auth: auth,
      )));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Bocar');
      await tester.enterText(fields.at(1), 'disciple@example.com');
      await tester.enterText(fields.at(2), 'motdepasse1');
      // Une image pour que le bouton, grisé sous 8 caractères, se réactive.
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Créer un compte'));
      await tester.pumpAndSettle();
      expect(auth.signUpData, {'display_name': 'Bocar'});

      expect(find.text('Vérifiez votre boîte mail'), findsOneWidget);
      expect(find.text('disciple@example.com'), findsOneWidget);
      expect(find.text("Renvoyer l'e-mail · dans 3 s"), findsOneWidget);
      await tester.tap(find.text("Renvoyer l'e-mail · dans 3 s"));
      expect(auth.resent, isEmpty);

      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.text("Renvoyer l'e-mail"));
      await tester.pump();
      expect(auth.resent, ['disciple@example.com']);
      // Le délai repart après le renvoi.
      expect(find.text("Renvoyer l'e-mail · dans 3 s"), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  // Audit des écrans refaits du 2026-11-03 (P3).
  test('règle « lettres » : une vraie lettre, de toute écriture, pas la ponctuation', () {
    final l10n = lookupAppLocalizations(const Locale('fr'));
    bool letters(String p) => newPasswordRules(p, l10n)[1].met;
    expect(letters('12345678!'), isFalse);
    expect(letters('abcd1234'), isTrue);
    expect(letters('سلام1234'), isTrue);
  });

  testWidgets("boîte mail : « Retour » mène à la connexion, adresse gardée", (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var left = 0;
    await tester.pumpWidget(_app(AuthScreen(
      onAuthenticated: () {},
      onBack: () => left++,
      initialSignUp: true,
      resendCooldown: const Duration(seconds: 3),
      auth: _FakeAuth(),
    )));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Bocar');
    await tester.enterText(fields.at(1), 'disciple@example.com');
    await tester.enterText(fields.at(2), 'motdepasse1');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Créer un compte'));
    await tester.pumpAndSettle();
    expect(find.text('Vérifiez votre boîte mail'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(left, 0, reason: "l'écran n'est pas quitté");
    expect(find.widgetWithText(TextFormField, 'disciple@example.com'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('nouveau mot de passe : « Enregistrer » grisé sous 8 caractères, « Identiques » coché', (tester) async {
    await tester.pumpWidget(_app(ResetPasswordScreen(onDone: () {}, onCancel: () {})));
    await tester.pumpAndSettle();
    ElevatedButton button() => tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button().onPressed, isNull);
    expect(find.text('Abandonner et me déconnecter'), findsOneWidget);

    final handle = tester.ensureSemantics();
    await tester.enterText(find.byType(TextFormField).first, 'nouveau123');
    await tester.enterText(find.byType(TextFormField).last, 'nouveau123');
    await tester.pump();
    expect(button().onPressed, isNotNull);
    expect(find.bySemanticsLabel('Identiques, respectée'), findsOneWidget);
    handle.dispose();
  });
}
