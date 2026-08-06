/// Accès aux données de confidentialité (Supabase — table
/// `privacy_settings`). Policy RLS `privacy_settings_owner_only` : `for
/// all using (auth.uid() = user_id)` — chaque disciple ne voit et ne
/// modifie jamais que sa propre ligne. Une seule ligne par utilisateur
/// (clé primaire `user_id`, auto-créée à l'inscription par le trigger
/// `handle_new_user`), d'où l'usage d'`upsert` plutôt que insert/update
/// séparés.
library;

import '../../../core/supabase/supabase_config.dart';
import '../domain/privacy_settings_models.dart';

class PrivacySettingsRepository {
  const PrivacySettingsRepository();

  Future<PrivacySettings> fetchMyPrivacySettings() async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    final row = await SupabaseConfig.client
        .from('privacy_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return PrivacySettings.fromRow(row);
  }

  Future<void> updateMyPrivacySettings(PrivacySettings settings) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    await SupabaseConfig.client.from('privacy_settings').upsert({
      'user_id': userId,
      'lineage_visible': settings.lineageVisible,
      'mouqaddam_status_visible': settings.mouqaddamStatusVisible,
      'available_as_sponsor': settings.availableAsSponsor,
      'who_can_contact': whoCanContactToDbValue(settings.whoCanContact),
    });
  }
}
