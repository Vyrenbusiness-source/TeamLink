// ignore_for_file: lines_longer_than_80_chars

import 'package:desktop_client/features/projects/widgets/task_card.dart';
import 'package:desktop_client/l10n/app_locale.dart';
import 'package:desktop_client/models/task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeLocaleNotifier extends LocaleNotifier {
  @override
  Locale build() => const Locale('de');
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _wrapCard(Task task, {String projectId = 'proj-1'}) {
  return ProviderScope(
    overrides: [
      localeProvider.overrideWith(_FakeLocaleNotifier.new),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: TaskCard(task: task, projectId: projectId),
      ),
    ),
  );
}

Task _task({
  String id = 't1',
  String title = 'Test-Aufgabe',
  TaskStatus status = TaskStatus.open,
  int? deadline,
  String? assigneeId,
}) =>
    Task(
      id: id,
      projectId: 'proj-1',
      title: title,
      status: status,
      createdAt: 1_000_000,
      updatedAt: 1_000_000,
      deadline: deadline,
      assigneeId: assigneeId,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TaskCard', () {
    testWidgets('zeigt Aufgabentitel', (tester) async {
      await tester.pumpWidget(_wrapCard(_task(title: 'Meine Aufgabe')));
      await tester.pump();

      expect(find.text('Meine Aufgabe'), findsOneWidget);
    });

    testWidgets('zeigt "Offen"-Chip für offene Aufgabe', (tester) async {
      await tester.pumpWidget(_wrapCard(_task(status: TaskStatus.open)));
      await tester.pump();

      expect(find.text('Offen'), findsOneWidget);
    });

    testWidgets('zeigt "Übernommen"-Chip für übernommene Aufgabe', (tester) async {
      await tester.pumpWidget(_wrapCard(_task(status: TaskStatus.taken)));
      await tester.pump();

      expect(find.text('Übernommen'), findsOneWidget);
    });

    testWidgets('zeigt "Erledigt"-Chip für erledigte Aufgabe', (tester) async {
      await tester.pumpWidget(_wrapCard(_task(status: TaskStatus.done)));
      await tester.pump();

      expect(find.text('Erledigt'), findsOneWidget);
    });

    testWidgets('zeigt "Übernehmen"-Button für offene Aufgabe', (tester) async {
      await tester.pumpWidget(_wrapCard(_task(status: TaskStatus.open)));
      await tester.pump();

      expect(find.text('Übernehmen'), findsOneWidget);
    });

    testWidgets('zeigt "Erledigen"-Button für übernommene Aufgabe', (tester) async {
      await tester.pumpWidget(_wrapCard(_task(status: TaskStatus.taken)));
      await tester.pump();

      expect(find.text('Erledigen'), findsOneWidget);
    });

    testWidgets('kein Aktionsbutton für erledigte Aufgabe', (tester) async {
      await tester.pumpWidget(_wrapCard(_task(status: TaskStatus.done)));
      await tester.pump();

      expect(find.text('Übernehmen'), findsNothing);
      expect(find.text('Erledigen'), findsNothing);
    });

    testWidgets('zeigt "Überfällig" für vergangene Deadline', (tester) async {
      // Unix-Timestamp aus 1970 – eindeutig überfällig
      await tester.pumpWidget(_wrapCard(_task(deadline: 1000)));
      await tester.pump();

      expect(find.text('Überfällig'), findsOneWidget);
    });

    testWidgets('zeigt Datum für weit zukünftige Deadline', (tester) async {
      final future =
          DateTime(2099, 6, 15).millisecondsSinceEpoch ~/ 1000;
      await tester.pumpWidget(_wrapCard(_task(deadline: future)));
      await tester.pump();

      // Datum im Format TT.MM.JJJJ — Jahr muss enthalten sein
      expect(find.textContaining('2099'), findsOneWidget);
    });

    testWidgets('zeigt Uhr-Icon neben Deadline', (tester) async {
      final future =
          DateTime(2099, 1, 1).millisecondsSinceEpoch ~/ 1000;
      await tester.pumpWidget(_wrapCard(_task(deadline: future)));
      await tester.pump();

      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });
  });
}
