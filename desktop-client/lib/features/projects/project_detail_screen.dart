// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:desktop_client/models/project.dart';
import 'package:desktop_client/features/projects/notes_provider.dart';
import 'package:desktop_client/features/projects/project_providers.dart';
import 'package:desktop_client/features/projects/widgets/create_task_dialog.dart';
import 'package:desktop_client/features/projects/widgets/invite_member_dialog.dart';
import 'package:desktop_client/features/projects/widgets/task_card.dart';
import 'package:desktop_client/l10n/app_strings.dart';
import 'package:desktop_client/services/ws_client.dart';
import 'package:desktop_client/shared/widgets/empty_state.dart';
import 'package:desktop_client/shared/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({
    required this.projectId,
    required this.projectName,
    super.key,
  });

  final String projectId;
  final String projectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final project = ref
        .watch(projectsProvider)
        .valueOrNull
        ?.where((p) => p.id == projectId)
        .firstOrNull;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(project?.name ?? projectName),
          actions: [
            Consumer(
              builder: (context, ref, _) => IconButton(
                onPressed: () =>
                    _showEditProjectDialog(context, ref, project),
                icon: const Icon(Icons.edit_outlined),
                tooltip: s.projectEditTitle,
              ),
            ),
            Consumer(
              builder: (context, ref, _) => IconButton(
                onPressed: () => _showInviteDialog(context, ref),
                icon: const Icon(Icons.person_add_outlined),
                tooltip: s.projectDetailInviteTooltip,
              ),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.task_alt),
                text: s.projectDetailTabTasks,
              ),
              Tab(
                icon: const Icon(Icons.edit_note),
                text: s.projectDetailTabNotes,
              ),
              Tab(
                icon: const Icon(Icons.people),
                text: s.projectDetailTabMembers,
              ),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCreateTask(context),
          icon: const Icon(Icons.add),
          label: Text(s.projectDetailNewTask),
        ),
        body: TabBarView(
          children: [
            _TasksTab(projectId: projectId),
            _NotesTab(projectId: projectId),
            _MembersTab(projectId: projectId),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditProjectDialog(
    BuildContext context,
    WidgetRef ref,
    Project? project,
  ) async {
    final s = ref.read(appStringsProvider);
    final nameCtrl =
        TextEditingController(text: project?.name ?? projectName);
    final descCtrl =
        TextEditingController(text: project?.description ?? '');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.projectEditTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: s.createProjectNameLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: InputDecoration(
                labelText: s.projectEditDescriptionLabel,
                border: const OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final desc = descCtrl.text.trim();
              await ref.read(projectsProvider.notifier).updateProject(
                    projectId,
                    name: name,
                    description: desc.isEmpty ? null : desc,
                  );
            },
            child: Text(s.save),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    descCtrl.dispose();
  }

  Future<void> _showCreateTask(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) => CreateTaskDialog(
          projectId: projectId,
          onCreate: ({required title, deadline, assigneeId}) =>
              ref.read(tasksProvider(projectId).notifier).create(
                    title: title,
                    deadline: deadline,
                    assigneeId: assigneeId,
                  ),
        ),
      ),
    );
  }

  Future<void> _showInviteDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (_) => InviteMemberDialog(
        projectId: projectId,
        onInvite: ({email, username, required role}) async {
          await ref.read(projectRepositoryProvider).inviteMember(
                projectId,
                email: email,
                username: username,
                role: role,
              );
          ref.invalidate(membersProvider(projectId));
        },
      ),
    );
  }
}

class _TasksTab extends ConsumerStatefulWidget {
  const _TasksTab({required this.projectId});

  final String projectId;

  @override
  ConsumerState<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends ConsumerState<_TasksTab> {
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  @override
  void initState() {
    super.initState();
    ref.read(wsClientProvider).joinProject(widget.projectId);
    _wsSub = ref.read(wsClientProvider).events.listen((msg) {
      if (!mounted) return;
      if (msg['type'] == 'task_updated') {
        ref.invalidate(tasksProvider(widget.projectId));
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider(widget.projectId));
    final s = ref.watch(appStringsProvider);
    return tasks.when(
      loading: () => const SkeletonListView(count: 3),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.task_alt,
            title: s.projectDetailTasksEmptyTitle,
            subtitle: s.projectDetailTasksEmptySubtitle,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: list.length,
          itemBuilder: (context, i) =>
              TaskCard(task: list[i], projectId: widget.projectId),
        );
      },
    );
  }
}

class _NotesTab extends ConsumerStatefulWidget {
  const _NotesTab({required this.projectId});

  final String projectId;

  @override
  ConsumerState<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<_NotesTab> {
  final _controller = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  Timer? _debounce;
  bool _initialized = false;
  // True while we apply a remote update to the controller; suppresses the
  // resulting onChanged so we never echo the same content back to the server
  // (which would otherwise cause a save/broadcast loop).
  bool _applyingRemote = false;

  @override
  void initState() {
    super.initState();
    ref.read(wsClientProvider).joinProject(widget.projectId);
    _wsSub = ref.read(wsClientProvider).events.listen((msg) {
      if (!mounted) return;
      if (msg['type'] == 'note_update' &&
          msg['projectId'] == widget.projectId) {
        final content =
            (msg['note'] as Map<String, dynamic>)['content'] as String;
        if (content != _controller.text) {
          _applyingRemote = true;
          _controller.text = content;
          _applyingRemote = false;
        }
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _wsSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (_applyingRemote) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(notesProvider(widget.projectId).notifier).save(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final note = ref.watch(notesProvider(widget.projectId));
    return note.when(
      loading: () => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            5,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SkeletonBox(
                width: i.isEven ? double.infinity : 260,
                height: 13,
              ),
            ),
          ),
        ),
      ),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (n) {
        if (!_initialized) {
          _initialized = true;
          if (n != null && n.content.isNotEmpty) {
            _applyingRemote = true;
            _controller.text = n.content;
            _applyingRemote = false;
          }
        }
        final s = ref.watch(appStringsProvider);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _controller,
            onChanged: _onChanged,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText: s.projectDetailNotesHint,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        );
      },
    );
  }
}

class _MembersTab extends ConsumerWidget {
  const _MembersTab({required this.projectId});

  final String projectId;

  Map<String, String> _roleLabels(AppStrings s) => {
        'lead': s.roleLead,
        'member': s.roleMember,
        'observer': s.roleObserver,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider(projectId));
    final s = ref.watch(appStringsProvider);
    final roleLabels = _roleLabels(s);
    return members.when(
      loading: () => const SkeletonListView(count: 3, hasLeading: true),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.group_outlined,
            title: s.projectDetailMembersEmptyTitle,
            subtitle: s.projectDetailMembersEmptySubtitle,
          );
        }
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final m = list[index];
            return ListTile(
              leading: const Icon(Icons.person),
              title: Text(m.name),
              subtitle: Text(m.email),
              trailing: DropdownButton<String>(
                value: roleLabels.containsKey(m.role) ? m.role : 'member',
                underline: const SizedBox.shrink(),
                items: roleLabels.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: (newRole) {
                  if (newRole == null || newRole == m.role) return;
                  ref
                      .read(projectRepositoryProvider)
                      .updateMemberRole(projectId, m.id, newRole)
                      .then((_) => ref.invalidate(membersProvider(projectId)));
                },
              ),
            );
          },
        );
      },
    );
  }
}
