import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/mouqaddam_models.dart';
import 'mouqaddam_providers.dart';

/// Rechercher un parrain — pour l'écran "Devenir Mouqaddam". Priorité P2
/// (docs/03-architecture-ecrans.md).
///
/// Ne renvoie que les mouqaddamines vérifiés ayant explicitement activé
/// "disponible comme parrain" (`search_available_sponsors`, fonction
/// `SECURITY DEFINER` — voir `mouqaddam_repository.dart`) : jamais un
/// annuaire général de tous les mouqaddamines.
class SearchSponsorScreen extends ConsumerStatefulWidget {
  const SearchSponsorScreen({super.key});

  @override
  ConsumerState<SearchSponsorScreen> createState() => _SearchSponsorScreenState();
}

class _SearchSponsorScreenState extends ConsumerState<SearchSponsorScreen> {
  final _queryController = TextEditingController();
  List<AvailableSponsor>? _results;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final results = await ref.read(mouqaddamRepositoryProvider).searchAvailableSponsors(_queryController.text);
      if (mounted) setState(() => _results = results);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mouqaddamSearchTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _queryController,
              decoration: InputDecoration(
                hintText: l10n.mouqaddamSearchFieldHint,
                prefixIcon: const Icon(Icons.search),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
            ),
          ),
          Expanded(child: _buildBody(l10n)),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.emerald));
    }
    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
              const SizedBox(height: 12),
              Text(l10n.mouqaddamSearchLoadError, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.bronze)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _search, child: Text(l10n.mouqaddamRetry)),
            ],
          ),
        ),
      );
    }

    final results = _results ?? [];
    if (results.isEmpty) {
      final message = _queryController.text.trim().isEmpty ? l10n.mouqaddamSearchEmpty : l10n.mouqaddamSearchNoResults;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.bronze)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final sponsor = results[i];
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: AppColors.emeraldSoft,
            child: Icon(Icons.person_outline, color: AppColors.emerald),
          ),
          title: Text(sponsor.displayName),
          subtitle: Text(sponsor.zawiyaName ?? l10n.profileZawiyaNoneLabel),
          onTap: () => Navigator.of(context).pop(sponsor),
        );
      },
    );
  }
}
