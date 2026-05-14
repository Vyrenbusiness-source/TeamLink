// ignore_for_file: public_member_api_docs

import 'package:desktop_client/models/project.dart';
import 'package:desktop_client/services/api_client.dart';

class MemberDetail {
  const MemberDetail({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory MemberDetail.fromJson(Map<String, dynamic> json) => MemberDetail(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
      );

  final String id;
  final String name;
  final String email;
  final String role;
}

class ProjectRepository {
  const ProjectRepository(this._api);

  final ApiClient _api;

  Future<List<Project>> listProjects() async {
    final data = await _api.getProjects();
    return data
        .map((e) => Project.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Project> createProject(String name) async {
    final data = await _api.createProject(name);
    return Project.fromJson(data);
  }

  Future<List<MemberDetail>> listMembers(String projectId) async {
    final data = await _api.getProjectMembers(projectId);
    return data
        .map((e) => MemberDetail.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateMemberRole(
    String projectId,
    String userId,
    String role,
  ) async {
    await _api.updateMemberRole(
      projectId: projectId,
      userId: userId,
      role: role,
    );
  }

  Future<Project> updateProject(
    String projectId, {
    String? name,
    String? description,
  }) async {
    final data = await _api.updateProject(
      projectId,
      name: name,
      description: description,
    );
    return Project.fromJson(data);
  }

  Future<void> inviteMember(
    String projectId, {
    String? email,
    String? username,
    String role = 'member',
  }) async {
    await _api.inviteMember(
      projectId: projectId,
      email: email,
      username: username,
      role: role,
    );
  }
}
