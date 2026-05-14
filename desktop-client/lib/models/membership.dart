// GENERATED — do not edit by hand. Run: node shared-models/generate.js
// ignore_for_file: lines_longer_than_80_chars, public_member_api_docs

enum MembershipRole { lead, member, observer }

class Membership {
  const Membership({
    required this.userId,
    required this.projectId,
    required this.role,
  });

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
    userId: json['user_id'] as String,
    projectId: json['project_id'] as String,
    role: MembershipRole.values.firstWhere((e) => e.name == json['role'] as String),
  );

  final String userId;
  final String projectId;
  final MembershipRole role;

  Map<String, dynamic> toJson() => <String, dynamic>{
      'user_id': userId,
      'project_id': projectId,
      'role': role.name,
  };
}
