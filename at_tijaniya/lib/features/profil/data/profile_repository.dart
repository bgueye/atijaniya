/// Accès aux données du profil disciple (Supabase — table `profiles`).
/// Lecture publique côté RLS (`profiles_read_all` : `using (true)`), mais
/// "Mon profil" ne concerne que le compte connecté : chaque méthode lit
/// `auth.currentUser` et n'est appelée qu'avec une session (l'écran Profil
/// affiche « connectez-vous » sinon). Côté base, le client ne modifie que
/// `display_name`, `avatar_url`, `locale`, `zawiya_id` et `bio` (privilèges
/// de colonne, voir CLAUDE.md).
library;

import '../../../core/supabase/supabase_config.dart';
import '../domain/profile_models.dart';

class ProfileRepository {
  const ProfileRepository();

  /// Colonnes listées et droit d'administration lu par `am_i_admin()`
  /// (audit Communauté du 2026-10-26, P2-2) : `profiles.is_admin` sera retiré
  /// de la lecture, pour que personne ne puisse repérer le compte
  /// administrateur ; un `select('*')` serait alors refusé.
  Future<Profile> fetchMyProfile() async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    final row = await SupabaseConfig.client
        .from('profiles')
        .select('user_id, display_name, avatar_url, locale, zawiya_id, bio, zawiyas(name)')
        .eq('user_id', userId)
        .single();
    final isAdmin = await SupabaseConfig.client.rpc('am_i_admin') as bool? ?? false;
    return Profile.fromRow({...row, 'is_admin': isAdmin});
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

  /// Langue de l'app du compte connecté (`profiles.locale`, `fr` ou `ar`) —
  /// écrite par `app.dart` au changement de langue et à la connexion
  /// (audit de l'accueil du 2026-10-26, P2-1).
  Future<void> updateMyLocale(String locale) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    await SupabaseConfig.client.from('profiles').update({'locale': locale}).eq('user_id', userId);
  }

  /// Photo de profil — appel séparé de [updateMyProfile] (même principe que
  /// `FiguresRepository.updatePortrait`) : l'image est téléversée puis son
  /// URL enregistrée seule, sans dépendre du reste du formulaire nom/bio/
  /// zawiya. Bucket `avatars` (database/schema.sql § 11.2quater), chemin
  /// `avatars/{auth.uid()}/...` déjà scopé par RLS côté Storage.
  ///
  /// `null` retire la photo du profil (avant la suppression du compte, P3-6).
  Future<void> updateMyAvatar(String? avatarUrl) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    await SupabaseConfig.client
        .from('profiles')
        .update({'avatar_url': avatarUrl}).eq('user_id', userId);
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
  ///
  /// Depuis l'audit du 2026-10-04 (S51, S52), la suppression passe par la
  /// fonction SQL `delete_my_account()` : une seule transaction, donc soit
  /// tout est supprimé, soit rien ne l'est. L'ancienne Edge Function
  /// enchaînait ses écritures sans lire leurs erreurs et pouvait effacer les
  /// messages d'un compte qu'elle n'arrivait pas ensuite à supprimer.
  Future<void> deleteMyAccount() async {
    await SupabaseConfig.client.rpc('delete_my_account');
  }
}
