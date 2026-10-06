import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../l10n/app_localizations.dart';
import '../../khadara/domain/khadara_models.dart';
import '../../khadara/presentation/khadara_providers.dart';
import '../../profil/presentation/profile_providers.dart';

/// Un mouqaddam au parrainage confirmé, vu par l'admin : seulement ce qu'il
/// faut pour lui attribuer une zawiya (fonction `admin_list_mouqaddams`).
class _ManagedMouqaddam {
  const _ManagedMouqaddam({required this.userId, required this.displayName, this.managedZawiyaId});

  final String userId;
  final String displayName;
  final String? managedZawiyaId;

  factory _ManagedMouqaddam.fromRow(Map<String, dynamic> row) {
    return _ManagedMouqaddam(
      userId: row['user_id'] as String,
      displayName: row['display_name'] as String,
      managedZawiyaId: row['managed_zawiya_id'] as String?,
    );
  }
}

/// Lié au compte connecté : la liste n'est lisible que par un admin, et ne
/// doit pas rester en cache pour le compte suivant.
final _managedMouqaddamsProvider = FutureProvider.autoDispose<List<_ManagedMouqaddam>>((ref) async {
  ref.watch(currentUserIdProvider);
  final rows = await SupabaseConfig.client.rpc('admin_list_mouqaddams');
  return (rows as List).map((row) => _ManagedMouqaddam.fromRow(row as Map<String, dynamic>)).toList();
});

/// Écran admin : attribuer à chaque mouqaddam confirmé la zawiya dont il peut
/// gérer les évènements et les directs.
///
/// Depuis l'audit du 2026-10-04 (S02a), ce droit ne vient plus de la zawiya
/// du profil (que chacun modifie librement) mais de
/// `mouqaddam_status.managed_zawiya_id`, écrit uniquement par la fonction
/// serveur `admin_set_mouqaddam_zawiya`. Sans attribution, un mouqaddam ne
/// peut créer aucun évènement : cet écran est donc le passage obligé après
/// chaque parrainage confirmé. Le garde-fou réel est côté serveur (les deux
/// fonctions vérifient `is_admin`) ; l'entrée n'est proposée qu'à l'admin.
class AdminMouqaddamZawiyasScreen extends ConsumerWidget {
  const AdminMouqaddamZawiyasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mouqaddams = ref.watch(_managedMouqaddamsProvider);
    final zawiyas = ref.watch(attachableZawiyasProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminMouqaddamZawiyasTitle)),
      body: mouqaddams.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.adminMouqaddamZawiyasLoadError,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.bronze),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(_managedMouqaddamsProvider),
                  child: Text(l10n.homeRetry),
                ),
              ],
            ),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.adminMouqaddamZawiyasEmpty,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.bronze),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.adminMouqaddamZawiyasIntro, style: TextStyle(color: AppColors.bronze)),
              const SizedBox(height: 16),
              for (final mouqaddam in list)
                _MouqaddamCard(
                  // `key` par compte : chaque carte garde son propre état
                  // d'enregistrement quand la liste est rechargée.
                  key: ValueKey(mouqaddam.userId),
                  mouqaddam: mouqaddam,
                  zawiyas: zawiyas.valueOrNull ?? const [],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MouqaddamCard extends ConsumerStatefulWidget {
  const _MouqaddamCard({super.key, required this.mouqaddam, required this.zawiyas});

  final _ManagedMouqaddam mouqaddam;
  final List<Zawiya> zawiyas;

  @override
  ConsumerState<_MouqaddamCard> createState() => _MouqaddamCardState();
}

class _MouqaddamCardState extends ConsumerState<_MouqaddamCard> {
  late String? _zawiyaId = widget.mouqaddam.managedZawiyaId;
  bool _saving = false;

  Future<void> _assign(String? zawiyaId) async {
    if (_saving || zawiyaId == _zawiyaId) return;
    final l10n = AppLocalizations.of(context)!;
    final previous = _zawiyaId;
    setState(() {
      _zawiyaId = zawiyaId;
      _saving = true;
    });
    try {
      await SupabaseConfig.client.rpc('admin_set_mouqaddam_zawiya', params: {
        'p_user_id': widget.mouqaddam.userId,
        'p_zawiya_id': zawiyaId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.adminMouqaddamZawiyasSaved)));
    } catch (_) {
      // Refus serveur ou réseau : on revient à la valeur réellement en base.
      if (!mounted) return;
      setState(() => _zawiyaId = previous);
      showErrorSnackBar(context, l10n.adminMouqaddamZawiyasSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Si la zawiya attribuée n'est plus dans la liste (lieu supprimé ou
    // liste encore en chargement), on n'impose pas de valeur absente au
    // sélecteur : il afficherait une erreur.
    final known = widget.zawiyas.any((z) => z.id == _zawiyaId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.mouqaddam.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              // `key` : `initialValue` n'est lu qu'à la création du champ.
              key: ValueKey('${widget.mouqaddam.userId}-$_zawiyaId-${widget.zawiyas.length}'),
              isExpanded: true,
              initialValue: known ? _zawiyaId : null,
              decoration: InputDecoration(labelText: l10n.adminMouqaddamZawiyasFieldLabel),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(l10n.adminMouqaddamZawiyasNone)),
                ...widget.zawiyas.map(
                  (z) => DropdownMenuItem<String?>(
                    value: z.id,
                    child: Text(z.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: _saving ? null : _assign,
            ),
          ],
        ),
      ),
    );
  }
}
