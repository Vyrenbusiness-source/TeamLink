// ignore_for_file: public_member_api_docs

import 'package:desktop_client/features/projects/project_providers.dart';
import 'package:desktop_client/features/projects/project_repository.dart';
import 'package:desktop_client/l10n/app_strings.dart';
import 'package:desktop_client/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef CreateTaskCallback = Future<void> Function({
  required String title,
  int? deadline,
  String? assigneeId,
});

class CreateTaskDialog extends ConsumerStatefulWidget {
  const CreateTaskDialog({
    required this.projectId,
    required this.onCreate,
    super.key,
  });

  final String projectId;

  /// Performs the creation. The widget handles validation, loading state,
  /// error display and dismissal.
  final CreateTaskCallback onCreate;

  @override
  ConsumerState<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends ConsumerState<CreateTaskDialog> {
  final _titleCtrl = TextEditingController();
  DateTime? _deadline;
  String? _assigneeId;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (!mounted) return;
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      final s = ref.read(appStringsProvider);
      setState(() => _error = s.createTaskTitleEmpty);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onCreate(
        title: title,
        deadline:
            _deadline != null ? _deadline!.millisecondsSinceEpoch ~/ 1000 : null,
        assigneeId: _assigneeId,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = humanizeError(e);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider(widget.projectId));
    final members = membersAsync.valueOrNull ?? <MemberDetail>[];
    final s = ref.watch(appStringsProvider);

    return AlertDialog(
      title: Text(s.createTaskTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: s.createTaskTitleLabel,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDeadline,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(
                _deadline == null
                    ? s.createTaskPickDeadline
                    : '${_deadline!.day.toString().padLeft(2, '0')}.${_deadline!.month.toString().padLeft(2, '0')}.${_deadline!.year}',
              ),
            ),
            if (_deadline != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _deadline = null),
                  child: Text(s.createTaskRemoveDeadline),
                ),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _assigneeId,
              decoration: InputDecoration(
                labelText: s.createTaskAssigneeLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  child: Text(s.createTaskAssigneeUnassigned),
                ),
                ...members.map(
                  (m) => DropdownMenuItem(
                    value: m.id,
                    child: Text(m.name),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _assigneeId = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(s.createTaskSubmit),
        ),
      ],
    );
  }
}
