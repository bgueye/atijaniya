import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase/supabase_config.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/contrast_controller.dart';
import 'core/theme/locale_controller.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/auth/presentation/reset_password_screen.dart';
import 'features/home/presentation/home_shell.dart';
import 'features/onboarding/data/onboarding_store.dart';
import 'features/onboarding/presentation/language_selection_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/profil/presentation/profile_providers.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'l10n/app_localizations.dart';

/// Orchestre le parcours P0/P1 : Splash -> Choix de langue -> Onboarding
/// (une seule fois, voir `OnboardingStore`) -> Auth (ou mode invité) ->
/// HomeShell. Flutter déduit automatiquement la directionnalité RTL de la
/// Locale (ar), donc aucune gestion manuelle du sens de lecture n'est
/// nécessaire ici.
class AtTijaniyaApp extends ConsumerStatefulWidget {
  const AtTijaniyaApp({super.key});

  @override
  ConsumerState<AtTijaniyaApp> createState() => _AtTijaniyaAppState();
}

enum _Step { splash, language, onboarding, auth, resetPassword, home }

class _AtTijaniyaAppState extends ConsumerState<AtTijaniyaApp> {
  _Step _step = _Step.splash;
  final _onboardingStore = const OnboardingStore();
  // Permet de purger les routes poussées par-dessus HomeShell (ProfilScreen,
  // Paramètres, Ma lignée...) avant de basculer `_step` — sans ça, ces routes
  // resteraient affichées par-dessus le nouvel écran racine tant qu'on ne les
  // dépile pas explicitement (le changement de `home:` de MaterialApp ne vide
  // pas la pile du Navigator existant).
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeControllerProvider);

    // Doit être synchronisé AVANT tout widget descendant construit sa
    // propre UI (`AppColors.bronze`/`emerald`/`gold` sont lues en dehors de
    // tout `BuildContext`, voir app_colors.dart) — pas un `ref.listen`, un
    // set direct dans `build()` pour garantir l'ordre.
    final highContrast = ref.watch(contrastControllerProvider);
    AppColors.setHighContrast(highContrast);

    // `_step` n'est calculé qu'une fois, juste après le choix de la langue
    // (voir `_afterLanguageChosen`) : sans ce listener, une déconnexion
    // depuis `ProfilScreen` laissait le disciple bloqué sur `HomeShell` (qui
    // affiche alors l'état "connectez-vous" sans aucun moyen d'y revenir,
    // faute de retour vers `AuthScreen`). `authStateChangesProvider` est un
    // ReplaySubject côté gotrue : la valeur rejouée à l'abonnement initial
    // (état de session au démarrage) ne déclenche pas ce callback, seules
    // les transitions ultérieures le font.
    ref.listen(authStateChangesProvider, (previous, next) {
      final event = next.valueOrNull?.event;
      if (event == AuthChangeEvent.signedOut && _step == _Step.home && mounted) {
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        setState(() => _step = _Step.auth);
      } else if (event == AuthChangeEvent.passwordRecovery && mounted) {
        // Lien de réinitialisation de mot de passe ouvert depuis l'e-mail
        // (deep link, voir SupabaseConfig.authCallbackUrl) : la session
        // "recovery" qui vient d'être établie n'autorise qu'un `updateUser`,
        // jamais un accès direct au reste de l'app tant que le mot de passe
        // n'a pas été changé.
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        setState(() => _step = _Step.resetPassword);
      } else if (event == AuthChangeEvent.signedIn &&
          _step != _Step.home &&
          _step != _Step.resetPassword &&
          mounted) {
        // Lien de confirmation d'inscription ouvert depuis l'e-mail (même
        // mécanisme) : la session est établie de façon asynchrone après le
        // démarrage de l'app, potentiellement après le calcul initial de
        // `_step` dans `_afterLanguageChosen` — sans ce cas, le disciple
        // resterait bloqué sur l'écran de connexion malgré une session
        // désormais valide.
        setState(() => _step = _Step.home);
      }
    });

    return MaterialApp(
      // Bascule le contraste = clé différente = Flutter démonte et remonte
      // tout l'arbre sous MaterialApp (Navigator et route poussées inclus),
      // au lieu d'une simple mise à jour de configuration. Nécessaire ici
      // (voir la note ci-dessus) : la quasi-totalité de l'app lit
      // `AppColors.bronze`/`emerald`/`gold` directement plutôt que via
      // `Theme.of(context)`, donc rien ne se propagerait par le mécanisme
      // habituel des `InheritedWidget` sur les écrans déjà poussés — seul
      // un remontage complet garantit que chaque `build()` relit la valeur
      // à jour. Contrepartie assumée : bascule rare et volontaire depuis
      // Paramètres, remise à zéro de la pile de navigation acceptable (la
      // session/l'auth ne sont pas perdues, elles vivent hors du widget
      // tree — voir `SupabaseConfig`/`authStateChangesProvider`).
      key: ValueKey(highContrast),
      navigatorKey: _navigatorKey,
      title: 'At-Tijaniya',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.standard,
      locale: locale,
      supportedLocales: const [Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _buildStep(),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.splash:
        return SplashScreen(onFinished: () => setState(() => _step = _Step.language));
      case _Step.language:
        // On avance automatiquement dès qu'une langue est choisie
        // (localeControllerProvider passe de null à une Locale).
        ref.listen(localeControllerProvider, (previous, next) {
          if (next != null && mounted) _afterLanguageChosen();
        });
        return const LanguageSelectionScreen();
      case _Step.onboarding:
        return OnboardingScreen(onFinished: () => setState(() => _step = _Step.auth));
      case _Step.auth:
        return AuthScreen(
          onAuthenticated: () => setState(() => _step = _Step.home),
          onContinueAsGuest: () => setState(() => _step = _Step.home),
        );
      case _Step.resetPassword:
        return ResetPasswordScreen(onDone: () => setState(() => _step = _Step.home));
      case _Step.home:
        return const HomeShell();
    }
  }

  Future<void> _afterLanguageChosen() async {
    final seen = await _onboardingStore.hasSeenOnboarding();
    if (!mounted) return;
    if (SupabaseConfig.client.auth.currentSession != null) {
      // Session restaurée par supabase_flutter au démarrage (voir
      // `main.dart`, `SupabaseConfig.init()` est attendu avant `runApp`) :
      // un disciple déjà connecté ne doit pas se reconnecter à chaque
      // lancement, ni revoir l'onboarding.
      setState(() => _step = _Step.home);
      return;
    }
    setState(() => _step = seen ? _Step.auth : _Step.onboarding);
  }
}
