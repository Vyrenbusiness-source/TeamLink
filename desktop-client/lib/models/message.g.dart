// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: unnecessary_null_checks

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Message _$MessageFromJson(Map<String, dynamic> json) => _Message(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      recipientId: json['recipient_id'] as String,
      content: json['content'] as String,
      createdAt: (json['created_at'] as num).toInt(),
      projectId: json['project_id'] as String?,
      readAt: (json['read_at'] as num?)?.toInt(),
      updatedAt: (json['updated_at'] as num?)?.toInt(),
    );

Map<String, dynamic> _$MessageToJson(_Message instance) => <String, dynamic>{
      'id': instance.id,
      'sender_id': instance.senderId,
      'recipient_id': instance.recipientId,
      'content': instance.content,
      'created_at': instance.createdAt,
      'project_id': instance.projectId,
      'read_at': instance.readAt,
      'updated_at': instance.updatedAt,
    };
