// ignore_for_file: public_member_api_docs

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_database.g.dart';

@DataClassName('CachedProject')
class ProjectsTable extends Table {
  @override
  String get tableName => 'projects';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get ownerId => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get description => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CachedTask')
class TasksTable extends Table {
  @override
  String get tableName => 'tasks';

  TextColumn get id => text()();
  TextColumn get projectId => text()();
  TextColumn get title => text()();
  TextColumn get status => text()(); // 'open'|'taken'|'done'
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get description => text().nullable()();
  // 'low'|'medium'|'high'|'urgent'
  TextColumn get priority => text().nullable()();
  TextColumn get assigneeId => text().nullable()();
  IntColumn get deadline => integer().nullable()();
  TextColumn get updatedBy => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [ProjectsTable, TasksTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'teamlink_cache');
  }

  // ── Projects ─────────────────────────────────────────────────────────────

  Future<List<CachedProject>> getAllProjects() =>
      select(projectsTable).get();

  Future<void> upsertProject(ProjectsTableCompanion row) =>
      into(projectsTable).insertOnConflictUpdate(row);

  Future<void> upsertProjects(List<ProjectsTableCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(projectsTable, rows));

  Future<void> deleteProject(String id) =>
      (delete(projectsTable)..where((t) => t.id.equals(id))).go();

  // ── Tasks ─────────────────────────────────────────────────────────────────

  Future<List<CachedTask>> getTasksForProject(String projectId) =>
      (select(tasksTable)..where((t) => t.projectId.equals(projectId))).get();

  Future<void> upsertTask(TasksTableCompanion row) =>
      into(tasksTable).insertOnConflictUpdate(row);

  Future<void> upsertTasks(List<TasksTableCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(tasksTable, rows));

  Future<void> deleteTask(String id) =>
      (delete(tasksTable)..where((t) => t.id.equals(id))).go();
}

final appDatabaseProvider = Provider<AppDatabase>((_) => AppDatabase());
