/// Accès aux données du profil disciple (Supabase — table `profiles`).
/// Lecture publique côté RLS (`profiles_read_all` : `using (true)`), mais
/// "Mon profil" ne concerne que l'utilisateur courant : la lecture comme
/// l'écriture ont besoin d'un `auth.uid()` réel (policies `profiles_owner_*`),
/// indisponible tant que l'authentification n'est pas branchée côté app
/// (TODO dans `auth_screen.dart` — même limitation documentée que
/// `CommunityRepository`). Les méthodes ci-dessous sont prêtes et
/// s'activeront automatiquement dès qu'une session réelle existera.
library;

import '../../../core/supabase/supabase_config.dart';
import '../domain/profile_models.dart';

class ProfileRepository {
  const ProfileRepository();

  Future<Profile> fetchMyProfile() async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    final row = await SupabaseConfig.client
        .from('profiles')
        .select('*, zawiyas(name)')
        .eq('user_id', userId)
        .single();
    return Profile.fromRow(row);
  }

  /// `zawiyaId` à `null` efface le rattachement à une zawiya.
  Future<void> updateMyProfile({
    required String displayName,
    String? bio,
    String? zawiyaId,
  }) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    await SupabaseConfig.client.from('profiles').update({
      'display_name': displayName,
      'bio': bio,
      'zawiya_id': zawiyaId,
    }).eq('user_id', userId);
  }

  /// Suppression définitive du compte connecté — via l'Edge Function
  /// `delete-account` (`supabase/functions/delete-account/index.ts`),
  /// nécessaire car `auth.admin.deleteUser` exige la clé service_role,
  /// jamais atteignable depuis le client. Voir le commentaire de la
  /// fonction pour le détail de ce qui est supprimé (contenu personnel :
  /// commentaires, messages, publications de groupe) vs conservé mais
  /// anonymisé (évènements créés, rediffusions validées, publications du
  /// fil). Peut échouer (compte admin avec des entrées non couvertes dans
  /// `admin_actions_log`/`sensitive_data_access_log`) — non catché ici,
  /// message générique affiché côté écran.
  Future<void> deleteMyAccount() async {
    await SupabaseConfig.client.functions.invoke('delete-account');
  }
}
