// ignore_for_file: public_member_api_docs

import 'package:desktop_client/features/projects/project_providers.dart';
import 'package:desktop_client/l10n/app_strings.dart';
import 'package:desktop_client/models/task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class QuickSearchOverlay extends ConsumerStatefulWidget {
  const QuickSearchOverlay({super.key});

  @override
  ConsumerState<QuickSearchOverlay> createState() =>
      _QuickSearchOverlayState();
}

class _QuickSearchOverlayState extends ConsumerState<QuickSearchOverlay> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider).valueOrNull ?? [];
    final tasks = ref.watch(allTasksProvider).valueOrNull ?? <Task>[];
    final s = ref.watch(appStringsProvider);

    final q = _query.toLowerCase();
    final filteredProjects = q.isEmpty
        ? projects
        : projects.where((p) => p.name.toLowerCase().contains(q)).toList();
    final filteredTasks = q.isEmpty
        ? <Task>[]
        : tasks.where((t) => t.title.toLowerCase().contains(q)).toList();
    final projectMap = {for (final p in projects) p.id: p.name};

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 480),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: s.quickSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() {
                            _ctrl.clear();
                            _query = '';
                          }),
                        )
                      : null,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  if (filteredProjects.isNotEmpty) ...[
                    _SectionLabel(label: s.quickSearchSectionProjects),
                    ...filteredProjects.map(
                      (p) => ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(p.name),
                        onTap: () {
                          Navigator.of(context).pop();
                          context.go('/projects/${p.id}', extra: p.name);
                        },
                      ),
                    ),
                  ],
                  if (filteredTasks.isNotEmpty) ...[
                    _SectionLabel(label: s.quickSearchSectionTasks),
                    ...filteredTasks.map(
                      (t) => ListTile(
                        leading: const Icon(Icons.task_alt),
                        title: Text(t.title),
                        subtitle:
                            Text(projectMap[t.projectId] ?? t.projectId),
                        onTap: () {
                          Navigator.of(context).pop();
                          context.go(
                            '/projects/${t.projectId}',
                            extra: projectMap[t.projectId] ?? t.projectId,
                          );
                        },
                      ),
                    ),
                  ],
                  if (filteredProjects.isEmpty &&
                      filteredTasks.isEmpty &&
                      _query.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text(s.quickSearchNoResults)),
                    ),
                  if (_query.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text(s.quickSearchPlaceholder)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
      ),
    );
  }
}
