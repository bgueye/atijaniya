import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth/sign_in_request.dart';
import 'core/supabase/supabase_config.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/contrast_controller.dart';
import 'core/theme/locale_controller.dart';
import 'features/auth/domain/auth_error_message.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/auth/presentation/reset_password_screen.dart';
import 'features/home/presentation/home_dashboard_provider.dart';
import 'features/home/presentation/home_shell.dart';
import 'features/onboarding/data/onboarding_store.dart';
import 'features/onboarding/presentation/language_selection_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/profil/presentation/profile_providers.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'l10n/app_localizations.dart';

/// Prévient quand une route dépilée ramène sur l'écran racine.
class _ReturnToRootObserver extends NavigatorObserver {
  _ReturnToRootObserver(this.onReturnToRoot);

  final VoidCallback onReturnToRoot;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute?.isFirst ?? false) onReturnToRoot();
  }
}

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

  /// Réinitialisation de mot de passe en attente (audit du 2026-10-04, S50).
  /// La session ouverte par le lien reçu par e-mail est une session
  /// complète : rien, côté serveur, n'oblige à choisir un nouveau mot de
  /// passe. Ce drapeau, enregistré sur l'appareil, garantit que l'app ramène
  /// sur l'écran de réinitialisation tant que le mot de passe n'a pas été
  /// changé (ou la réinitialisation abandonnée, ce qui déconnecte) — y
  /// compris après une fermeture puis réouverture de l'app.
  static const _recoveryPendingKey = 'password_recovery_pending';

  Future<void> _setRecoveryPending(bool pending) async {
    final prefs = await SharedPreferences.getInstance();
    if (pending) {
      await prefs.setBool(_recoveryPendingKey, true);
    } else {
      await prefs.remove(_recoveryPendingKey);
    }
  }

  // Permet de purger les routes poussées par-dessus HomeShell (ProfilScreen,
  // Paramètres, Ma lignée...) avant de basculer `_step` — sans ça, ces routes
  // resteraient affichées par-dessus le nouvel écran racine tant qu'on ne les
  // dépile pas explicitement (le changement de `home:` de MaterialApp ne vide
  // pas la pile du Navigator existant).
  final _navigatorKey = GlobalKey<NavigatorState>();

  /// Messages affichés hors de tout écran (lien d'e-mail refusé, P1-1).
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

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
      // Lien d'e-mail expiré ou déjà utilisé (audit de l'authentification du
      // 2026-10-27, P1-1) : l'erreur arrivait sur ce flux et était ignorée,
      // l'app s'ouvrait sans rien dire. Message, puis écran de connexion pour
      // un invité, d'où l'on redemande un lien.
      if (next is AsyncError && isAuthLinkError(next.error!) && mounted) {
        _showAuthLinkExpired();
        return;
      }
      final event = next.valueOrNull?.event;
      if (event == AuthChangeEvent.signedOut && _step == _Step.home && mounted) {
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        setState(() => _step = _Step.auth);
        // Session expirée (rafraîchissement refusé) : le disciple revenait à
        // la connexion sans savoir pourquoi (audit de l'authentification du
        // 2026-10-27, P3-4). Une déconnexion voulue n'a pas de message.
        if (next.valueOrNull?.signOutReason == SignOutReason.sessionExpired) {
          _showAuthMessage((l10n) => l10n.authSessionExpired);
        }
      } else if (event == AuthChangeEvent.passwordRecovery && mounted) {
        // Lien de réinitialisation de mot de passe ouvert depuis l'e-mail
        // (deep link, voir SupabaseConfig.authCallbackUrl). La session
        // "recovery" est une session complète côté serveur : c'est l'app qui
        // impose de changer le mot de passe avant tout accès au reste, via
        // `_recoveryPendingKey` (voir plus haut).
        _setRecoveryPending(true);
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        setState(() => _step = _Step.resetPassword);
      } else if (event == AuthChangeEvent.signedIn && _step != _Step.home && _step != _Step.resetPassword && mounted) {
        // Lien de confirmation d'inscription ouvert depuis l'e-mail (même
        // mécanisme) : la session est établie de façon asynchrone après le
        // démarrage de l'app, potentiellement après le calcul initial de
        // `_step` dans `_afterLanguageChosen` — sans ce cas, le disciple
        // resterait bloqué sur l'écran de connexion malgré une session
        // désormais valide.
        setState(() => _step = _Step.home);
      }
    });

    // Un invité demande à se connecter (voir `signInRequestProvider`).
    // Langue du compte connecté écrite dans `profiles.locale` (P2-1), au
    // changement de langue comme à la connexion : la colonne restait à sa
    // valeur par défaut.
    ref.listen(localeControllerProvider, (previous, next) => _syncProfileLocale());
    ref.listen(currentUserIdProvider, (previous, next) => _syncProfileLocale());

    ref.listen(signInRequestProvider, (previous, next) {
      if (!mounted || _step != _Step.home) return;
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      setState(() => _step = _Step.auth);
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
      scaffoldMessengerKey: _scaffoldMessengerKey,
      // Au retour sur l'écran racine (wird terminé, tasbih avancé, rappel
      // modifié depuis une carte de l'accueil), le tableau de bord doit
      // refléter ce qui vient d'être fait : il n'était rechargé qu'au
      // changement d'onglet.
      navigatorObservers: [
        _ReturnToRootObserver(() {
          if (mounted) ref.invalidate(homeDashboardProvider);
        }),
      ],
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
        // Ne quitte le splash que si l'étape n'a pas déjà été fixée par un
        // évènement d'authentification arrivé pendant l'animation. Langue
        // déjà enregistrée (P2-1) : pas d'écran de langue, on passe
        // directement à la suite du parcours.
        return SplashScreen(onFinished: () {
          if (_step != _Step.splash) return;
          if (ref.read(localeControllerProvider) != null) {
            _step = _Step.language;
            _afterLanguageChosen();
          } else {
            setState(() => _step = _Step.language);
          }
        });
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
        return ResetPasswordScreen(
          onDone: () {
            _setRecoveryPending(false);
            setState(() => _step = _Step.home);
          },
          // Abandon : on ferme la session ouverte par le lien, sinon le
          // disciple resterait connecté avec un mot de passe qu'il ne
          // connaît plus.
          onCancel: () async {
            await _setRecoveryPending(false);
            try {
              await SupabaseConfig.client.auth.signOut();
            } catch (_) {}
            if (mounted) setState(() => _step = _Step.auth);
          },
        );
      case _Step.home:
        return const HomeShell();
    }
  }

  void _showAuthLinkExpired() {
    if (ref.read(currentUserIdProvider) == null && _step == _Step.home) {
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      setState(() => _step = _Step.auth);
    }
    _showAuthMessage((l10n) => l10n.authLinkExpired);
  }

  /// Message de session affiché hors de tout écran. Après la reconstruction :
  /// le messager n'existe qu'une fois MaterialApp monté (lien ouvert pendant
  /// le splash).
  void _showAuthMessage(String Function(AppLocalizations l10n) message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = _scaffoldMessengerKey.currentState;
      if (messenger == null) return;
      final l10n = AppLocalizations.of(messenger.context);
      if (l10n == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message(l10n)), duration: const Duration(seconds: 8)));
    });
  }

  /// Dernière langue écrite dans le profil, pour ne l'écrire qu'une fois.
  String? _syncedProfileLocale;

  /// Écrit la langue de l'app dans `profiles.locale` du compte connecté — au
  /// mieux : un échec (hors ligne) sera retenté au prochain changement.
  void _syncProfileLocale() {
    final locale = ref.read(localeControllerProvider)?.languageCode;
    if (locale == null || ref.read(currentUserIdProvider) == null || locale == _syncedProfileLocale) return;
    _syncedProfileLocale = locale;
    ref.read(profileRepositoryProvider).updateMyLocale(locale).catchError((_) => _syncedProfileLocale = null);
  }

  Future<void> _afterLanguageChosen() async {
    _syncProfileLocale();
    final seen = await _onboardingStore.hasSeenOnboarding();
    final recoveryPending = (await SharedPreferences.getInstance()).getBool(_recoveryPendingKey) ?? false;
    if (!mounted) return;
    // Un évènement d'authentification a déjà fixé l'étape pendant le choix
    // de la langue (lien e-mail) : on ne la réécrit pas.
    if (_step != _Step.language) return;
    // `currentUserIdProvider` plutôt que la session lue directement : même
    // information, remplaçable dans les tests du parcours de démarrage.
    final signedIn = ref.read(currentUserIdProvider) != null;
    if (signedIn && recoveryPending) {
      setState(() => _step = _Step.resetPassword);
      return;
    }
    if (signedIn) {
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
