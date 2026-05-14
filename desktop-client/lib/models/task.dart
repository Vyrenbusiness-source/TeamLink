// GENERATED — do not edit by hand. Run: node shared-models/generate.js
// ignore_for_file: lines_longer_than_80_chars, public_member_api_docs

import 'package:freezed_annotation/freezed_annotation.dart';

part 'task.freezed.dart';
part 'task.g.dart';

@JsonEnum()
enum TaskStatus {
  open,
  taken,
  done,
}

@JsonEnum()
enum TaskPriority {
  low,
  medium,
  high,
  urgent,
}

@freezed
abstract class Task with _$Task {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Task({
    required String id,
    required String projectId,
    required String title,
    required TaskStatus status,
    required int createdAt,
    required int updatedAt,
    String? description,
    TaskPriority? priority,
    String? assigneeId,
    int? deadline,
    String? updatedBy,
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) =>
      _$TaskFromJson(json);
}
