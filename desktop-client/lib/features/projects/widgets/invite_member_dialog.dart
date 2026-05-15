// ignore_for_file: public_member_api_docs

import 'package:desktop_client/features/onboarding/invite_code.dart';
import 'package:desktop_client/l10n/app_strings.dart';
import 'package:desktop_client/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dialog that creates a token-based invite for [projectId] and displays it
/// as a copy-and-share code. Replaces the old "find user by email" flow,
/// which produced "user not found" for everyone who didn't already have an
/// account on the host server.
class InviteMemberDialog extends ConsumerStatefulWidget {
  const InviteMemberDialog({
    required this.projectId,
    this.showRole = true,
    super.key,
  });

  /// ID of the project the invite belongs to. The server scopes the token
  /// to this project; redeeming it adds the new user as a member.
  final String projectId;

  /// When false, the role dropdown is hidden and `'member'` is used.
  final bool showRole;

  @override
  ConsumerState<InviteMemberDialog> createState() =>
      _InviteMemberDialogState();
}

class _InviteMemberDialogState extends ConsumerState<InviteMemberDialog> {
  String _role = 'member';
  bool _loading = true;
  String? _error;
  String? _code;

  @override
  void initState() {
    super.initState();
    _generateCode();
  }

  Future<void> _generateCode() async {
    setState(() {
      _loading = true;
      _error = null;
      _code = null;
    });
    final api = ref.read(apiClientProvider);
    try {
      // 1) Get the Cloudflare tunnel URL the host server is currently
      //    publishing. Without a public URL the joiner cannot connect, so
      //    we surface a clear error instead of falling back to localhost
      //    (which would only work on the same machine).
      final tunnel = await _waitForTunnelUrl(api);
      if (tunnel == null) {
        if (mounted) {
          final s = ref.read(appStringsProvider);
          setState(() {
            _error = s.errorTunnelNotReady;
            _loading = false;
          });
        }
        return;
      }

      // 2) Create a fresh invite token scoped to this project and role.
      final invite = await api.createInvite(
        projectId: widget.projectId,
        role: _role,
      );

      // 3) Pack the tunnel URL + token into the same TLK1.* code format
      //    the onboarding flow already understands on the joiner side.
      final code = InviteCode(
        serverUrl: tunnel,
        token: invite['token'] as String,
      ).encode();

      if (mounted) {
        setState(() {
          _code = code;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = humanizeError(e);
          _loading = false;
        });
      }
    }
  }

  /// Polls /host/tunnel briefly so that we don't fail the very first invite
  /// when the tunnel is still coming up after a fresh server start.
  Future<String?> _waitForTunnelUrl(ApiClient api) async {
    for (var i = 0; i < 10; i++) {
      try {
        final info = await api.getTunnelInfo();
        final url = info['url'] as String?;
        if (url != null && url.isNotEmpty) return url;
      } catch (_) {
        // ignore transient errors while the server is still initialising
      }
      if (i < 9) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
    }
    return null;
  }

  Future<void> _copy() async {
    final code = _code;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    final s = ref.read(appStringsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.inviteCopiedToast),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(s.inviteMemberTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.inviteMemberTokenSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (widget.showRole) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: InputDecoration(
                  labelText: s.inviteMemberRoleLabel,
                  border: const OutlineInputBorder(),
                ),
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
                onChanged: _loading
                    ? null
                    : (v) {
                        if (v == null || v == _role) return;
                        setState(() => _role = v);
                        _generateCode();
                      },
              ),
            ],
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 18,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (_code != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        _code!,
                        maxLines: 4,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: s.inviteCopyTooltip,
                      icon: const Icon(
                        Icons.content_copy_rounded,
                        size: 18,
                      ),
                      onPressed: _copy,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              s.inviteMemberTokenFooter,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_error != null)
          TextButton(
            onPressed: _loading ? null : _generateCode,
            child: Text(s.retry),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_code != null),
          child: Text(s.close),
        ),
      ],
    );
  }
}
