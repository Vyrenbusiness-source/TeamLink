// GENERATED — do not edit by hand. Run: node shared-models/generate.js
// ignore_for_file: lines_longer_than_80_chars, public_member_api_docs

enum TaskStatus { open, taken, done }

class Task {
  const Task({
    required this.id,
    required this.projectId,
    required this.title,
    required this.status,
    this.deadline,
    this.assigneeId,
    this.createdAt,
    this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as String,
    projectId: json['project_id'] as String,
    title: json['title'] as String,
    status: TaskStatus.values.firstWhere((e) => e.name == json['status'] as String),
    deadline: json['deadline'] as int?,
    assigneeId: json['assignee_id'] as String?,
    createdAt: json['created_at'] as int?,
    updatedAt: json['updated_at'] as int?,
  );

  final String id;
  final String projectId;
  final String title;
  final TaskStatus status;
  final int? deadline;
  final String? assigneeId;
  final int? createdAt;
  final int? updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
      'id': id,
      'project_id': projectId,
      'title': title,
      'status': status.name,
      'deadline': deadline,
      'assignee_id': assigneeId,
      'created_at': createdAt,
      'updated_at': updatedAt,
  };
}
