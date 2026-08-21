import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/donation_amount.dart';
import 'donation_providers.dart';

/// Faire un don — don ponctuel, priorité P1 (docs/03-architecture-ecrans.md).
///
/// IMPORTANT (voir `donation_repository.dart`) : aucun prestataire de
/// paiement n'est encore choisi pour le projet (Orange Money/Wave/Stripe...
/// « à trancher séparément », `docs/06-architecture-backend.md`). Cet écran
/// ne fait donc jamais transiter de paiement réel : il enregistre
/// uniquement l'intention de don (`donations`, `status = 'pending'`) puis
/// affiche un état honnête indiquant que le paiement en ligne n'est pas
/// encore disponible — même logique que l'audio des Wirds ou « Comprendre
/// la Khadara », pas de fonctionnalité simulée.
class DonationScreen extends ConsumerStatefulWidget {
  const DonationScreen({super.key});

  @override
  ConsumerState<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends ConsumerState<DonationScreen> {
  final _customAmountController = TextEditingController();
  int? _selectedPreset;
  bool _submitting = false;
  bool _submitted = false;
  String? _errorMessage;

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  double? get _effectiveAmount => _selectedPreset != null
      ? _selectedPreset!.toDouble()
      : parseDonationAmount(_customAmountController.text);

  void _selectPreset(int amount) {
    setState(() {
      _selectedPreset = amount;
      _customAmountController.clear();
      _errorMessage = null;
    });
  }

  void _onCustomAmountChanged(String _) {
    setState(() {
      _selectedPreset = null;
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final amount = _effectiveAmount;
    if (amount == null) {
      setState(() => _errorMessage = l10n.donationAmountInvalid);
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(donationRepositoryProvider)
          .recordDonationIntent(amount: amount);
      if (mounted) setState(() => _submitted = true);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = l10n.donationSubmitError);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.donationTitle)),
      body: _submitted ? _DonationRecordedState(l10n: l10n) : _buildForm(l10n),
    );
  }

  Widget _buildForm(AppLocalizations l10n) {
    // `SafeArea` : évite que le bouton de don se retrouve masqué sous la
    // barre de navigation Android (3 boutons).
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.donationSubtitle,
                style: TextStyle(color: AppColors.bronze, fontSize: 15)),
            const SizedBox(height: 24),
            Row(
              children: [
                for (final amount in donationPresetAmounts) ...[
                  Expanded(
                    child: _AmountChip(
                      amount: amount,
                      selected: _selectedPreset == amount,
                      onTap: () => _selectPreset(amount),
                    ),
                  ),
                  if (amount != donationPresetAmounts.last)
                    const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _customAmountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
              ],
              onChanged: _onCustomAmountChanged,
              decoration: InputDecoration(
                labelText: l10n.donationCustomAmountLabel,
                hintText: l10n.donationCustomAmountHint,
                suffixText: 'F CFA',
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(_errorMessage!,
                  style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 28),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.zaytoune),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.zaytoune),
                    )
                  : Text(l10n.donationSubmitButton),
            ),
          ],
        ),
      ),
    );
  }
}

/// Puce de montant suggéré — `Container` explicite plutôt qu'un `ChoiceChip`,
/// même approche que `_QuickTargetPill` (`free_wird_screen.dart`) et
/// `_RepetitionBadge` (`wird_detail_screen.dart`) : le thème M3 par défaut de
/// l'app (aucun `chipTheme` personnalisé, voir `app_theme.dart`) ne rend pas
/// les couleurs de marque de façon fiable sur ce widget.
class _AmountChip extends StatelessWidget {
  const _AmountChip(
      {required this.amount, required this.selected, required this.onTap});

  final int amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.goldSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AppColors.gold : AppColors.bronze,
              width: selected ? 1.5 : 1),
        ),
        child: Text(
          _formatXof(amount),
          // `textDirection` explicite : un montant doit toujours se lire
          // chiffres-puis-devise, même en contexte arabe (RTL) — sans cela,
          // le séparateur de milliers (espace, neutre en bidi) fait
          // réordonner "10 000 F" en "F 000 10" par l'algorithme bidi
          // Unicode (chaque groupe séparé par un espace redevient un run
          // indépendant, réordonné selon la direction du paragraphe RTL).
          textDirection: TextDirection.ltr,
          style: TextStyle(
            color: AppColors.ink,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Formate un montant en F CFA avec séparateur de milliers (`2000` → `2 000 F`).
String _formatXof(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return '$buffer F';
}

class _DonationRecordedState extends StatelessWidget {
  const _DonationRecordedState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                  color: AppColors.goldSoft, shape: BoxShape.circle),
              child:
                  Icon(Icons.favorite, color: AppColors.gold, size: 32),
            ),
            const SizedBox(height: 20),
            Text(l10n.donationRecordedTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(l10n.donationRecordedBody,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.bronze)),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.donationRecordedBackButton),
            ),
          ],
        ),
      ),
    );
  }
}
