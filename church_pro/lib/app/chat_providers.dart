import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/chat/data/chat_repository.dart';
import '../features/chat/domain/chat_models.dart';
import 'providers.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepository());

/// The channels the signed-in person belongs to, most recent first.
final channelsProvider = StreamProvider<List<Channel>>((ref) {
  final churchId = ref.watch(activeChurchIdProvider);
  final user = ref.watch(authStateProvider).value;
  if (churchId == null || user == null) return Stream.value(const <Channel>[]);
  return ref.watch(chatRepositoryProvider).watchChannels(churchId, user.uid);
});

final channelMessagesProvider = StreamProvider.family<List<ChatMessage>, String>((ref, channelId) {
  final churchId = ref.watch(activeChurchIdProvider);
  if (churchId == null) return Stream.value(const <ChatMessage>[]);
  return ref.watch(chatRepositoryProvider).watchMessages(churchId, channelId);
});