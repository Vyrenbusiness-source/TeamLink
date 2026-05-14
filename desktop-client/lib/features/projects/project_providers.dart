// ignore_for_file: public_member_api_docs

import 'package:desktop_client/features/projects/project_repository.dart';
import 'package:desktop_client/models/project.dart';
import 'package:desktop_client/models/task.dart';
import 'package:desktop_client/services/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(ref.watch(apiClientProvider)),
);

class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() {
    return ref.read(projectRepositoryProvider).listProjects();
  }

  Future<Project> create(String name) async {
    final project =
        await ref.read(projectRepositoryProvider).createProject(name);
    state = AsyncData([project, ...state.valueOrNull ?? const []]);
    return project;
  }
}

final projectsProvider =
    AsyncNotifierProvider<ProjectsNotifier, List<Project>>(
  ProjectsNotifier.new,
);

final membersProvider =
    FutureProvider.family<List<MemberDetail>, String>(
  (ref, projectId) =>
      ref.read(projectRepositoryProvider).listMembers(projectId),
);

class TasksNotifier extends FamilyAsyncNotifier<List<Task>, String> {
  @override
  Future<List<Task>> build(String arg) async {
    final data = await ref.read(apiClientProvider).getTasks(arg);
    return data.cast<Map<String, dynamic>>().map(Task.fromJson).toList();
  }

  Future<void> takeTask(String taskId, String userId) async {
    final data = await ref.read(apiClientProvider).updateTask(
      projectId: arg,
      taskId: taskId,
      assigneeId: userId,
      status: 'taken',
    );
    _replace(Task.fromJson(data));
  }

  Future<void> markDone(String taskId) async {
    final data = await ref.read(apiClientProvider).updateTask(
      projectId: arg,
      taskId: taskId,
      status: 'done',
    );
    _replace(Task.fromJson(data));
  }

  Future<void> create({
    required String title,
    int? deadline,
    String? assigneeId,
  }) async {
    final data = await ref.read(apiClientProvider).createTask(
      projectId: arg,
      title: title,
      deadline: deadline,
      assigneeId: assigneeId,
    );
    final task = Task.fromJson(data);
    state = AsyncData([...state.valueOrNull ?? [], task]);
  }

  void _replace(Task updated) {
    state = AsyncData(
      state.valueOrNull
              ?.map((t) => t.id == updated.id ? updated : t)
              .toList() ??
          [],
    );
  }
}

final tasksProvider =
    AsyncNotifierProvider.family<TasksNotifier, List<Task>, String>(
  TasksNotifier.new,
);

final allTasksProvider = FutureProvider<List<Task>>((ref) async {
  final projects = await ref.watch(projectsProvider.future);
  final client = ref.read(apiClientProvider);
  final results = await Future.wait(projects.map((p) => client.getTasks(p.id)));
  return results
      .expand(
        (list) => list.cast<Map<String, dynamic>>().map(Task.fromJson),
      )
      .toList();
});
