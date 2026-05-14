// ignore_for_file: public_member_api_docs

import 'package:desktop_client/l10n/app_strings.dart';
import 'package:desktop_client/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Signature for the callback that performs the actual invite.
///
/// Exactly one of [email] or [username] is non-null. [role] is one of
/// `'lead' | 'member' | 'observer'` and defaults to `'member'` when the
/// caller hides the role dropdown via [InviteMemberDialog.showRole].
typedef InviteMemberCallback = Future<void> Function({
  String? email,
  String? username,
  required String role,
});

class InviteMemberDialog extends ConsumerStatefulWidget {
  const InviteMemberDialog({
    required this.projectId,
    required this.onInvite,
    this.showRole = true,
    super.key,
  });

  /// ID of the project the user is invited into. Forwarded for the caller's
  /// convenience; the dialog itself does not consume it.
  final String projectId;

  /// Performs the invite. The widget handles validation, loading state,
  /// error display and dismissal.
  final InviteMemberCallback onInvite;

  /// When false, the role dropdown is hidden and `'member'` is submitted.
  final bool showRole;

  @override
  ConsumerState<InviteMemberDialog> createState() =>
      _InviteMemberDialogState();
}

class _InviteMemberDialogState extends ConsumerState<InviteMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _ctrl = TextEditingController();
  String _role = 'member';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String v) => v.contains('@');

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final input = _ctrl.text.trim();
    try {
      await widget.onInvite(
        email: _looksLikeEmail(input) ? input : null,
        username: _looksLikeEmail(input) ? null : input,
        role: _role,
      );
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
      title: Text(s.inviteMemberTitle),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: s.inviteMemberLabel,
                  hintText: s.inviteMemberHint,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? s.inviteMemberRequired
                    : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              if (widget.showRole) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration:
                      InputDecoration(labelText: s.inviteMemberRoleLabel),
                  items: [
                    DropdownMenuItem(value: 'lead', child: Text(s.roleLead)),
                    DropdownMenuItem(
                      value: 'member',
                      child: Text(s.roleMember),
                    ),
                    DropdownMenuItem(
                      value: 'observer',
                      child: Text(s.roleObserver),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _role = v ?? 'member'),
                ),
              ],
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
              : Text(s.inviteMemberSubmit),
        ),
      ],
    );
  }
}
