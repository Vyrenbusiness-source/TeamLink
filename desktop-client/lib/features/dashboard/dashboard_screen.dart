import 'package:desktop_client/features/projects/widgets/create_project_dialog.dart';
import 'package:desktop_client/features/projects/widgets/invite_member_dialog.dart';
import 'package:desktop_client/l10n/app_strings.dart';
import 'package:desktop_client/models/project.dart';
import 'package:desktop_client/providers/auth_provider.dart';
import 'package:desktop_client/features/projects/project_providers.dart';
import 'package:desktop_client/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Root screen: shows login form when unauthenticated,
/// otherwise the project list.
class DashboardScreen extends ConsumerWidget {
  /// Creates a [DashboardScreen].
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(authProvider).when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            body: Center(child: Text('$e')),
          ),
          data: (user) =>
              user == null ? const _LoginView() : const _ProjectsView(),
        );
  }
}

// ── Login / Register ──────────────────────────────────────────────────────────

class _LoginView extends ConsumerStatefulWidget {
  const _LoginView();

  @override
  ConsumerState<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<_LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _isRegister = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider.notifier);
      if (_isRegister) {
        await auth.register(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _pwCtrl.text,
        );
      } else {
        await auth.login(
          _emailCtrl.text.trim(),
          _pwCtrl.text,
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'TeamLink',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_isRegister) ...[
                      TextFormField(
                        controller: _nameCtrl,
                        decoration:
                            InputDecoration(labelText: s.loginNameLabel),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? s.loginNameRequired
                                : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _emailCtrl,
                      decoration:
                          InputDecoration(labelText: s.loginEmailLabel),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          (v == null || !v.contains('@'))
                              ? s.loginEmailInvalid
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pwCtrl,
                      decoration:
                          InputDecoration(labelText: s.loginPasswordLabel),
                      obscureText: true,
                      validator: (v) =>
                          (v == null || v.length < 8)
                              ? s.loginPasswordTooShort
                              : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _isRegister ? s.loginRegister : s.loginSignIn,
                            ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          setState(() => _isRegister = !_isRegister),
                      child: Text(
                        _isRegister
                            ? s.loginSwitchToLogin
                            : s.loginSwitchToRegister,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Projects view ─────────────────────────────────────────────────────────────

class _ProjectsView extends ConsumerWidget {
  const _ProjectsView();

  Future<void> _showCreate(BuildContext context, WidgetRef ref) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => CreateProjectDialog(
        onCreate: (name) =>
            ref.read(projectsProvider.notifier).create(name),
      ),
    );
  }

  Future<void> _showInvite(
    BuildContext context,
    WidgetRef ref,
    String projectId,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => InviteMemberDialog(
        projectId: projectId,
        showRole: false,
        onInvite: ({email, username, required role}) async {
          await ref.read(apiClientProvider).inviteMember(
                projectId: projectId,
                email: email,
                username: username,
              );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final projectsState = ref.watch(projectsProvider);
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TeamLink'),
        actions: [
          if (user != null) ...[
            IconButton(
              onPressed: () => context.go('/overview'),
              icon: const Icon(Icons.dashboard_outlined),
              tooltip: s.dashboardOverviewTooltip,
            ),
            IconButton(
              onPressed: () => context.go('/dm'),
              icon: const Icon(Icons.message_outlined),
              tooltip: s.dashboardMessagesTooltip,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () =>
                    ref.read(authProvider.notifier).logout(),
                icon: const Icon(Icons.logout, size: 18),
                label: Text(user.name),
              ),
            ),
          ],
        ],
      ),
      body: projectsState.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (projects) => _ProjectList(
          projects: projects,
          onInvite: (id) => _showInvite(context, ref, id),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context, ref),
        icon: const Icon(Icons.add),
        label: Text(s.dashboardNewProject),
      ),
    );
  }
}

class _ProjectList extends ConsumerWidget {
  const _ProjectList({
    required this.projects,
    required this.onInvite,
  });

  final List<Project> projects;
  final void Function(String projectId) onInvite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    if (projects.isEmpty) {
      return Center(
        child: Text(s.dashboardEmptyProjects),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: projects.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (ctx, i) {
        final p = projects[i];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.folder_outlined),
            ),
            title: Text(p.name),
            trailing: IconButton(
              tooltip: s.dashboardInviteMemberTooltip,
              icon: const Icon(Icons.person_add_outlined),
              onPressed: () => onInvite(p.id),
            ),
            onTap: () => ctx.go('/projects/${p.id}', extra: p.name),
          ),
        );
      },
    );
  }
}
