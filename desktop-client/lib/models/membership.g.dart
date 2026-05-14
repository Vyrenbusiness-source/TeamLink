// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: unnecessary_null_checks

part of 'membership.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Membership _$MembershipFromJson(Map<String, dynamic> json) => _Membership(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      projectId: json['project_id'] as String,
      role: $enumDecode(_$MembershipRoleEnumMap, json['role']),
      joinedAt: (json['joined_at'] as num).toInt(),
      updatedAt: (json['updated_at'] as num).toInt(),
      invitedBy: json['invited_by'] as String?,
    );

Map<String, dynamic> _$MembershipToJson(_Membership instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'project_id': instance.projectId,
      'role': _$MembershipRoleEnumMap[instance.role]!,
      'joined_at': instance.joinedAt,
      'updated_at': instance.updatedAt,
      'invited_by': instance.invitedBy,
    };

const _$MembershipRoleEnumMap = {
  MembershipRole.lead: 'lead',
  MembershipRole.member: 'member',
  MembershipRole.observer: 'observer',
};
