import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/live_stream_repository.dart';
import '../domain/khadara_models.dart';

final liveStreamRepositoryProvider = Provider<LiveStreamRepository>((ref) => const LiveStreamRepository());

final latestStreamForEventProvider = FutureProvider.family<LiveStream?, String>((ref, eventId) {
  return ref.watch(liveStreamRepositoryProvider).fetchLatestStreamForEvent(eventId);
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
