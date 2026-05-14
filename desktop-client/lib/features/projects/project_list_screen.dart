// ignore_for_file: public_member_api_docs

import 'package:desktop_client/features/projects/project_providers.dart';
import 'package:desktop_client/features/projects/widgets/create_project_dialog.dart';
import 'package:desktop_client/l10n/app_strings.dart';
import 'package:desktop_client/shared/widgets/empty_state.dart';
import 'package:desktop_client/shared/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProjectListScreen extends ConsumerWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.projectListTitle)),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(s.projectListNewProject),
      ),
      body: projects.when(
        loading: () => const SkeletonListView(count: 4),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.folder_open_outlined,
                title: s.projectListEmptyTitle,
                subtitle: s.projectListEmptySubtitle,
              )
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final project = list[index];
                  return ListTile(
                    title: Text(project.name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.push('/projects/${project.id}'),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _showCreateDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => CreateProjectDialog(
        onCreate: (name) =>
            ref.read(projectsProvider.notifier).create(name),
      ),
    );
  }
}
