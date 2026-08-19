import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profil/presentation/profile_providers.dart';
import '../data/notifications_repository.dart';
import '../domain/app_notification.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) => const NotificationsRepository());

/// Flux temps réel des notifications de l'utilisateur courant — liste vide
/// tant qu'aucune session n'est ouverte (mode invité), même garde que le
/// reste de l'app plutôt qu'un appel Supabase voué à échouer.
final myNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(notificationsRepositoryProvider).watchMyNotifications(userId);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(myNotificationsProvider).maybeWhen(
        data: (list) => list.where((n) => n.isUnread).length,
        orElse: () => 0,
      );
});
