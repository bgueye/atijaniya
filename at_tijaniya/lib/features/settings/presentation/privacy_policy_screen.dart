import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/legal_document.dart';

/// Chemin de la politique de confidentialité dans les ressources de l'app —
/// copie exacte de `docs/politique-de-confidentialite.md`, vérifiée par
/// `legal_document_test.dart`.
const privacyPolicyAsset = 'assets/legal/politique-de-confidentialite.md';

/// Politique de confidentialité, consultable dans l'app depuis l'inscription
/// et depuis « À propos » (audit de l'authentification du 2026-10-27, P2-5) :
/// l'inscription demandait de l'accepter sans qu'elle soit lisible nulle
/// part. Le texte fait foi tel qu'il est rédigé, en français ; en interface
/// arabe, une ligne le signale.
class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  // Lu une seule fois par ouverture de l'écran, pas à chaque reconstruction.
  // Sans le cache de `rootBundle` : le texte est court, et l'écran ne le relit
  // qu'à sa prochaine ouverture.
  late final Future<List<LegalBlock>> _blocks =
      rootBundle.loadString(privacyPolicyAsset, cache: false).then(parseLegalMarkdown);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyPolicyTitle)),
      body: SafeArea(
        child: FutureBuilder<List<LegalBlock>>(
          future: _blocks,
          builder: (context, snapshot) {
            final blocks = snapshot.data;
            if (blocks == null) {
              return Center(child: CircularProgressIndicator(color: AppColors.emerald));
            }
            return SelectionArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (isArabic)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(l10n.privacyPolicyFrenchOnly, style: TextStyle(color: AppColors.secondaryInk)),
                    ),
                  // Document rédigé en français : de gauche à droite, quelle
                  // que soit la langue de l'interface.
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [for (final block in blocks) _LegalBlockView(block)],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LegalBlockView extends StatelessWidget {
  const _LegalBlockView(this.block);

  final LegalBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    const body = TextStyle(color: AppColors.ink, fontSize: 15, height: 1.5);
    Text rich(TextStyle style) => Text.rich(
          TextSpan(children: [
            for (final (text, bold) in splitBold(block.text))
              TextSpan(text: text, style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null),
          ]),
          style: style,
        );

    switch (block.kind) {
      case LegalBlockKind.title:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(header: true, child: rich(theme.titleLarge!.copyWith(color: AppColors.zaytoune))),
        );
      case LegalBlockKind.heading:
        return Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Semantics(
            header: true,
            child: rich(const TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: AppColors.ink)),
          ),
        );
      case LegalBlockKind.subheading:
        return Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Semantics(
            header: true,
            child: rich(const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.ink)),
          ),
        );
      case LegalBlockKind.bullet:
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  ', style: body),
              Expanded(child: rich(body)),
            ],
          ),
        );
      case LegalBlockKind.paragraph:
        return Padding(padding: const EdgeInsets.only(bottom: 10), child: rich(body));
    }
  }
}
