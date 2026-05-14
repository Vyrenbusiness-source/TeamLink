// ignore_for_file: public_member_api_docs

import 'package:desktop_client/l10n/app_strings.dart';
import 'package:desktop_client/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Signature for the callback that performs the actual project creation.
typedef CreateProjectCallback = Future<void> Function(String name);

class CreateProjectDialog extends ConsumerStatefulWidget {
  const CreateProjectDialog({required this.onCreate, super.key});

  /// Performs the creation. The widget handles validation, loading state,
  /// error display and dismissal.
  final CreateProjectCallback onCreate;

  @override
  ConsumerState<CreateProjectDialog> createState() =>
      _CreateProjectDialogState();
}

class _CreateProjectDialogState extends ConsumerState<CreateProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onCreate(_nameCtrl.text.trim());
      if (mounted) Navigator.of(context).pop(true);
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
    final s = ref.watch(appStringsProvider);
    return AlertDialog(
      title: Text(s.createProjectTitle),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: s.createProjectNameLabel,
                  hintText: s.createProjectNameHint,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? s.createProjectNameRequired
                    : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _loading ? null : () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(s.createProjectSubmit),
        ),
      ],
    );
  }
}
