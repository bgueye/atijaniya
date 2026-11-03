import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import 'auth_widgets.dart';

/// Entrée de l'app pour un disciple sans session (refonte du 2026-11-03,
/// maquette `docs/maquettes/parcours-entree.html`, décisions validées du
/// 2026-11-02). Remplace l'écran de connexion comme porte d'entrée : trois
/// choix au même niveau de lecture, « Découvrir sans compte » étant un vrai
/// bouton à côté de « Créer un compte » (il n'était qu'un lien sous le
/// formulaire de connexion).
///
/// Les trois raisons de créer un compte sont celles de la carte invité du
/// Profil, mot pour mot (mêmes clés de traduction), pour que le disciple lise
/// la même chose aux deux endroits. Elles ne promettent pas de sauvegarder
/// la pratique : séries et historique restent sur le téléphone, avec ou sans
/// compte (correction du 2026-11-02), ce que la note du bas dit.
///
/// En-tête sur parchemin avec le logo clair, et non sur zaytoune comme dans
/// la maquette : CLAUDE.md réserve ce vert à la pratique et à l'accueil
/// (décision du porteur de projet du 2026-11-03).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onCreateAccount, required this.onSignIn, required this.onGuest});

  final VoidCallback onCreateAccount;
  final VoidCallback onSignIn;
  final VoidCallback onGuest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final benefits = [l10n.profileGuestBenefit1, l10n.profileGuestBenefit2, l10n.profileGuestBenefit3];

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/branding/logo-fond-clair-1024.png',
                          width: 84,
                          height: 84,
                          excludeFromSemantics: true,
                          errorBuilder: (context, error, stackTrace) => const SizedBox(height: 84),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.authTitle,
                          textAlign: TextAlign.center,
                          style: entryTitleStyle(context, fontSize: 28),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.welcomeTagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: AppColors.secondaryInk),
                      ),
                      const SizedBox(height: 22),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < benefits.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Même pastille numérotée que la carte
                                      // invité du Profil.
                                      Container(
                                        width: 22,
                                        height: 22,
                                        alignment: Alignment.center,
                                        decoration:
                                            const BoxDecoration(color: AppColors.emeraldSoft, shape: BoxShape.circle),
                                        child: Text('${i + 1}',
                                            style: TextStyle(
                                                fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.emerald)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(benefits[i],
                                            style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.ink)),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 6),
                              FilledButton(onPressed: onCreateAccount, child: Text(l10n.authSignUpAction)),
                              const SizedBox(height: 8),
                              OutlinedButton(onPressed: onGuest, child: Text(l10n.welcomeGuest)),
                              const SizedBox(height: 2),
                              TextButton(onPressed: onSignIn, child: Text(l10n.profileGuestHaveAccount)),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 20),
                      Text(
                        l10n.welcomeNote,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.secondaryInk),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
