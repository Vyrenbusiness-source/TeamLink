// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:desktop_client/features/projects/project_repository.dart';
import 'package:desktop_client/models/project.dart';
import 'package:desktop_client/models/task.dart';
import 'package:desktop_client/services/api_client.dart';
import 'package:desktop_client/services/local_cache_service.dart';
import 'package:desktop_client/services/ws_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(ref.watch(apiClientProvider)),
);

class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() async {
    final cache = ref.read(localCacheServiceProvider);
    final cached = await cache.getProjects();

    if (cached.isNotEmpty) {
      // Return cache immediately; refresh from API in background.
      unawaited(_refreshProjectsFromApi());
      return cached;
    }

    // First launch or empty cache: fetch from API.
    return _fetchAndCacheProjects();
  }

  Future<List<Project>> _fetchAndCacheProjects() async {
    final data = await ref.read(projectRepositoryProvider).listProjects();
    await ref.read(localCacheServiceProvider).saveProjects(data);
    return data;
  }

  Future<void> _refreshProjectsFromApi() async {
    try {
      final data = await ref.read(projectRepositoryProvider).listProjects();
      await ref.read(localCacheServiceProvider).saveProjects(data);
      state = AsyncData(data);
    } catch (_) {
      // Keep cached state on network error.
    }
  }

  Future<Project> create(String name) async {
    final project =
        await ref.read(projectRepositoryProvider).createProject(name);
    await ref.read(localCacheServiceProvider).saveProject(project);
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
    await ref.read(localCacheServiceProvider).saveProject(project);
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
    // Subscribe to real-time WS events before returning.
    final sub = ref.read(wsClientProvider).events.listen(_handleWsEvent);
    ref.onDispose(sub.cancel);

    final cache = ref.read(localCacheServiceProvider);
    final cached = await cache.getTasksForProject(arg);

    if (cached.isNotEmpty) {
      // Return cache immediately; refresh from API in background.
      unawaited(_refreshTasksFromApi(arg));
      return cached;
    }

    return _fetchAndCacheTasks(arg);
  }

  Future<List<Task>> _fetchAndCacheTasks(String projectId) async {
    final data = await ref.read(apiClientProvider).getTasks(projectId);
    final tasks = data.cast<Map<String, dynamic>>().map(Task.fromJson).toList();
    await ref.read(localCacheServiceProvider).saveTasks(tasks);
    return tasks;
  }

  Future<void> _refreshTasksFromApi(String projectId) async {
    try {
      final data = await ref.read(apiClientProvider).getTasks(projectId);
      final tasks =
          data.cast<Map<String, dynamic>>().map(Task.fromJson).toList();
      await ref.read(localCacheServiceProvider).saveTasks(tasks);
      state = AsyncData(tasks);
    } catch (_) {
      // Keep cached state on network error.
    }
  }

  void _handleWsEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    final cache = ref.read(localCacheServiceProvider);
    switch (type) {
      case 'task_created':
        final raw = event['task'];
        if (raw is Map<String, dynamic>) {
          final task = Task.fromJson(raw);
          if (task.projectId != arg) return;
          final current = state.valueOrNull ?? [];
          if (current.any((t) => t.id == task.id)) return;
          state = AsyncData([...current, task]);
          unawaited(cache.saveTask(task));
        }

      case 'task_updated':
        final raw = event['task'];
        if (raw is Map<String, dynamic>) {
          final task = Task.fromJson(raw);
          if (task.projectId != arg) return;
          final winner = _replaceLww(task);
          unawaited(cache.saveTask(winner));
        }

      case 'task_deleted':
        final taskId = event['taskId'] as String?;
        if (taskId == null) return;
        final current = state.valueOrNull;
        if (current == null) return;
        state = AsyncData(current.where((t) => t.id != taskId).toList());
        unawaited(cache.removeTask(taskId));
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
      final winner = _replaceLww(Task.fromJson(data));
      await ref.read(localCacheServiceProvider).saveTask(winner);
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
      final winner = _replaceLww(Task.fromJson(data));
      await ref.read(localCacheServiceProvider).saveTask(winner);
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
    await ref.read(localCacheServiceProvider).saveTask(task);
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
      final winner = _replaceLww(Task.fromJson(data));
      await ref.read(localCacheServiceProvider).saveTask(winner);
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
    await ref.read(localCacheServiceProvider).removeTask(taskId);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.where((t) => t.id != taskId).toList());
    }
  }

  Task? _findById(String taskId) =>
      state.valueOrNull?.where((t) => t.id == taskId).firstOrNull;

  // LWW merge: only apply incoming update if it is at least as recent as local.
  // Returns the winning task (for cache persistence).
  Task _replaceLww(Task updated) {
    final current = state.valueOrNull;
    if (current == null) return updated;
    var winner = updated;
    state = AsyncData(
      current.map((t) {
        if (t.id != updated.id) return t;
        return winner = updated.updatedAt >= t.updatedAt ? updated : t;
      }).toList(),
    );
    return winner;
  }

  // On 409: server has a newer version — apply it (LWW: server wins).
  void _handleConflict(ApiException e) {
    if (e.statusCode != 409) return;
    final raw = e.body?['current'];
    if (raw is Map<String, dynamic>) {
      try {
        final winner = _replaceLww(Task.fromJson(raw));
        unawaited(ref.read(localCacheServiceProvider).saveTask(winner));
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
