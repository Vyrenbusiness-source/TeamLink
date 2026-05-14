// GENERATED — do not edit by hand. Run: node shared-models/generate.js
// ignore_for_file: lines_longer_than_80_chars, public_member_api_docs

enum ProjectMemberRole { lead, member, observer }

class ProjectMember {
  const ProjectMember({
    required this.userId,
    required this.role,
  });

  factory ProjectMember.fromJson(Map<String, dynamic> json) => ProjectMember(
    userId: json['user_id'] as String,
    role: ProjectMemberRole.values.firstWhere((e) => e.name == json['role'] as String),
  );

  final String userId;
  final ProjectMemberRole role;

  Map<String, dynamic> toJson() => <String, dynamic>{
      'user_id': userId,
      'role': role.name,
  };
}

class Project {
  const Project({
    required this.id,
    required this.name,
    this.createdAt,
    this.members,
  });

  factory Project.fromJson(Map<String, dynamic> json) => Project(
    id: json['id'] as String,
    name: json['name'] as String,
    createdAt: json['created_at'] as int?,
    members: (json['members'] as List<dynamic>?)?.map((e) => ProjectMember.fromJson(e as Map<String, dynamic>)).toList(),
  );

  final String id;
  final String name;
  final int? createdAt;
  final List<ProjectMember>? members;

  Map<String, dynamic> toJson() => <String, dynamic>{
      'id': id,
      'name': name,
      'created_at': createdAt,
      'members': members?.map((e) => e.toJson()).toList(),
  };
}
