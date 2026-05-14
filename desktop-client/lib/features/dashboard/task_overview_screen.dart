// ignore_for_file: public_member_api_docs

import 'package:desktop_client/features/projects/project_providers.dart';
import 'package:desktop_client/l10n/app_strings.dart';
import 'package:desktop_client/models/project.dart';
import 'package:desktop_client/models/task.dart';
import 'package:desktop_client/shared/task_status_theme.dart';
import 'package:desktop_client/shared/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TaskOverviewScreen extends ConsumerWidget {
  const TaskOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTasksAsync = ref.watch(allTasksProvider);
    final projects = ref.watch(projectsProvider).valueOrNull ?? [];
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.overviewTitle)),
      body: allTasksAsync.when(
        loading: () => const SkeletonKanbanColumns(),
        error: (e, _) => Center(child: Text('$e')),
        data: (tasks) => _DashboardBody(tasks: tasks, projects: projects),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({
    required this.tasks,
    required this.projects,
  });

  final List<Task> tasks;
  final List<Project> projects;

  String _projectName(String projectId) {
    try {
      return projects.firstWhere((p) => p.id == projectId).name;
    } on StateError {
      return projectId;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final statusTheme = taskStatusTheme(s);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final open = tasks.where((t) => t.status == TaskStatus.open).toList();
    final taken = tasks.where((t) => t.status == TaskStatus.taken).toList();
    final done = tasks.where((t) => t.status == TaskStatus.done).toList();

    final upcoming = tasks.where((t) {
      if (t.deadline == null) return false;
      final dt = DateTime.fromMillisecondsSinceEpoch(t.deadline! * 1000);
      final deadlineDay = DateTime(dt.year, dt.month, dt.day);
      final diff = deadlineDay.difference(today).inDays;
      return diff >= 0 && diff <= 14;
    }).toList()
      ..sort((a, b) => a.deadline!.compareTo(b.deadline!));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: s.overviewSectionTasks, total: tasks.length),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _TaskColumn(
                  label: statusTheme[TaskStatus.open]!.$1,
                  color: statusTheme[TaskStatus.open]!.$2,
                  tasks: open,
                  projectName: _projectName,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TaskColumn(
                  label: statusTheme[TaskStatus.taken]!.$1,
                  color: statusTheme[TaskStatus.taken]!.$2,
                  tasks: taken,
                  projectName: _projectName,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TaskColumn(
                  label: statusTheme[TaskStatus.done]!.$1,
                  color: statusTheme[TaskStatus.done]!.$2,
                  tasks: done,
                  projectName: _projectName,
                ),
              ),
            ],
          ),
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeader(
              title: s.overviewSectionDeadlines,
              total: upcoming.length,
            ),
            const SizedBox(height: 12),
            _DeadlineList(tasks: upcoming, projectName: _projectName),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.total});

  final String title;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(width: 8),
        Chip(
          label: Text('$total'),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

class _TaskColumn extends ConsumerWidget {
  const _TaskColumn({
    required this.label,
    required this.color,
    required this.tasks,
    required this.projectName,
  });

  final String label;
  final Color color;
  final List<Task> tasks;
  final String Function(String) projectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                Text(
                  label,
                  style:
                      theme.textTheme.labelLarge?.copyWith(color: color),
                ),
                const Spacer(),
                Text(
                  '${tasks.length}',
                  style:
                      theme.textTheme.labelLarge?.copyWith(color: color),
                ),
              ],
            ),
          ),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                s.overviewColumnEmpty,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            )
          else
            ...tasks.map(
              (t) => ListTile(
                dense: true,
                title: Text(t.title),
                subtitle: Text(
                  projectName(t.projectId),
                  style: theme.textTheme.bodySmall,
                ),
                trailing: t.deadline != null
                    ? _DeadlineChip(unix: t.deadline!)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _DeadlineList extends StatelessWidget {
  const _DeadlineList({
    required this.tasks,
    required this.projectName,
  });

  final List<Task> tasks;
  final String Function(String) projectName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: tasks
            .map(
              (t) => ListTile(
                leading: _DeadlineChip(unix: t.deadline!),
                title: Text(t.title),
                subtitle: Text(projectName(t.projectId)),
                trailing: _StatusChip(status: t.status),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _DeadlineChip extends ConsumerWidget {
  const _DeadlineChip({required this.unix});

  final int unix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final dt = DateTime.fromMillisecondsSinceEpoch(unix * 1000);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDay = DateTime(dt.year, dt.month, dt.day);
    final diff = deadlineDay.difference(today).inDays;

    final String label;
    final Color bgColor;
    final Color fgColor;
    if (diff < 0) {
      label = s.overviewDeadlineOverdue;
      bgColor = Colors.red.shade700;
      fgColor = Colors.white;
    } else if (diff == 0) {
      label = s.overviewDeadlineToday;
      bgColor = Colors.deepOrange;
      fgColor = Colors.white;
    } else if (diff <= 7) {
      label = '${dt.day}.${dt.month}.';
      bgColor = Colors.amber.shade200;
      fgColor = Colors.amber.shade900;
    } else {
      label = '${dt.day}.${dt.month}.';
      bgColor = Colors.grey.shade200;
      fgColor = Colors.grey.shade700;
    }

    return Chip(
      label: Text(
        label,
        style: TextStyle(color: fgColor, fontSize: 11),
      ),
      backgroundColor: bgColor,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
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
      backgroundColor: color.withOpacity(0.15),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}
