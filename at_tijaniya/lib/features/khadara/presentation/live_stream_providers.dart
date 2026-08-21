import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/live_stream_repository.dart';
import '../domain/khadara_models.dart';

final liveStreamRepositoryProvider = Provider<LiveStreamRepository>((ref) => const LiveStreamRepository());

// `.autoDispose` sur les 3 providers ci-dessous (Sprint 4, audit perf) :
// paramétrés par un `eventId`/`groupId` consulté depuis un écran de détail
// poussé/dépilé (EventDetailScreen/GroupDetailScreen) — sans ça, chaque
// évènement/groupe visité au fil d'une session laisse une entrée en cache
// jamais libérée, pour une donnée qui n'a aucune raison de survivre à la
// fermeture de l'écran.
final latestStreamForEventProvider = FutureProvider.autoDispose.family<LiveStream?, String>((ref, eventId) {
  return ref.watch(liveStreamRepositoryProvider).fetchLatestStreamForEvent(eventId);
});

/// Symétrique côté groupe — voir `LiveStreamRepository.fetchLatestStreamForGroup`.
final latestStreamForGroupProvider = FutureProvider.autoDispose.family<LiveStream?, String>((ref, groupId) {
  return ref.watch(liveStreamRepositoryProvider).fetchLatestStreamForGroup(groupId);
});

/// Voir `LiveStreamRepository.fetchPastStreamsForGroup`.
final pastStreamsForGroupProvider = FutureProvider.autoDispose.family<List<LiveStream>, String>((ref, groupId) {
  return ref.watch(liveStreamRepositoryProvider).fetchPastStreamsForGroup(groupId);
});

final allLiveStreamsProvider = FutureProvider<List<LiveStream>>((ref) {
  return ref.watch(liveStreamRepositoryProvider).fetchAllLiveStreams();
});

final streamReplaysProvider = FutureProvider<List<StreamReplay>>((ref) {
  return ref.watch(liveStreamRepositoryProvider).fetchReplays();
});

/// Pas de `.autoDispose`/Realtime ici : `LiveStreamScreen` rafraîchit ce
/// provider lui-même via un polling léger tant que l'écran est ouvert (voir
/// commentaire de `LiveChatMessage`).
final chatMessagesProvider = FutureProvider.family<List<LiveChatMessage>, String>((ref, streamId) {
  return ref.watch(liveStreamRepositoryProvider).fetchChatMessages(streamId);
});
