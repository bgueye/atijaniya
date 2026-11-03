import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

/// Splash screen — logo Sceau-rosace sur fond zaytoune, animation discrète.
/// Priorité P0 (docs/03-architecture-ecrans.md).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    // Minuteur annulable (audit du 2026-10-04, S50) : un `Future.delayed` nu
    // se déclenchait même après le démontage du splash et réécrivait l'étape
    // de l'app — notamment par-dessus l'écran de réinitialisation ouvert par
    // un lien reçu par e-mail.
    //
    // Plus d'attente fixe de 1,6 s (audit de l'accueil du 2026-10-26, P2-1,
    // décision du porteur de projet) : Supabase, la langue et les
    // notifications sont déjà prêts quand ce widget s'affiche (`main()`), le
    // splash ne dure que le court fondu du logo, prolongeant l'écran de
    // lancement natif qui a les mêmes couleurs.
    _timer = Timer(const Duration(milliseconds: 450), () {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // La langue n'est pas toujours connue au premier lancement : sans
    // traduction, la phrase reste en français (langue par défaut de l'app).
    final tagline = AppLocalizations.of(context)?.splashTagline ?? 'La pratique de la Tijaniyya, au quotidien';
    return Scaffold(
      backgroundColor: AppColors.zaytoune,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          // Refonte du parcours d'entrée (2026-11-03, maquette
          // `parcours-entree.html`) : le nom de l'app et sa phrase sous le
          // logo. L'animation de la rosace de la maquette n'est pas reprise
          // (décision du porteur de projet du 2026-11-03) : elle aurait
          // rallongé un démarrage que l'audit du 2026-10-26 avait raccourci.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: SvgPicture.asset(
                    'assets/branding/logo-fond-sombre.svg',
                    placeholderBuilder: (context) => Icon(
                      Icons.circle_outlined,
                      color: AppColors.gold,
                      size: 96,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Nom de l'app : titre latin, police des titres du thème.
                Text(
                  'At-Tijaniya',
                  textAlign: TextAlign.center,
                  style: AppTheme.titleText(fontSize: 30, color: AppColors.offWhite, height: 1.1),
                ),
                const SizedBox(height: 6),
                Text(
                  tagline,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.secondaryOnDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
