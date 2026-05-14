// GENERATED — do not edit by hand. Run: node shared-models/generate.js
// ignore_for_file: lines_longer_than_80_chars, public_member_api_docs

import 'package:freezed_annotation/freezed_annotation.dart';

part 'note.freezed.dart';
part 'note.g.dart';

@freezed
abstract class Note with _$Note {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Note({
    required String id,
    required String projectId,
    required String content,
    required String createdBy,
    required int createdAt,
    required int updatedAt,
    String? title,
    String? updatedBy,
  }) = _Note;

  factory Note.fromJson(Map<String, dynamic> json) =>
      _$NoteFromJson(json);
}
