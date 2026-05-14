// GENERATED — do not edit by hand. Run: node shared-models/generate.js
// ignore_for_file: lines_longer_than_80_chars, public_member_api_docs

import 'package:freezed_annotation/freezed_annotation.dart';

part 'membership.freezed.dart';
part 'membership.g.dart';

@JsonEnum()
enum MembershipRole {
  lead,
  member,
  observer,
}

@freezed
abstract class Membership with _$Membership {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Membership({
    required String id,
    required String userId,
    required String projectId,
    required MembershipRole role,
    required int joinedAt,
    required int updatedAt,
    String? invitedBy,
  }) = _Membership;

  factory Membership.fromJson(Map<String, dynamic> json) =>
      _$MembershipFromJson(json);
}
