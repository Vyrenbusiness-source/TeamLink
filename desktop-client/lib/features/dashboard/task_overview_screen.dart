// ignore_for_file: public_member_api_docs

import 'package:desktop_client/features/projects/project_providers.dart';
import 'package:desktop_client/l10n/app_strings.dart';
import 'package:desktop_client/models/project.dart';
import 'package:desktop_client/models/task.dart';
import 'package:desktop_client/shared/task_status_theme.dart';
import 'package:desktop_client/shared/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _SortBy { deadline, newest, title }

enum _ViewMode { kanban, list }

class TaskOverviewScreen extends ConsumerStatefulWidget {
  const TaskOverviewScreen({super.key});

  @override
  ConsumerState<TaskOverviewScreen> createState() =>
      _TaskOverviewScreenState();
}

class _TaskOverviewScreenState extends ConsumerState<TaskOverviewScreen> {
  _ViewMode _viewMode = _ViewMode.kanban;
  final Set<TaskStatus> _statusFilter = {};
  _SortBy _sortBy = _SortBy.deadline;

  void _toggleStatusFilter(TaskStatus status) {
    setState(() {
      if (_statusFilter.contains(status)) {
        _statusFilter.remove(status);
      } else {
        _statusFilter.add(status);
      }
    });
  }

  List<Task> _applyFiltersAndSort(List<Task> tasks) {
    final Iterable<Task> filtered = _statusFilter.isEmpty
        ? tasks
        : tasks.where((t) => _statusFilter.contains(t.status));
    final result = filtered.toList();
    switch (_sortBy) {
      case _SortBy.deadline:
        result.sort((a, b) {
          if (a.deadline == null && b.deadline == null) return 0;
          if (a.deadline == null) return 1;
          if (b.deadline == null) return -1;
          return a.deadline!.compareTo(b.deadline!);
        });
      case _SortBy.newest:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _SortBy.title:
        result.sort((a, b) => a.title.compareTo(b.title));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final allTasksAsync = ref.watch(allTasksProvider);
    final projects = ref.watch(projectsProvider).valueOrNull ?? [];
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.overviewTitle),
        actions: [
          IconButton(
            tooltip: _viewMode == _ViewMode.kanban
                ? s.overviewListViewTooltip
                : s.overviewKanbanViewTooltip,
            icon: Icon(
              _viewMode == _ViewMode.kanban
                  ? Icons.view_list_outlined
                  : Icons.view_column_outlined,
            ),
            onPressed: () => setState(() {
              _viewMode = _viewMode == _ViewMode.kanban
                  ? _ViewMode.list
                  : _ViewMode.kanban;
            }),
          ),
        ],
      ),
      body: allTasksAsync.when(
        loading: () => const SkeletonKanbanColumns(),
        error: (e, _) => Center(child: Text('$e')),
        data: (tasks) {
          if (_viewMode == _ViewMode.kanban) {
            return _DashboardBody(tasks: tasks, projects: projects);
          }
          final filtered = _applyFiltersAndSort(tasks);
          return _VirtualizedTaskList(
            tasks: filtered,
            totalCount: tasks.length,
            projects: projects,
            statusFilter: _statusFilter,
            sortBy: _sortBy,
            onToggleFilter: _toggleStatusFilter,
            onSortChanged: (v) => setState(() => _sortBy = v),
          );
        },
      ),
    );
  }
}

// ── Kanban view ───────────────────────────────────────────────────────────────

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

// ── Virtualized list view ─────────────────────────────────────────────────────

class _VirtualizedTaskList extends ConsumerWidget {
  const _VirtualizedTaskList({
    required this.tasks,
    required this.totalCount,
    required this.projects,
    required this.statusFilter,
    required this.sortBy,
    required this.onToggleFilter,
    required this.onSortChanged,
  });

  final List<Task> tasks;
  final int totalCount;
  final List<Project> projects;
  final Set<TaskStatus> statusFilter;
  final _SortBy sortBy;
  final void Function(TaskStatus) onToggleFilter;
  final void Function(_SortBy) onSortChanged;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterBar(
          statusTheme: statusTheme,
          statusFilter: statusFilter,
          sortBy: sortBy,
          filteredCount: tasks.length,
          totalCount: totalCount,
          onToggleFilter: onToggleFilter,
          onSortChanged: onSortChanged,
        ),
        const Divider(height: 1),
        Expanded(
          child: tasks.isEmpty
              ? Center(
                  child: Text(
                    s.overviewColumnEmpty,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                )
              : ListView.builder(
                  itemCount: tasks.length,
                  itemExtent: 72.0,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return RepaintBoundary(
                      key: ValueKey(task.id),
                      child: _TaskListRow(
                        task: task,
                        projectName: _projectName(task.projectId),
                        statusTheme: statusTheme,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({
    required this.statusTheme,
    required this.statusFilter,
    required this.sortBy,
    required this.filteredCount,
    required this.totalCount,
    required this.onToggleFilter,
    required this.onSortChanged,
  });

  final Map<TaskStatus, (String, Color)> statusTheme;
  final Set<TaskStatus> statusFilter;
  final _SortBy sortBy;
  final int filteredCount;
  final int totalCount;
  final void Function(TaskStatus) onToggleFilter;
  final void Function(_SortBy) onSortChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: Text(s.overviewFilterAll),
            selected: statusFilter.isEmpty,
            onSelected: (_) {
              for (final st in TaskStatus.values) {
                if (statusFilter.contains(st)) onToggleFilter(st);
              }
            },
          ),
          const SizedBox(width: 6),
          for (final status in TaskStatus.values) ...[
            FilterChip(
              label: Text(statusTheme[status]!.$1),
              selected: statusFilter.contains(status),
              selectedColor: statusTheme[status]!.$2.withOpacity(0.15),
              checkmarkColor: statusTheme[status]!.$2,
              side: statusFilter.contains(status)
                  ? BorderSide(
                      color: statusTheme[status]!.$2.withOpacity(0.5),
                    )
                  : null,
              onSelected: (_) => onToggleFilter(status),
            ),
            const SizedBox(width: 6),
          ],
          const SizedBox(width: 8),
          Text(
            '$filteredCount / $totalCount',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<_SortBy>(
            value: sortBy,
            underline: const SizedBox.shrink(),
            isDense: true,
            items: [
              DropdownMenuItem(
                value: _SortBy.deadline,
                child: Text(
                  s.overviewSortDeadline,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              DropdownMenuItem(
                value: _SortBy.newest,
                child: Text(
                  s.overviewSortNewest,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              DropdownMenuItem(
                value: _SortBy.title,
                child: Text(
                  s.overviewSortTitle,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
            onChanged: (v) {
              if (v != null) onSortChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _TaskListRow extends StatelessWidget {
  const _TaskListRow({
    required this.task,
    required this.projectName,
    required this.statusTheme,
  });

  final Task task;
  final String projectName;
  final Map<TaskStatus, (String, Color)> statusTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (statusLabel, statusColor) = statusTheme[task.status]!;
    final isDone = task.status == TaskStatus.done;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      task.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        decoration:
                            isDone ? TextDecoration.lineThrough : null,
                        color: isDone ? theme.colorScheme.outline : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      projectName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 11),
                ),
                backgroundColor: statusColor.withOpacity(0.12),
                side: BorderSide(color: statusColor.withOpacity(0.3)),
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                visualDensity: VisualDensity.compact,
              ),
              if (task.deadline != null) ...[
                const SizedBox(width: 8),
                _DeadlineChip(unix: task.deadline!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

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
                  style: theme.textTheme.labelLarge?.copyWith(color: color),
                ),
                const Spacer(),
                Text(
                  '${tasks.length}',
                  style: theme.textTheme.labelLarge?.copyWith(color: color),
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
