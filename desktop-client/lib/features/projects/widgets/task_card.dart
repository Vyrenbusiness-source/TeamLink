// ignore_for_file: public_member_api_docs

import 'package:desktop_client/features/projects/project_providers.dart';
import 'package:desktop_client/l10n/app_strings.dart';
import 'package:desktop_client/models/task.dart';
import 'package:desktop_client/providers/auth_provider.dart';
import 'package:desktop_client/shared/task_status_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TaskCard extends ConsumerWidget {
  const TaskCard({
    required this.task,
    required this.projectId,
    super.key,
  });

  final Task task;
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            context.go('/projects/$projectId/tasks/${task.id}'),
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _StatusChip(status: task.status),
                      if (task.deadline != null) ...[
                        const SizedBox(width: 8),
                        Builder(builder: (context) {
                          final color = _deadlineColor(task.deadline!);
                          return Row(
                            children: [
                              Icon(Icons.schedule, size: 13, color: color),
                              const SizedBox(width: 2),
                              Text(
                                _formatDeadline(task.deadline!, s),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: color,
                                      fontWeight: color == Colors.red
                                          ? FontWeight.bold
                                          : null,
                                    ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            _ActionButton(task: task, projectId: projectId),
          ],
        ),
      ),
      ),
    );
  }

  String _formatDeadline(int unixSeconds, AppStrings s) {
    final dt = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
    final diff = _dayDiff(unixSeconds);
    if (diff < 0) return s.taskOverdue;
    if (diff == 0) return s.taskToday;
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  static int _dayDiff(int unixSeconds) {
    final dt = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDay = DateTime(dt.year, dt.month, dt.day);
    return deadlineDay.difference(today).inDays;
  }

  static Color _deadlineColor(int unixSeconds) {
    final diff = _dayDiff(unixSeconds);
    if (diff < 0) return Colors.red;
    if (diff == 0) return Colors.orange;
    if (diff <= 7) return Colors.amber.shade700;
    return Colors.grey;
  }
}

class _StatusChip extends ConsumerWidget {
  const _StatusChip({required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final (label, color) = taskStatusTheme(s)[status]!;
    return Chip(
      label: Text(label, style: TextStyle(color: color, fontSize: 11)),
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide(color: color.withOpacity(0.4)),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ActionButton extends ConsumerStatefulWidget {
  const _ActionButton({required this.task, required this.projectId});

  final Task task;
  final String projectId;

  @override
  ConsumerState<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends ConsumerState<_ActionButton> {
  bool _loading = false;

  Future<void> _take() async {
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(tasksProvider(widget.projectId).notifier)
          .takeTask(widget.task.id, user.id);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _done() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(tasksProvider(widget.projectId).notifier)
          .markDone(widget.task.id);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.task.status == TaskStatus.done) return const SizedBox.shrink();
    final s = ref.watch(appStringsProvider);

    final child = _loading
        ? const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(
            widget.task.status == TaskStatus.open ? s.taskTake : s.taskComplete,
          );

    if (widget.task.status == TaskStatus.open) {
      return FilledButton.tonal(
        onPressed: _loading ? null : _take,
        child: child,
      );
    }

    return FilledButton(
      onPressed: _loading ? null : _done,
      child: child,
    );
  }
}
