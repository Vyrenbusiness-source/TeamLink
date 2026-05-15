// ignore_for_file: public_member_api_docs

import 'package:desktop_client/features/projects/project_providers.dart';
import 'package:desktop_client/l10n/app_strings.dart';
import 'package:desktop_client/models/task.dart';
import 'package:desktop_client/services/api_client.dart';
import 'package:desktop_client/shared/task_status_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({
    required this.projectId,
    required this.taskId,
    super.key,
  });

  final String projectId;
  final String taskId;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  bool _editing = false;
  bool _saving = false;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  TaskStatus _editStatus = TaskStatus.open;
  TaskPriority? _editPriority;
  DateTime? _editDeadline;
  bool _clearDeadline = false;
  String? _editAssigneeId;
  bool _assigneeCleared = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _descCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _startEditing(Task task) {
    _titleCtrl.text = task.title;
    _descCtrl.text = task.description ?? '';
    _editStatus = task.status;
    _editPriority = task.priority;
    _editDeadline = task.deadline != null
        ? DateTime.fromMillisecondsSinceEpoch(task.deadline! * 1000)
        : null;
    _clearDeadline = false;
    _editAssigneeId = task.assigneeId;
    _assigneeCleared = false;
    setState(() => _editing = true);
  }

  Future<void> _save(Task task) async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    try {
      final desc = _descCtrl.text.trim();
      await ref.read(tasksProvider(widget.projectId).notifier).editTask(
            taskId: task.id,
            title: title,
            description: desc.isEmpty ? null : desc,
            status: _editStatus,
            priority: _editPriority,
            deadline: _clearDeadline
                ? null
                : _editDeadline != null
                    ? (_editDeadline!.millisecondsSinceEpoch ~/ 1000)
                    : null,
            clearDeadline: _clearDeadline,
            assigneeId: _assigneeCleared ? null : _editAssigneeId,
            clearAssignee: _assigneeCleared,
          );
      if (mounted) setState(() => _editing = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(BuildContext context, Task task) async {
    final s = ref.read(appStringsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.taskDetailDeleteConfirmTitle),
        content: Text(s.taskDetailDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref
          .read(tasksProvider(widget.projectId).notifier)
          .deleteTask(task.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(humanizeError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider(widget.projectId));
    final s = ref.watch(appStringsProvider);

    return tasks.when(
      loading: () => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/projects/${widget.projectId}'),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/projects/${widget.projectId}'),
          ),
        ),
        body: Center(child: Text(e.toString())),
      ),
      data: (list) {
        final task = list.where((t) => t.id == widget.taskId).firstOrNull;
        if (task == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/projects/${widget.projectId}'),
              ),
            ),
            body: const Center(child: Text('—')),
          );
        }
        return _editing
            ? _buildEditScaffold(context, task, s)
            : _buildDetailScaffold(context, task, s);
      },
    );
  }

  Scaffold _buildDetailScaffold(
    BuildContext context,
    Task task,
    AppStrings s,
  ) {
    final theme = Theme.of(context);
    final members = ref.watch(membersProvider(widget.projectId));
    final statusTheme = taskStatusTheme(s);
    final (statusLabel, statusColor) = statusTheme[task.status]!;

    String assigneeDisplay = s.createTaskAssigneeUnassigned;
    if (task.assigneeId != null) {
      assigneeDisplay = members.valueOrNull
              ?.where((m) => m.id == task.assigneeId)
              .firstOrNull
              ?.name ??
          task.assigneeId!;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: s.back,
          onPressed: () => context.go('/projects/${widget.projectId}'),
        ),
        title: Text(task.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: s.taskDetailEditTitle,
            onPressed: () => _startEditing(task),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: s.delete,
            onPressed: () => _delete(context, task),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    statusLabel,
                    style: TextStyle(color: statusColor, fontSize: 12),
                  ),
                  backgroundColor: statusColor.withOpacity(0.12),
                  side: BorderSide(color: statusColor.withOpacity(0.4)),
                ),
                if (task.priority != null)
                  _PriorityChip(priority: task.priority!, s: s),
              ],
            ),
            const SizedBox(height: 20),
            if (task.description != null &&
                task.description!.isNotEmpty) ...[
              Text(s.taskDetailDescriptionLabel,
                  style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(task.description!, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 20),
            ],
            _MetaRow(
              icon: Icons.schedule_outlined,
              label: 'Deadline',
              value: task.deadline != null
                  ? _fmtDate(DateTime.fromMillisecondsSinceEpoch(
                      task.deadline! * 1000))
                  : '—',
            ),
            _MetaRow(
              icon: Icons.person_outline,
              label: s.createTaskAssigneeLabel,
              value: assigneeDisplay,
            ),
            _MetaRow(
              icon: Icons.calendar_today_outlined,
              label: 'Erstellt',
              value: _fmtDate(
                  DateTime.fromMillisecondsSinceEpoch(task.createdAt * 1000)),
            ),
          ],
        ),
      ),
    );
  }

  Scaffold _buildEditScaffold(
    BuildContext context,
    Task task,
    AppStrings s,
  ) {
    final members = ref.watch(membersProvider(widget.projectId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: s.cancel,
          onPressed: _saving ? null : () => setState(() => _editing = false),
        ),
        title: Text(s.taskDetailEditTitle),
        actions: [
          TextButton(
            onPressed:
                _saving ? null : () => setState(() => _editing = false),
            child: Text(s.cancel),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _saving
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : FilledButton(
                    onPressed: () => _save(task),
                    child: Text(s.save),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: s.createTaskTitleLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: s.taskDetailDescriptionLabel,
                hintText: s.taskDetailDescriptionHint,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              minLines: 2,
              maxLines: 6,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TaskStatus>(
              value: _editStatus,
              decoration: InputDecoration(
                labelText: 'Status',
                border: const OutlineInputBorder(),
              ),
              items: TaskStatus.values
                  .map(
                    (st) => DropdownMenuItem(
                      value: st,
                      child: Text(_statusLabel(st, s)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _editStatus = v);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TaskPriority?>(
              value: _editPriority,
              decoration: InputDecoration(
                labelText: s.taskDetailPriorityLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem<TaskPriority?>(
                  value: null,
                  child: const Text('—'),
                ),
                ...TaskPriority.values.map(
                  (p) => DropdownMenuItem(
                    value: p,
                    child: Text(_priorityLabel(p, s)),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _editPriority = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      _clearDeadline || _editDeadline == null
                          ? s.createTaskPickDeadline
                          : _fmtDate(_editDeadline!),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _editDeadline ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null && mounted) {
                        setState(() {
                          _editDeadline = picked;
                          _clearDeadline = false;
                        });
                      }
                    },
                  ),
                ),
                if (_editDeadline != null && !_clearDeadline) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: s.createTaskRemoveDeadline,
                    onPressed: () => setState(() {
                      _editDeadline = null;
                      _clearDeadline = true;
                    }),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            members.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (list) => DropdownButtonFormField<String?>(
                value: _assigneeCleared ? null : _editAssigneeId,
                decoration: InputDecoration(
                  labelText: s.createTaskAssigneeLabel,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(s.createTaskAssigneeUnassigned),
                  ),
                  ...list.map(
                    (m) => DropdownMenuItem(
                      value: m.id,
                      child: Text(m.name),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() {
                  _editAssigneeId = v;
                  _assigneeCleared = v == null;
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(TaskStatus st, AppStrings s) => switch (st) {
        TaskStatus.open => s.taskStatusOpen,
        TaskStatus.taken => s.taskStatusTaken,
        TaskStatus.done => s.taskStatusDone,
      };

  static String _priorityLabel(TaskPriority p, AppStrings s) => switch (p) {
        TaskPriority.low => s.priorityLow,
        TaskPriority.medium => s.priorityMedium,
        TaskPriority.high => s.priorityHigh,
        TaskPriority.urgent => s.priorityUrgent,
      };

  static String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority, required this.s});

  final TaskPriority priority;
  final AppStrings s;

  static Color _color(TaskPriority p) => switch (p) {
        TaskPriority.low => Colors.blue,
        TaskPriority.medium => Colors.green.shade700,
        TaskPriority.high => Colors.orange.shade700,
        TaskPriority.urgent => Colors.red.shade700,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color(priority);
    final label = switch (priority) {
      TaskPriority.low => s.priorityLow,
      TaskPriority.medium => s.priorityMedium,
      TaskPriority.high => s.priorityHigh,
      TaskPriority.urgent => s.priorityUrgent,
    };
    return Chip(
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide(color: color.withOpacity(0.4)),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.outline),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
