import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/locale_controller.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/home/presentation/home_shell.dart';
import 'features/onboarding/presentation/language_selection_screen.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'l10n/app_localizations.dart';

/// Orchestre le parcours P0 : Splash -> Choix de langue -> Auth (ou mode
/// invité) -> HomeShell. Flutter déduit automatiquement la directionnalité
/// RTL de la Locale (ar), donc aucune gestion manuelle du sens de lecture
/// n'est nécessaire ici.
class AtTijaniyaApp extends ConsumerStatefulWidget {
  const AtTijaniyaApp({super.key});

  @override
  ConsumerState<AtTijaniyaApp> createState() => _AtTijaniyaAppState();
}

enum _Step { splash, language, auth, home }

class _AtTijaniyaAppState extends ConsumerState<AtTijaniyaApp> {
  _Step _step = _Step.splash;

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeControllerProvider);

    return MaterialApp(
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
          if (next != null && mounted) setState(() => _step = _Step.auth);
        });
        return const LanguageSelectionScreen();
      case _Step.auth:
        return AuthScreen(
          onAuthenticated: () => setState(() => _step = _Step.home),
          onContinueAsGuest: () => setState(() => _step = _Step.home),
        );
      case _Step.home:
        return const HomeShell();
    }
  }
}
