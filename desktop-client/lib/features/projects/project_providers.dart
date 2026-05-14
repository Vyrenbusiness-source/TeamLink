// ignore_for_file: public_member_api_docs

import 'package:desktop_client/features/projects/project_repository.dart';
import 'package:desktop_client/models/project.dart';
import 'package:desktop_client/models/task.dart';
import 'package:desktop_client/services/api_client.dart';
import 'package:desktop_client/services/ws_client.dart';
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

  Future<Project> updateProject(
    String projectId, {
    String? name,
    String? description,
  }) async {
    final project = await ref
        .read(projectRepositoryProvider)
        .updateProject(projectId, name: name, description: description);
    state = AsyncData(
      (state.valueOrNull ?? [])
          .map((p) => p.id == projectId ? project : p)
          .toList(),
    );
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
    final tasks =
        data.cast<Map<String, dynamic>>().map(Task.fromJson).toList();

    // Subscribe to real-time WS events; apply LWW merge for incoming updates.
    final sub =
        ref.read(wsClientProvider).events.listen(_handleWsEvent);
    ref.onDispose(sub.cancel);

    return tasks;
  }

  void _handleWsEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    switch (type) {
      case 'task_created':
        final raw = event['task'];
        if (raw is Map<String, dynamic>) {
          final task = Task.fromJson(raw);
          if (task.projectId != arg) return;
          final current = state.valueOrNull ?? [];
          if (current.any((t) => t.id == task.id)) return;
          state = AsyncData([...current, task]);
        }

      case 'task_updated':
        final raw = event['task'];
        if (raw is Map<String, dynamic>) {
          final task = Task.fromJson(raw);
          if (task.projectId != arg) return;
          _replaceLww(task);
        }

      case 'task_deleted':
        final taskId = event['taskId'] as String?;
        if (taskId == null) return;
        final current = state.valueOrNull;
        if (current == null) return;
        state = AsyncData(current.where((t) => t.id != taskId).toList());
    }
  }

  Future<void> takeTask(String taskId, String userId) async {
    final currentTask = _findById(taskId);
    try {
      final data = await ref.read(apiClientProvider).updateTask(
        projectId: arg,
        taskId: taskId,
        assigneeId: userId,
        status: 'taken',
        updatedAt: currentTask?.updatedAt,
      );
      _replaceLww(Task.fromJson(data));
    } on ApiException catch (e) {
      _handleConflict(e);
      rethrow;
    }
  }

  Future<void> markDone(String taskId) async {
    final currentTask = _findById(taskId);
    try {
      final data = await ref.read(apiClientProvider).updateTask(
        projectId: arg,
        taskId: taskId,
        status: 'done',
        updatedAt: currentTask?.updatedAt,
      );
      _replaceLww(Task.fromJson(data));
    } on ApiException catch (e) {
      _handleConflict(e);
      rethrow;
    }
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

  Future<void> editTask({
    required String taskId,
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    int? deadline,
    bool clearDeadline = false,
    String? assigneeId,
    bool clearAssignee = false,
  }) async {
    final currentTask = _findById(taskId);
    try {
      final data = await ref.read(apiClientProvider).updateTask(
        projectId: arg,
        taskId: taskId,
        title: title,
        description: description,
        status: status?.name,
        priority: priority?.name,
        deadline: deadline,
        clearDeadline: clearDeadline,
        assigneeId: assigneeId,
        clearAssignee: clearAssignee,
        updatedAt: currentTask?.updatedAt,
      );
      _replaceLww(Task.fromJson(data));
    } on ApiException catch (e) {
      _handleConflict(e);
      rethrow;
    }
  }

  Future<void> deleteTask(String taskId) async {
    await ref.read(apiClientProvider).deleteTask(
      projectId: arg,
      taskId: taskId,
    );
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.where((t) => t.id != taskId).toList());
    }
  }

  Task? _findById(String taskId) =>
      state.valueOrNull?.where((t) => t.id == taskId).firstOrNull;

  // LWW merge: only apply incoming update if it is at least as recent as local.
  void _replaceLww(Task updated) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.map((t) {
        if (t.id != updated.id) return t;
        return updated.updatedAt >= t.updatedAt ? updated : t;
      }).toList(),
    );
  }

  // On 409: server has a newer version — apply it (LWW: server wins).
  void _handleConflict(ApiException e) {
    if (e.statusCode != 409) return;
    final raw = e.body?['current'];
    if (raw is Map<String, dynamic>) {
      try {
        _replaceLww(Task.fromJson(raw));
      } catch (_) {
        // malformed payload — discard; WS broadcast will reconcile
      }
    }
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
