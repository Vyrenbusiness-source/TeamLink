// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:desktop_client/features/projects/project_providers.dart';
import 'package:desktop_client/l10n/app_strings.dart';
import 'package:desktop_client/models/task.dart';
import 'package:desktop_client/providers/auth_provider.dart';
import 'package:desktop_client/services/ws_client.dart';
import 'package:desktop_client/shared/toast_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationWatcher extends ConsumerStatefulWidget {
  const NotificationWatcher({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NotificationWatcher> createState() =>
      _NotificationWatcherState();
}

class _NotificationWatcherState extends ConsumerState<NotificationWatcher> {
  late final StreamSubscription<Map<String, dynamic>> _wsSub;
  Timer? _deadlineTimer;
  final _shownDeadlines = <String>{};
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    _wsSub = WsClient.instance.events.listen(_onWsEvent);
    _deadlineTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkDeadlines(),
    );
    // Forget shown-deadlines whenever the signed-in user changes (logout,
    // re-login, or a new joiner accepting an invite) — otherwise we silently
    // suppress notifications for a fresh identity that happens to share IDs.
    ref.listenManual(authProvider, (prev, next) {
      final newId = next.valueOrNull?.id;
      if (newId != _lastUserId) {
        _shownDeadlines.clear();
        _lastUserId = newId;
      }
    }, fireImmediately: true);
    // initial check after providers have had time to load
    Future.delayed(const Duration(seconds: 3), _checkDeadlines);
  }

  void _onWsEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    if (event['type'] != 'task_assigned') return;
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;
    if ((event['assigneeId'] as String?) != user.id) return;

    final s = ref.read(appStringsProvider);
    ref.read(toastProvider.notifier).show(
      ToastMessage(
        title: s.notificationTaskAssignedTitle,
        body: event['taskTitle'] as String? ?? s.notificationTaskAssignedFallback,
      ),
    );
  }

  void _checkDeadlines() {
    if (!mounted) return;
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;
    final tasks = ref.read(allTasksProvider).valueOrNull;
    if (tasks == null) return;

    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final in24hSec = nowSec + 86400;

    for (final task in tasks) {
      if (task.status == TaskStatus.done) continue;
      final dl = task.deadline;
      if (dl == null || dl <= nowSec || dl > in24hSec) continue;
      if (_shownDeadlines.contains(task.id)) continue;

      final isAssignedToMe = task.assigneeId == user.id;
      final isOpen = task.assigneeId == null;
      if (!isAssignedToMe && !isOpen) continue;

      _shownDeadlines.add(task.id);
      final s = ref.read(appStringsProvider);
      ref.read(toastProvider.notifier).show(
        ToastMessage(
          title: s.notificationDeadlineTodayTitle,
          body: s.notificationDeadlineTodayBodyTemplate
              .replaceAll('{title}', task.title),
          type: ToastType.warning,
        ),
      );
    }
  }

  @override
  void dispose() {
    _wsSub.cancel();
    _deadlineTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
