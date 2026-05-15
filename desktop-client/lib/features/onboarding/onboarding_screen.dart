import 'package:desktop_client/features/onboarding/invite_code.dart';
import 'package:desktop_client/features/onboarding/onboarding_provider.dart';
import 'package:desktop_client/features/projects/project_providers.dart';
import 'package:desktop_client/l10n/app_strings.dart';
import 'package:desktop_client/providers/auth_provider.dart';
import 'package:desktop_client/services/api_client.dart';
import 'package:desktop_client/services/server_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _Flow { unknown, host, joiner }

enum _Step {
  welcome,
  account,
  project,
  invite,
  joinCode,
  joinAccount,
  done,
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _Flow _flow = _Flow.unknown;
  _Step _step = _Step.welcome;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _projectNameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _inviteCodeForDisplay;
  String? _joinedProjectName;
  String? _joinedRole;
  InviteCode? _decodedInvite;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _projectNameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  // ── Host flow ──────────────────────────────────────────────────────────────

  Future<void> _startHostFlow() async {
    await ref.read(serverConfigProvider.notifier).setHost();
    setState(() {
      _flow = _Flow.host;
      _step = _Step.account;
      _error = null;
    });
  }

  Future<void> _hostCreateAccount() async {
    final s = ref.read(appStringsProvider);
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = s.errorFillAllFields);
      return;
    }
    if (password.length < 8) {
      setState(() => _error = s.errorPasswordTooShort);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).register(
            name: name,
            email: email,
            password: password,
          );
      if (mounted) setState(() => _step = _Step.project);
    } catch (e) {
      if (mounted) setState(() => _error = humanizeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _hostCreateProject() async {
    final s = ref.read(appStringsProvider);
    final name = _projectNameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = s.errorProjectName);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final project = await ref.read(projectsProvider.notifier).create(name);
      final api = ref.read(apiClientProvider);

      final tunnel = await _waitForTunnelUrl(api);
      if (tunnel == null) {
        if (mounted) {
          setState(() {
            _error = s.errorTunnelNotReady;
            _loading = false;
          });
        }
        return;
      }

      final invite = await api.createInvite(
        projectId: project.id,
        role: 'member',
      );
      final code = InviteCode(
        serverUrl: tunnel,
        token: invite['token'] as String,
      ).encode();

      if (mounted) {
        setState(() {
          _inviteCodeForDisplay = code;
          _step = _Step.invite;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = humanizeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _waitForTunnelUrl(ApiClient api) async {
    for (var i = 0; i < 30; i++) {
      try {
        final info = await api.getTunnelInfo();
        final url = info['url'] as String?;
        if (url != null && url.isNotEmpty) return url;
      } catch (_) {
        // server might still be coming up
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return null;
  }

  // ── Joiner flow ────────────────────────────────────────────────────────────

  /// "Ich habe schon einen Account": Onboarding als erledigt markieren und
  /// als Host-Modus konfigurieren, damit der Router den User auf /login
  /// weiterleitet. Sinnvoll wenn der Nutzer beim ersten Start aus Versehen
  /// im Onboarding gelandet ist (z.B. nach Update mit geloeschter
  /// onboarding_done-Flag oder neuem Bundle).
  Future<void> _useExistingAccount() async {
    await ref.read(serverConfigProvider.notifier).setHost();
    await markOnboardingDone(ref);
    if (mounted) context.go('/login');
  }

  Future<void> _startJoinerFlow() async {
    setState(() {
      _flow = _Flow.joiner;
      _step = _Step.joinCode;
      _error = null;
    });
  }

  Future<void> _joinerValidateCode() async {
    final s = ref.read(appStringsProvider);
    final raw = _codeCtrl.text.trim();
    final decoded = InviteCode.tryDecode(raw);
    if (decoded == null) {
      setState(() => _error = s.errorInvalidCode);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(serverConfigProvider.notifier).setJoiner(decoded.serverUrl);
      final info =
          await ref.read(apiClientProvider).getInvite(decoded.token);
      if (mounted) {
        setState(() {
          _decodedInvite = decoded;
          _joinedProjectName =
              info['project_name'] as String? ?? 'Workspace';
          _joinedRole = info['role'] as String? ?? 'member';
          _step = _Step.joinAccount;
        });
      }
    } catch (e) {
      // Keep the joiner config — the user may just need to retry on a flaky
      // network. Resetting to host-mode here would force them to paste the
      // code again, which is the wrong recovery for a transient error.
      if (mounted) setState(() => _error = humanizeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinerAcceptInvite() async {
    final s = ref.read(appStringsProvider);
    final invite = _decodedInvite;
    if (invite == null) {
      setState(() => _error = s.errorInvalidCode);
      return;
    }
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = s.errorFillAllFields);
      return;
    }
    if (password.length < 8) {
      setState(() => _error = s.errorPasswordTooShort);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).acceptInvite(
            token: invite.token,
            name: name,
            email: email,
            password: password,
          );
      // Auth muss VOR _finish neu geladen werden, sonst sieht der Router
      // beim naechsten Redirect noch user=null und schiebt den User auf
      // /login statt ins frische Projekt.
      ref.invalidate(authProvider);
      await ref.read(authProvider.future);
      ref.invalidate(projectsProvider);
      await _finish();
    } catch (e) {
      if (mounted) setState(() => _error = humanizeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Finish ─────────────────────────────────────────────────────────────────

  Future<void> _finish() async {
    await markOnboardingDone(ref);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 40,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: _buildStep(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    final s = ref.watch(appStringsProvider);
    switch (_step) {
      case _Step.welcome:
        return _WelcomeStep(
          onHost: _startHostFlow,
          onJoin: _startJoinerFlow,
          onExistingAccount: _useExistingAccount,
        );
      case _Step.account:
        return _AccountFormStep(
          title: s.accountHostTitle,
          subtitle: s.accountHostSubtitle,
          buttonLabel: s.accountHostButton,
          nameCtrl: _nameCtrl,
          emailCtrl: _emailCtrl,
          passwordCtrl: _passwordCtrl,
          loading: _loading,
          error: _error,
          onSubmit: _hostCreateAccount,
        );
      case _Step.project:
        return _ProjectStep(
          ctrl: _projectNameCtrl,
          loading: _loading,
          error: _error,
          onSubmit: _hostCreateProject,
        );
      case _Step.invite:
        return _InviteDisplayStep(
          code: _inviteCodeForDisplay ?? '',
          onFinish: _finish,
        );
      case _Step.joinCode:
        return _JoinCodeStep(
          ctrl: _codeCtrl,
          loading: _loading,
          error: _error,
          onSubmit: _joinerValidateCode,
          onBack: () => setState(() {
            _flow = _Flow.unknown;
            _step = _Step.welcome;
            _error = null;
          }),
        );
      case _Step.joinAccount:
        return _AccountFormStep(
          title: s.accountJoinTitleTemplate
              .replaceAll('{project}', _joinedProjectName ?? ''),
          subtitle: s.accountJoinSubtitleTemplate
              .replaceAll('{role}', _joinedRole ?? 'member'),
          buttonLabel: s.accountJoinButton,
          nameCtrl: _nameCtrl,
          emailCtrl: _emailCtrl,
          passwordCtrl: _passwordCtrl,
          loading: _loading,
          error: _error,
          onSubmit: _joinerAcceptInvite,
        );
      case _Step.done:
        return const SizedBox.shrink();
    }
  }
}

// ── Step widgets ─────────────────────────────────────────────────────────────

class _WelcomeStep extends ConsumerWidget {
  const _WelcomeStep({
    required this.onHost,
    required this.onJoin,
    required this.onExistingAccount,
  });

  final VoidCallback onHost;
  final VoidCallback onJoin;
  final VoidCallback onExistingAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(appStringsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.link_rounded,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 20),
        Text(
          s.welcomeTitle,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          s.welcomeQuestion,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: onHost,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
          child: Text(s.welcomeCreate),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onJoin,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
          child: Text(s.welcomeJoin),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onExistingAccount,
          child: Text(s.welcomeExistingAccount),
        ),
        const SizedBox(height: 16),
        Text(
          s.welcomeHint,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _AccountFormStep extends ConsumerWidget {
  const _AccountFormStep({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.loading,
    required this.error,
    required this.onSubmit,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(appStringsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: nameCtrl,
          autofocus: true,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: s.accountName,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: s.accountEmail,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passwordCtrl,
          obscureText: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: s.accountPassword,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => onSubmit(),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error!,
            style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: loading ? null : onSubmit,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          child: loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(buttonLabel),
        ),
      ],
    );
  }
}

class _ProjectStep extends ConsumerWidget {
  const _ProjectStep({
    required this.ctrl,
    required this.loading,
    required this.error,
    required this.onSubmit,
  });

  final TextEditingController ctrl;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(appStringsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.projectTitle,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          s.projectSubtitle,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: s.projectLabel,
            hintText: s.projectHint,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => onSubmit(),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error!,
            style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: loading ? null : onSubmit,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          child: loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(s.projectCreateButton),
        ),
        if (loading) ...[
          const SizedBox(height: 12),
          Text(
            s.projectTunnelStarting,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _InviteDisplayStep extends ConsumerWidget {
  const _InviteDisplayStep({required this.code, required this.onFinish});

  final String code;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(appStringsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          s.inviteReadyTitle,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          s.inviteReadyBody,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                tooltip: s.inviteCopyTooltip,
                icon: const Icon(Icons.content_copy_rounded, size: 18),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(s.inviteCopiedToast),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          s.inviteFooterHint,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onFinish,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          child: Text(s.inviteFinishButton),
        ),
      ],
    );
  }
}

class _JoinCodeStep extends ConsumerWidget {
  const _JoinCodeStep({
    required this.ctrl,
    required this.loading,
    required this.error,
    required this.onSubmit,
    required this.onBack,
  });

  final TextEditingController ctrl;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(appStringsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.joinTitle,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          s.joinSubtitle,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: s.joinCodeLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error!,
            style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: loading ? null : onSubmit,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          child: loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(s.joinConnectButton),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: loading ? null : onBack,
          child: Text(s.back),
        ),
      ],
    );
  }
}
