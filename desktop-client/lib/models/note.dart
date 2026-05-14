// GENERATED — do not edit by hand. Run: node shared-models/generate.js
// ignore_for_file: lines_longer_than_80_chars, public_member_api_docs

class Note {
  const Note({
    required this.id,
    required this.projectId,
    required this.content,
    this.updatedAt,
    this.updatedBy,
  });

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'] as String,
    projectId: json['project_id'] as String,
    content: json['content'] as String,
    updatedAt: json['updated_at'] as int?,
    updatedBy: json['updated_by'] as String?,
  );

  final String id;
  final String projectId;
  final String content;
  final int? updatedAt;
  final String? updatedBy;

  Map<String, dynamic> toJson() => <String, dynamic>{
      'id': id,
      'project_id': projectId,
      'content': content,
      'updated_at': updatedAt,
      'updated_by': updatedBy,
  };
}
