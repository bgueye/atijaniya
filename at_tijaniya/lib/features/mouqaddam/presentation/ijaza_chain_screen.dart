import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../profil/presentation/profile_providers.dart';
import '../domain/mouqaddam_models.dart';
import 'mouqaddam_providers.dart';

/// Ma silsila d'ijaza — chaîne de transmission reconstruite automatiquement
/// via le graphe de parrainage (`get_ijaza_chain`), complétée en texte
/// libre au-delà de l'app. Priorité P2 (docs/03-architecture-ecrans.md).
///
/// Distincte de la silsila HISTORIQUE de la tarikha (module Figures,
/// `historical_silsila_links`/`get_historical_silsila_chain`) : ici, un
/// graphe personnel de parrainage entre disciples vivants, jamais partagé
/// avec celui-là — voir le commentaire de `HistoricalSilsilaLink` dans
/// `figure_models.dart`. Widgets volontairement séparés de `_SilsilaTab`
/// (`figure_detail_screen.dart`) plutôt que factorisés : deux concepts
/// distincts qui n'ont pas vocation à évoluer ensemble.
class IjazaChainScreen extends ConsumerWidget {
  const IjazaChainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final chainAsync = ref.watch(myIjazaChainProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mouqaddamChainTitle)),
      body: chainAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
                const SizedBox(height: 12),
                Text(l10n.mouqaddamChainLoadError, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.bronze)),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () => ref.invalidate(myIjazaChainProvider), child: Text(l10n.mouqaddamRetry)),
              ],
            ),
          ),
        ),
        data: (chain) {
          final currentUserId = ref.watch(currentUserIdProvider);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (chain.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(l10n.mouqaddamChainEmpty, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.bronze)),
                  ),
                )
              else
                for (var i = 0; i < chain.length; i++) ...[
                  _ChainNode(link: chain[i], isSelf: chain[i].userId == currentUserId, l10n: l10n),
                  if (i != chain.length - 1) const _ChainConnector(),
                ],
              const SizedBox(height: 32),
              _CompleteChainSection(l10n: l10n),
            ],
          );
        },
      ),
    );
  }
}

class _ChainConnector extends StatelessWidget {
  const _ChainConnector();

  @override
  Widget build(BuildContext context) {
    return const Center(child: SizedBox(width: 1.5, height: 16, child: ColoredBox(color: AppColors.gold)));
  }
}

class _ChainNode extends StatelessWidget {
  const _ChainNode({required this.link, required this.isSelf, required this.l10n});

  final IjazaChainLink link;
  final bool isSelf;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(12),
        border: isSelf ? Border.all(color: AppColors.gold, width: 2) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            link.displayName('—'),
            textAlign: TextAlign.center,
            style: AppTheme.sacredText(fontSize: 16, color: AppColors.zaytoune),
          ),
          if (link.isManual ? link.yearText != null : link.ijazaYear != null) ...[
            const SizedBox(height: 4),
            Text(
              link.isManual ? link.yearText! : '${link.ijazaYear}',
              style: const TextStyle(fontSize: 12, color: AppColors.bronze),
            ),
          ],
          if (isSelf) ...[
            const SizedBox(height: 4),
            Text(l10n.mouqaddamChainYouLabel, style: const TextStyle(fontSize: 10, color: AppColors.gold, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

class _CompleteChainSection extends ConsumerStatefulWidget {
  const _CompleteChainSection({required this.l10n});

  final AppLocalizations l10n;

  @override
  ConsumerState<_CompleteChainSection> createState() => _CompleteChainSectionState();
}

class _CompleteChainSectionState extends ConsumerState<_CompleteChainSection> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _yearTextController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _yearTextController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final l10n = widget.l10n;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final yearText = _yearTextController.text.trim();
      await ref.read(mouqaddamRepositoryProvider).addManualChainLink(
            nameText: _nameController.text.trim(),
            yearText: yearText.isEmpty ? null : yearText,
          );
      ref.invalidate(myIjazaChainProvider);
      _nameController.clear();
      _yearTextController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.mouqaddamChainAddSuccess)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.mouqaddamChainAddError)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.mouqaddamChainCompleteTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 8),
              Text(l10n.mouqaddamChainCompleteBody, style: const TextStyle(color: AppColors.bronze, fontSize: 13)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: l10n.mouqaddamChainNameFieldLabel),
                validator: (value) => (value == null || value.trim().isEmpty) ? l10n.mouqaddamChainNameRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _yearTextController,
                decoration: InputDecoration(labelText: l10n.mouqaddamChainYearTextFieldLabel),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _saving ? null : _add,
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.mouqaddamChainAddButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
