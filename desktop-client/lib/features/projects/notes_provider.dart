// ignore_for_file: public_member_api_docs

import 'package:desktop_client/models/note.dart';
import 'package:desktop_client/services/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotesNotifier extends FamilyAsyncNotifier<Note?, String> {
  @override
  Future<Note?> build(String arg) async {
    final data = await ref.read(apiClientProvider).getNote(arg);
    return Note.fromJson(data);
  }

  Future<void> save(String content) async {
    final data =
        await ref.read(apiClientProvider).updateNote(arg, content);
    state = AsyncData(Note.fromJson(data));
  }
}

final notesProvider =
    AsyncNotifierProvider.family<NotesNotifier, Note?, String>(
  NotesNotifier.new,
);
