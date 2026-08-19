/// Accès aux données de `public.notifications` — RLS `notifications_owner_only`
/// (`for all`, propriétaire uniquement) : chaque utilisateur ne voit et ne
/// modifie que ses propres notifications, le fan-out (une ligne par
/// destinataire) est fait côté base par les triggers, jamais depuis ce
/// fichier. Seul point du projet à utiliser Supabase Realtime — le chat en
/// direct (`live_stream_repository.dart`) l'a délibérément écarté au profit
/// d'un polling léger, mais `docs/06-architecture-backend.md` anticipait
/// justement Realtime pour les notifications.
library;

import '../../../core/supabase/supabase_config.dart';
import '../domain/app_notification.dart';

class NotificationsRepository {
  const NotificationsRepository();

  Stream<List<AppNotification>> watchMyNotifications(String userId) {
    return SupabaseConfig.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(AppNotification.fromRow).toList());
  }

  Future<void> markAsRead(String notificationId) async {
    await SupabaseConfig.client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', notificationId);
  }
}
