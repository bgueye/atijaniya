import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/mouqaddam_models.dart';
import 'mouqaddam_providers.dart';
import 'search_sponsor_screen.dart';

/// Devenir Mouqaddam — déclaration du statut par parrainage, jamais
/// auto-proclamée (docs/01-perimetre-fonctionnel.md § 5.4.2, CLAUDE.md).
/// Priorité P2 (docs/03-architecture-ecrans.md).
///
/// Accessible depuis `ProfilScreen` uniquement quand `isVerifiedMouqaddamProvider`
/// vaut `false` — un disciple déjà vérifié n'a plus besoin de cet écran, il
/// voit à la place "Demandes de parrainage"/"Ma silsila d'ijaza".
class BecomeMouqaddamScreen extends ConsumerWidget {
  const BecomeMouqaddamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final requestAsync = ref.watch(myLatestSponsorshipRequestProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mouqaddamBecomeTitle)),
      // `SafeArea` : évite que le bouton Enregistrer/Annuler se retrouve
      // masqué sous la barre de navigation Android (3 boutons).
      body: SafeArea(
        child: requestAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.emerald)),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
                  const SizedBox(height: 12),
                  Text(l10n.mouqaddamLoadError,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.bronze)),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        ref.invalidate(myLatestSponsorshipRequestProvider),
                    child: Text(l10n.mouqaddamRetry),
                  ),
                ],
              ),
            ),
          ),
          data: (request) {
            if (request != null &&
                request.status == SponsorshipRequestStatus.pending) {
              return _PendingRequestView(request: request, l10n: l10n);
            }
            return _RequestForm(previousRequest: request, l10n: l10n);
          },
        ),
      ),
    );
  }
}

class _PendingRequestView extends ConsumerWidget {
  const _PendingRequestView({required this.request, required this.l10n});

  final SponsorshipRequest request;
  final AppLocalizations l10n;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.mouqaddamPendingCancelConfirmTitle),
        content: Text(l10n.mouqaddamPendingCancelConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.profileCancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.mouqaddamPendingCancelConfirmAction,
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(mouqaddamRepositoryProvider)
          .cancelMyPendingRequest(request.id);
      ref.invalidate(myLatestSponsorshipRequestProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.mouqaddamCancelError)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.hourglass_top_outlined,
                          color: AppColors.gold),
                      const SizedBox(width: 12),
                      Text(l10n.mouqaddamPendingTitle,
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.mouqaddamPendingSponsorLabel,
                      style: const TextStyle(
                          color: AppColors.bronze, fontSize: 13)),
                  Text(request.sponsorName ?? '—',
                      style: const TextStyle(fontSize: 16)),
                  if (request.ijazaYear != null) ...[
                    const SizedBox(height: 12),
                    Text(l10n.mouqaddamYearFieldLabel,
                        style: const TextStyle(
                            color: AppColors.bronze, fontSize: 13)),
                    Text('${request.ijazaYear}',
                        style: const TextStyle(fontSize: 16)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => _cancel(context, ref),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(l10n.mouqaddamPendingCancelButton),
          ),
        ],
      ),
    );
  }
}

class _RequestForm extends ConsumerStatefulWidget {
  const _RequestForm({required this.previousRequest, required this.l10n});

  final SponsorshipRequest? previousRequest;
  final AppLocalizations l10n;

  @override
  ConsumerState<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends ConsumerState<_RequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _yearController = TextEditingController();
  AvailableSponsor? _selectedSponsor;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _chooseSponsor() async {
    final selected = await Navigator.of(context).push<AvailableSponsor>(
      MaterialPageRoute(builder: (_) => const SearchSponsorScreen()),
    );
    if (selected != null && mounted) {
      setState(() => _selectedSponsor = selected);
    }
  }

  Future<void> _submit() async {
    final l10n = widget.l10n;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSponsor == null) {
      setState(() => _errorMessage = l10n.mouqaddamSponsorRequiredError);
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final yearText = _yearController.text.trim();
      await ref.read(mouqaddamRepositoryProvider).requestSponsorship(
            sponsorUserId: _selectedSponsor!.userId,
            ijazaYear: yearText.isEmpty ? null : int.parse(yearText),
          );
      ref.invalidate(myLatestSponsorshipRequestProvider);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = l10n.mouqaddamSubmitError);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: AppColors.goldSoft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.bronze),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(l10n.mouqaddamIntro,
                            style: const TextStyle(
                                color: AppColors.ink, fontSize: 15))),
                  ],
                ),
              ),
            ),
            if (widget.previousRequest?.status ==
                SponsorshipRequestStatus.rejected) ...[
              const SizedBox(height: 16),
              Text(l10n.mouqaddamRejectedNote,
                  style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 24),
            Text(l10n.mouqaddamSelectedSponsorLabel,
                style: const TextStyle(color: AppColors.bronze, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              _selectedSponsor?.displayName ?? l10n.mouqaddamNoSponsorChosen,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _chooseSponsor,
              icon: const Icon(Icons.search, size: 18),
              label: Text(_selectedSponsor == null
                  ? l10n.mouqaddamChooseSponsorButton
                  : l10n.mouqaddamChangeSponsorButton),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _yearController,
              decoration:
                  InputDecoration(labelText: l10n.mouqaddamYearFieldLabel),
              keyboardType: TextInputType.number,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return null;
                final year = int.tryParse(text);
                if (year == null || year < 1200 || year > 2100) {
                  return l10n.mouqaddamYearInvalid;
                }
                return null;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(_errorMessage!,
                  style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.mouqaddamSubmitButton),
            ),
          ],
        ),
      ),
    );
  }
}
