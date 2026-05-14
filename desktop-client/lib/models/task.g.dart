// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: unnecessary_null_checks

part of 'task.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Task _$TaskFromJson(Map<String, dynamic> json) => _Task(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      title: json['title'] as String,
      status: $enumDecode(_$TaskStatusEnumMap, json['status']),
      createdAt: (json['created_at'] as num).toInt(),
      updatedAt: (json['updated_at'] as num).toInt(),
      description: json['description'] as String?,
      priority: $enumDecodeNullable(_$TaskPriorityEnumMap, json['priority']),
      assigneeId: json['assignee_id'] as String?,
      deadline: (json['deadline'] as num?)?.toInt(),
      updatedBy: json['updated_by'] as String?,
    );

Map<String, dynamic> _$TaskToJson(_Task instance) => <String, dynamic>{
      'id': instance.id,
      'project_id': instance.projectId,
      'title': instance.title,
      'status': _$TaskStatusEnumMap[instance.status]!,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'description': instance.description,
      'priority': _$TaskPriorityEnumMap[instance.priority],
      'assignee_id': instance.assigneeId,
      'deadline': instance.deadline,
      'updated_by': instance.updatedBy,
    };

const _$TaskStatusEnumMap = {
  TaskStatus.open: 'open',
  TaskStatus.taken: 'taken',
  TaskStatus.done: 'done',
};

const _$TaskPriorityEnumMap = {
  TaskPriority.low: 'low',
  TaskPriority.medium: 'medium',
  TaskPriority.high: 'high',
  TaskPriority.urgent: 'urgent',
};
