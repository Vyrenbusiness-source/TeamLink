// ignore_for_file: public_member_api_docs

import 'package:desktop_client/models/message.dart';
import 'package:desktop_client/services/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.name,
    required this.email,
    required this.lastContent,
    required this.lastAt,
    required this.lastSenderId,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) =>
      ConversationSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        lastContent: json['last_content'] as String? ?? '',
        lastAt: json['last_at'] as int? ?? 0,
        lastSenderId: json['last_sender_id'] as String? ?? '',
      );

  final String id;
  final String name;
  final String email;
  final String lastContent;
  final int lastAt;
  final String lastSenderId;
}

class DmUser {
  const DmUser({
    required this.id,
    required this.name,
    required this.email,
  });

  factory DmUser.fromJson(Map<String, dynamic> json) => DmUser(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
      );

  final String id;
  final String name;
  final String email;
}

final conversationsProvider =
    FutureProvider<List<ConversationSummary>>((ref) async {
  final data = await ref.read(apiClientProvider).getConversations();
  return data
      .cast<Map<String, dynamic>>()
      .map(ConversationSummary.fromJson)
      .toList();
});

final dmUsersProvider = FutureProvider<List<DmUser>>((ref) async {
  final data = await ref.read(apiClientProvider).getDmUsers();
  return data.cast<Map<String, dynamic>>().map(DmUser.fromJson).toList();
});

class MessagesNotifier extends FamilyAsyncNotifier<List<Message>, String> {
  @override
  Future<List<Message>> build(String arg) async {
    final data = await ref.read(apiClientProvider).getMessages(arg);
    return data
        .cast<Map<String, dynamic>>()
        .map(Message.fromJson)
        .toList();
  }

  Future<void> send(String content) async {
    final data = await ref.read(apiClientProvider).sendMessage(arg, content);
    final msg = Message.fromJson(data);
    state = AsyncData([...?state.valueOrNull, msg]);
  }

  void addIncoming(Message msg) {
    final current = state.valueOrNull ?? [];
    if (current.any((m) => m.id == msg.id)) return;
    state = AsyncData([...current, msg]);
  }
}

final messagesProvider =
    AsyncNotifierProvider.family<MessagesNotifier, List<Message>, String>(
  MessagesNotifier.new,
);
