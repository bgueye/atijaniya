// Kit de composants (docs/kit/components/BottomSheet) : feuille du bas qui
// montre un contenu en entier sans quitter l'écran (réponse d'un cas de
// rattrapage avec sa source, texte entier d'une condition). Extraite de
// `home_discover_section.dart` (`_showSheet`, refonte de l'accueil du
// 2026-11-01).

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import 'content_text.dart';
import 'eyebrow.dart';

/// Ouvre la feuille.
///
/// - [eyebrow] : de quoi il s'agit (« Situation · Erreur »).
/// - [children] : le contenu, jamais tronqué — un texte religieux s'affiche
///   en entier ; la feuille défile au-delà de 85 % de la hauteur d'écran.
/// - [source] : déjà mise en forme (« Source : … »), en `secondaire`
///   italique, sans italique si elle est en arabe (l'écriture arabe n'en a
///   pas).
/// - [onOpenFullPage] : action principale « Ouvrir la page complète »,
///   appelée une fois la feuille fermée, avec le contexte de l'écran
///   d'origine. Sans elle, seul « Fermer » reste.
Future<void> showContentSheet(
  BuildContext context, {
  required String eyebrow,
  required List<Widget> children,
  String? source,
  VoidCallback? onOpenFullPage,
  String? openLabel,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.offWhite,
    // Coins du haut à 22 (fiche du kit), plus doux que les cartes : la
    // feuille se lit comme une page posée sur l'écran.
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Eyebrow(eyebrow),
              const SizedBox(height: 10),
              for (final child in children) ...[child, const SizedBox(height: 8)],
              if (source != null && source.isNotEmpty) _SheetSource(source),
              const SizedBox(height: 8),
              // `Wrap` plutôt que `Row` : à forte taille de texte, le bouton
              // principal passe sous « Fermer » au lieu de déborder.
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(onPressed: () => Navigator.of(sheetContext).pop(), child: Text(l10n.commonClose)),
                  if (onOpenFullPage != null)
                    FilledButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        onOpenFullPage();
                      },
                      child: Text(openLabel ?? l10n.commonOpenFullPage),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SheetSource extends StatelessWidget {
  const _SheetSource(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final arabic = contentDirection(text) == TextDirection.rtl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ContentText(
        text,
        style: TextStyle(
          fontSize: arabic ? 13 : 12.5,
          fontStyle: arabic ? FontStyle.normal : FontStyle.italic,
          color: AppColors.secondaryInk,
          height: 1.4,
        ),
      ),
    );
  }
}
