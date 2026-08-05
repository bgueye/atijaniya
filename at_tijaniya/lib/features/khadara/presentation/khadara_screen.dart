import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Module Khadara — priorité P1. Placeholder en attendant le calendrier des
/// évènements géolocalisé, l'annuaire des zawiyas et le direct natif.
class KhadaraScreen extends StatelessWidget {
  const KhadaraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _ComingSoon(title: l10n.khadaraComingSoonTitle, body: l10n.khadaraComingSoonBody);
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
