/// Accès aux récitations audio des piliers (Supabase — `wird_recitations`,
/// docs/decision-gestion-audio-wirds.md).
///
/// Le corpus texte des wirds reste local (`wirds_content.dart`, source
/// unique — voir CLAUDE.md) : `WirdPillar` ne porte donc aucun identifiant
/// Supabase. La résolution vers `wird_recitations` se fait par position —
/// la place d'un pilier dans `Wird.pillars` (index + 1) correspond
/// exactement à `wird_steps.order_index` (vérifié sur les trois wirds au
/// moment de la préparation du plan, docs/decision-gestion-audio-wirds.md
/// §10) — jamais en faisant porter un UUID par le corpus local.
library;

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import '../domain/wird_recitation.dart';

/// Extensions audio acceptées par `WirdAudioPickerService` et par l'upload
/// admin — même style que `allowedImageExtensions` dans
/// `lib/core/storage/image_upload_service.dart`.
const Set<String> allowedWirdAudioExtensions = {'aac', 'm4a', 'mp3'};

/// Résout l'extension à partir d'un chemin local choisi par l'admin — `null`
/// si absente ou non reconnue (défensif : le file picker restreint déjà les
/// extensions proposées, cette fonction ne devrait donc jamais échouer en
/// pratique).
String? wirdAudioExtensionFromPath(String path) {
  final dotIndex = path.lastIndexOf('.');
  if (dotIndex == -1 || dotIndex == path.length - 1) return null;
  final extension = path.substring(dotIndex + 1).toLowerCase();
  return allowedWirdAudioExtensions.contains(extension) ? extension : null;
}

/// Content-Type MIME à déclarer au téléversement pour une [extension] déjà
/// résolue par [wirdAudioExtensionFromPath].
String wirdAudioContentTypeForExtension(String extension) {
  switch (extension) {
    case 'mp3':
      return 'audio/mpeg';
    case 'm4a':
      return 'audio/mp4';
    default:
      return 'audio/aac';
  }
}

/// Chemin Storage pour une nouvelle récitation — `{wirdKey}/{orderIndex}.{ext}`
/// pour la version 1, `{wirdKey}/{orderIndex}_v{contentVersion}.{ext}` au-delà
/// (jamais d'écrasement du fichier en place, docs/decision-gestion-audio-wirds.md
/// §2/§7) — convention déjà en usage dans `assets/audio/manifest.json`
/// (ex. `wazifa/6_v2.aac`). Ne produit jamais un chemin `shared/...` : la
/// réutilisation d'un même fichier entre plusieurs piliers reste une
/// curation manuelle, hors scope de l'upload admin.
String buildWirdAudioPath({
  required String wirdKey,
  required int orderIndex,
  required int contentVersion,
  required String extension,
}) {
  final suffix = contentVersion <= 1 ? '' : '_v$contentVersion';
  return '$wirdKey/$orderIndex$suffix.$extension';
}

/// Prochain `content_version` pour un pilier — 1 si aucune récitation
/// existante, sinon `max(contentVersion) + 1`.
int nextContentVersionFor(List<WirdRecitationEntry> existing) {
  if (existing.isEmpty) return 1;
  return existing.map((r) => r.contentVersion).reduce((a, b) => a > b ? a : b) +
      1;
}

class WirdRecitationRepository {
  const WirdRecitationRepository();

  /// Récitation par défaut validée de chaque pilier de [wirdKey]
  /// (`Wird.id`), indexée par position dans `Wird.pillars`. Un pilier sans
  /// récitation validée est absent du résultat.
  Future<Map<int, WirdRecitation>> fetchRecitationsForWird(
      String wirdKey) async {
    final steps = await SupabaseConfig.client
        .from('wird_steps')
        .select('id, order_index, wirds!inner(key)')
        .eq('wirds.key', wirdKey)
        .order('order_index');
    final stepRows = (steps as List).cast<Map<String, dynamic>>();
    final stepIds = [for (final s in stepRows) s['id'] as String];
    if (stepIds.isEmpty) return const {};

    // content_status = 'valide' explicite en plus de la RLS
    // (wird_recitations_read_valid_or_admin) : défense en profondeur, même
    // principe que FiguresRepository — un compte admin ne doit jamais voir
    // de brouillon dans l'écran normal du disciple.
    final recitations = await SupabaseConfig.client
        .from('wird_recitations')
        .select(
            'id, wird_step_id, audio_path, content_version, duration_seconds')
        .inFilter('wird_step_id', stepIds)
        .eq('is_default', true)
        .eq('content_status', 'valide');

    return buildRecitationsByPillarIndex(
      steps: stepRows,
      recitations: (recitations as List).cast<Map<String, dynamic>>(),
    );
  }

  /// Télécharge le fichier audio (bucket privé `wird-audio`) — passe par le
  /// client Supabase authentifié plutôt que par une URL signée
  /// intermédiaire : même résultat (accès respectant la RLS storage), sans
  /// gérer nous-mêmes l'expiration/régénération d'une URL.
  Future<List<int>> downloadAudioBytes(String audioPath) {
    return SupabaseConfig.client.storage.from('wird-audio').download(audioPath);
  }

  /// Récitations en `brouillon`, pour l'écran de review admin
  /// (`WirdRecitationsReviewScreen`). La RLS `wird_recitations_read_valid_or_admin`
  /// ne renvoie ces lignes qu'à un compte `is_admin` — un compte non-admin
  /// qui appellerait cette méthode par erreur obtient une liste vide, jamais
  /// les brouillons eux-mêmes. Embarque le wird et le pilier concernés
  /// (`wird_steps`/`wirds`) en un aller-retour, nécessaires pour identifier
  /// la récitation à l'écran.
  Future<List<WirdRecitationDraft>> fetchDraftRecitations() async {
    final rows = await SupabaseConfig.client
        .from('wird_recitations')
        .select(
          'id, reciter_name, audio_path, content_version, duration_seconds, '
          'wird_steps!inner(order_index, transliteration, arabic_text, wirds!inner(name_fr))',
        )
        .eq('content_status', 'brouillon')
        .order('created_at');
    return (rows as List)
        .map((row) => WirdRecitationDraft.fromRow(row as Map<String, dynamic>))
        .toList();
  }

  /// Fait passer une récitation de "brouillon" à "valide" — délègue à la
  /// RPC serveur `validate_wird_recitation` (migration
  /// `add_wird_recitations_delete_policies_and_validate_rpc`) plutôt qu'à
  /// un simple UPDATE : elle démote dans la même transaction l'ancienne
  /// récitation `valide`+`is_default=true` du même pilier, s'il y en a une
  /// — sans ça, `fetchRecitationsForWird` pourrait voir deux lignes
  /// concurrentes pour un même pilier. `security invoker` côté fonction :
  /// reste soumise à `wird_recitations_admin_update`, donc no-op pour tout
  /// compte non-admin même si appelée par erreur.
  Future<void> validateRecitation(String recitationId) {
    return SupabaseConfig.client.rpc('validate_wird_recitation',
        params: {'p_recitation_id': recitationId});
  }

  /// Toutes les récitations (tout statut) des piliers de [wirdKey], pour
  /// l'écran de gestion admin (`WirdRecitationsManagementScreen`). La RLS
  /// `wird_recitations_read_valid_or_admin` laisse un compte admin tout
  /// voir ; un compte non-admin qui appellerait cette méthode par erreur ne
  /// verrait que les lignes déjà `valide` (jamais les brouillons).
  Future<List<WirdStepRecitations>> fetchAllRecitationsForWird(
      String wirdKey) async {
    final steps = await SupabaseConfig.client
        .from('wird_steps')
        .select('id, order_index, wirds!inner(key)')
        .eq('wirds.key', wirdKey)
        .order('order_index');
    final stepRows = (steps as List).cast<Map<String, dynamic>>();
    final stepIds = [for (final s in stepRows) s['id'] as String];
    if (stepIds.isEmpty) return const [];

    final recitations = await SupabaseConfig.client
        .from('wird_recitations')
        .select(
            'id, wird_step_id, reciter_name, audio_path, content_version, content_status, is_default, duration_seconds')
        .inFilter('wird_step_id', stepIds)
        .order('content_version');

    return buildStepRecitations(
      steps: stepRows,
      recitations: (recitations as List).cast<Map<String, dynamic>>(),
    );
  }

  /// Téléverse [bytes] vers le bucket privé `wird-audio` (chemin résolu par
  /// [buildWirdAudioPath], `upsert: false` — jamais d'écrasement d'un
  /// fichier en place), puis insère la ligne `wird_recitations`
  /// correspondante (`content_status` reste `'brouillon'` par défaut,
  /// jamais publié directement — même geste éditorial que
  /// `FiguresRepository.createFigure`). Upload d'abord, insert ensuite : si
  /// l'upload échoue, aucune ligne orpheline en base ; si l'insert échoue
  /// après un upload réussi, le fichier orphelin reste invisible côté
  /// disciple (la RLS de lecture exige une ligne `wird_recitations`
  /// correspondante, sauf pour un admin).
  Future<WirdRecitationEntry> uploadRecitation({
    required String wirdStepId,
    required String wirdKey,
    required int orderIndex,
    required int contentVersion,
    required String reciterName,
    required Uint8List bytes,
    required String extension,
  }) async {
    final audioPath = buildWirdAudioPath(
      wirdKey: wirdKey,
      orderIndex: orderIndex,
      contentVersion: contentVersion,
      extension: extension,
    );
    await SupabaseConfig.client.storage.from('wird-audio').uploadBinary(
          audioPath,
          bytes,
          fileOptions: FileOptions(
              contentType: wirdAudioContentTypeForExtension(extension),
              upsert: false),
        );
    final row = await SupabaseConfig.client
        .from('wird_recitations')
        .insert({
          'wird_step_id': wirdStepId,
          'reciter_name': reciterName,
          'audio_path': audioPath,
          'content_version': contentVersion,
          'is_default': false,
        })
        .select(
            'id, wird_step_id, reciter_name, audio_path, content_version, content_status, is_default, duration_seconds')
        .single();
    return WirdRecitationEntry.fromRow(row);
  }

  /// Supprime une récitation, brouillon ou déjà validée — l'admin a
  /// autorité pleine sur ce contenu (même principe que
  /// `FiguresRepository.deleteFigure`/`deleteCitation`). Ligne DB
  /// supprimée d'abord, puis suppression Storage best-effort : le pire
  /// résultat d'un échec de l'étape Storage est un objet orphelin dans le
  /// bucket privé (jamais lu — la policy de lecture exige une ligne
  /// `wird_recitations` correspondante, sauf admin), sans impact disciple.
  /// L'ordre inverse ferait courir le risque qu'un échec du DELETE en base
  /// laisse une ligne (potentiellement valide+défaut) pointer vers un
  /// fichier déjà supprimé.
  Future<void> deleteRecitation(
      {required String recitationId, required String audioPath}) async {
    await SupabaseConfig.client
        .from('wird_recitations')
        .delete()
        .eq('id', recitationId);
    try {
      await SupabaseConfig.client.storage
          .from('wird-audio')
          .remove([audioPath]);
    } catch (_) {
      // Best-effort — voir commentaire ci-dessus.
    }
  }
}

/// Regroupe et trie par pilier les récitations d'un wird — logique pure
/// (sans réseau, testée dans `test/wird_recitation_repository_test.dart`),
/// pour l'écran de gestion admin.
List<WirdStepRecitations> buildStepRecitations({
  required List<Map<String, dynamic>> steps,
  required List<Map<String, dynamic>> recitations,
}) {
  final recitationsByStepId = <String, List<WirdRecitationEntry>>{};
  for (final row in recitations) {
    final entry = WirdRecitationEntry.fromRow(row);
    recitationsByStepId.putIfAbsent(entry.wirdStepId, () => []).add(entry);
  }
  final sortedSteps = [...steps]..sort(
      (a, b) => (a['order_index'] as int).compareTo(b['order_index'] as int));
  return [
    for (final step in sortedSteps)
      WirdStepRecitations(
        wirdStepId: step['id'] as String,
        orderIndex: step['order_index'] as int,
        recitations: recitationsByStepId[step['id'] as String] ?? const [],
      ),
  ];
}

/// Logique pure (sans réseau, testée dans `test/wird_recitation_repository_test.dart`) :
/// associe à chaque pilier (par position) sa récitation par défaut, si elle
/// existe.
Map<int, WirdRecitation> buildRecitationsByPillarIndex({
  required List<Map<String, dynamic>> steps,
  required List<Map<String, dynamic>> recitations,
}) {
  final recitationByStepId = {
    for (final r in recitations)
      r['wird_step_id'] as String: WirdRecitation.fromRow(r),
  };
  final result = <int, WirdRecitation>{};
  for (final step in steps) {
    final recitation = recitationByStepId[step['id'] as String];
    if (recitation == null) continue;
    final orderIndex = step['order_index'] as int;
    result[orderIndex - 1] = recitation;
  }
  return result;
}
