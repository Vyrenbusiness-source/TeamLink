// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:desktop_client/features/dm/dm_provider.dart';
import 'package:desktop_client/l10n/app_strings.dart';
import 'package:desktop_client/models/message.dart';
import 'package:desktop_client/providers/auth_provider.dart';
import 'package:desktop_client/services/ws_client.dart';
import 'package:desktop_client/shared/widgets/empty_state.dart';
import 'package:desktop_client/shared/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DmListScreen extends ConsumerStatefulWidget {
  const DmListScreen({super.key});

  @override
  ConsumerState<DmListScreen> createState() => _DmListScreenState();
}

class _DmListScreenState extends ConsumerState<DmListScreen> {
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).valueOrNull;
    if (user != null) {
      ref.read(wsClientProvider).joinUser(user.id);
    }
    _wsSub = ref.read(wsClientProvider).events.listen((msg) {
      if (!mounted) return;
      if (msg['type'] == 'dm') {
        ref.invalidate(conversationsProvider);
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> _showNewDmDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _NewDmDialog(
        onSelected: (user) {
          context.go('/dm/${user.id}', extra: user.name);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider);
    final currentUser = ref.watch(authProvider).valueOrNull;
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.dmTitle)),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewDmDialog,
        icon: const Icon(Icons.edit_outlined),
        label: Text(s.dmNew),
      ),
      body: conversations.when(
        loading: () => const SkeletonListView(count: 4, hasLeading: true),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.chat_bubble_outline,
              title: s.dmEmptyTitle,
              subtitle: s.dmEmptySubtitle,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final c = list[i];
              final isMe = currentUser?.id == c.lastSenderId;
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                  ),
                ),
                title: Text(c.name),
                subtitle: Text(
                  '${isMe ? s.dmYouPrefix : ''}${c.lastContent}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: c.lastAt > 0
                    ? Text(
                        _formatTime(c.lastAt),
                        style: Theme.of(ctx).textTheme.bodySmall,
                      )
                    : null,
                onTap: () => context.go('/dm/${c.id}', extra: c.name),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(int unixSec) {
    final dt = DateTime.fromMillisecondsSinceEpoch(unixSec * 1000);
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return DateFormat('HH:mm').format(dt);
    }
    return DateFormat('dd.MM').format(dt);
  }
}

class _NewDmDialog extends ConsumerWidget {
  const _NewDmDialog({required this.onSelected});

  final void Function(DmUser user) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(dmUsersProvider);
    final s = ref.watch(appStringsProvider);
    return AlertDialog(
      title: Text(s.dmNewTitle),
      content: SizedBox(
        width: 320,
        child: users.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
          data: (list) {
            if (list.isEmpty) {
              return Text(s.dmNoTeamMembers);
            }
            return ListView.builder(
              shrinkWrap: true,
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final u = list[i];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(u.name[0].toUpperCase()),
                  ),
                  title: Text(u.name),
                  subtitle: Text(u.email),
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelected(u);
                  },
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
      ],
    );
  }
}

class DmChatScreen extends ConsumerStatefulWidget {
  const DmChatScreen({
    required this.partnerId,
    required this.partnerName,
    super.key,
  });

  final String partnerId;
  final String partnerName;

  @override
  ConsumerState<DmChatScreen> createState() => _DmChatScreenState();
}

class _DmChatScreenState extends ConsumerState<DmChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).valueOrNull;
    if (user != null) {
      ref.read(wsClientProvider).joinUser(user.id);
    }
    _wsSub = ref.read(wsClientProvider).events.listen((msg) {
      if (!mounted) return;
      if (msg['type'] == 'dm' && msg['message'] != null) {
        final incoming =
            Message.fromJson(msg['message'] as Map<String, dynamic>);
        if (incoming.senderId == widget.partnerId ||
            incoming.recipientId == widget.partnerId) {
          ref
              .read(messagesProvider(widget.partnerId).notifier)
              .addIncoming(incoming);
          _scrollToBottom();
        }
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _inputCtrl.clear();
    try {
      await ref
          .read(messagesProvider(widget.partnerId).notifier)
          .send(text);
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.partnerId));
    final currentUserId = ref.watch(authProvider).valueOrNull?.id;
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dm'),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              child: Text(
                widget.partnerName.isNotEmpty
                    ? widget.partnerName[0].toUpperCase()
                    : '?',
              ),
            ),
            const SizedBox(width: 12),
            Text(widget.partnerName),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              loading: () => const SkeletonChatBubbles(),
              error: (e, _) => Center(child: Text('$e')),
              data: (list) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.forum_outlined,
                    title: s.dmChatEmptyTitle,
                    subtitle: s.dmChatEmptySubtitle,
                  );
                }
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) {
                    final m = list[i];
                    final isMe = m.senderId == currentUserId;
                    return _MessageBubble(message: m, isMe: isMe);
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    decoration: InputDecoration(
                      hintText: s.dmInputHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMe});

  final Message message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = isMe
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final fg = isMe
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(message.content, style: TextStyle(color: fg)),
            if (message.createdAt != null) ...[
              const SizedBox(height: 2),
              Text(
                DateFormat('HH:mm').format(
                  DateTime.fromMillisecondsSinceEpoch(
                    message.createdAt! * 1000,
                  ),
                ),
                style: TextStyle(
                  color: fg.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
