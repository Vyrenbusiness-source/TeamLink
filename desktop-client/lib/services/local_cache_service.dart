// ignore_for_file: public_member_api_docs

import 'package:desktop_client/models/project.dart';
import 'package:desktop_client/models/task.dart';
import 'package:desktop_client/services/app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocalCacheService {
  const LocalCacheService(this._db);

  final AppDatabase _db;

  // ── Projects ─────────────────────────────────────────────────────────────

  Future<List<Project>> getProjects() async {
    final rows = await _db.getAllProjects();
    return rows.map(_projectFromRow).toList();
  }

  Future<void> saveProjects(List<Project> projects) =>
      _db.upsertProjects(projects.map(_projectToCompanion).toList());

  Future<void> saveProject(Project project) =>
      _db.upsertProject(_projectToCompanion(project));

  Future<void> removeProject(String id) => _db.deleteProject(id);

  // ── Tasks ─────────────────────────────────────────────────────────────────

  Future<List<Task>> getTasksForProject(String projectId) async {
    final rows = await _db.getTasksForProject(projectId);
    return rows.map(_taskFromRow).toList();
  }

  Future<void> saveTasks(List<Task> tasks) =>
      _db.upsertTasks(tasks.map(_taskToCompanion).toList());

  Future<void> saveTask(Task task) =>
      _db.upsertTask(_taskToCompanion(task));

  Future<void> removeTask(String id) => _db.deleteTask(id);

  // ── Mappers ───────────────────────────────────────────────────────────────

  static Project _projectFromRow(CachedProject row) => Project(
        id: row.id,
        name: row.name,
        ownerId: row.ownerId,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        description: row.description,
      );

  static ProjectsTableCompanion _projectToCompanion(Project p) =>
      ProjectsTableCompanion(
        id: Value(p.id),
        name: Value(p.name),
        ownerId: Value(p.ownerId),
        createdAt: Value(p.createdAt),
        updatedAt: Value(p.updatedAt),
        description: Value(p.description),
      );

  static Task _taskFromRow(CachedTask row) => Task(
        id: row.id,
        projectId: row.projectId,
        title: row.title,
        status: TaskStatus.values.byName(row.status),
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        description: row.description,
        priority: row.priority != null
            ? TaskPriority.values.byName(row.priority!)
            : null,
        assigneeId: row.assigneeId,
        deadline: row.deadline,
        updatedBy: row.updatedBy,
      );

  static TasksTableCompanion _taskToCompanion(Task t) => TasksTableCompanion(
        id: Value(t.id),
        projectId: Value(t.projectId),
        title: Value(t.title),
        status: Value(t.status.name),
        createdAt: Value(t.createdAt),
        updatedAt: Value(t.updatedAt),
        description: Value(t.description),
        priority: Value(t.priority?.name),
        assigneeId: Value(t.assigneeId),
        deadline: Value(t.deadline),
        updatedBy: Value(t.updatedBy),
      );
}

final localCacheServiceProvider = Provider<LocalCacheService>(
  (ref) => LocalCacheService(ref.watch(appDatabaseProvider)),
);
