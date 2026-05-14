// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: unnecessary_null_checks

part of 'note.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Note _$NoteFromJson(Map<String, dynamic> json) => _Note(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      content: json['content'] as String,
      createdBy: json['created_by'] as String,
      createdAt: (json['created_at'] as num).toInt(),
      updatedAt: (json['updated_at'] as num).toInt(),
      title: json['title'] as String?,
      updatedBy: json['updated_by'] as String?,
    );

Map<String, dynamic> _$NoteToJson(_Note instance) => <String, dynamic>{
      'id': instance.id,
      'project_id': instance.projectId,
      'content': instance.content,
      'created_by': instance.createdBy,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'title': instance.title,
      'updated_by': instance.updatedBy,
    };
