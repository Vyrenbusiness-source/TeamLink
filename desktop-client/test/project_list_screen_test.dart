// ignore_for_file: lines_longer_than_80_chars

import 'dart:async';

import 'package:desktop_client/features/projects/project_list_screen.dart';
import 'package:desktop_client/features/projects/project_providers.dart';
import 'package:desktop_client/l10n/app_locale.dart';
import 'package:desktop_client/models/project.dart';
import 'package:desktop_client/shared/widgets/empty_state.dart';
import 'package:desktop_client/shared/widgets/skeleton.dart';
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

/// Bleibt dauerhaft im Loading-Zustand.
class _LoadingProjectsNotifier extends ProjectsNotifier {
  @override
  Future<List<Project>> build() => Completer<List<Project>>().future;
}

class _EmptyProjectsNotifier extends ProjectsNotifier {
  @override
  Future<List<Project>> build() async => [];
}

class _FixedProjectsNotifier extends ProjectsNotifier {
  _FixedProjectsNotifier(this._list);
  final List<Project> _list;

  @override
  Future<List<Project>> build() async => _list;
}

class _ErrorProjectsNotifier extends ProjectsNotifier {
  @override
  Future<List<Project>> build() async => throw Exception('Netzwerkfehler');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(ProjectsNotifier Function() factory) {
  return ProviderScope(
    overrides: [
      localeProvider.overrideWith(_FakeLocaleNotifier.new),
      projectsProvider.overrideWith(factory),
    ],
    child: const MaterialApp(home: ProjectListScreen()),
  );
}

Project _fakeProject(String id, String name) => Project(
      id: id,
      name: name,
      ownerId: 'owner-1',
      createdAt: 0,
      updatedAt: 0,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ProjectListScreen', () {
    testWidgets('zeigt Skeleton-Loader während des Ladens', (tester) async {
      await tester.pumpWidget(_wrap(_LoadingProjectsNotifier.new));
      await tester.pump();

      expect(find.byType(SkeletonListView), findsOneWidget);
    });

    testWidgets('zeigt EmptyState wenn keine Projekte vorhanden', (tester) async {
      await tester.pumpWidget(_wrap(_EmptyProjectsNotifier.new));
      await tester.pump();
      await tester.pump();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Noch keine Projekte'), findsOneWidget);
    });

    testWidgets('zeigt Projektnamen als ListTile', (tester) async {
      final projects = [
        _fakeProject('p1', 'Alpha Projekt'),
        _fakeProject('p2', 'Beta Projekt'),
      ];
      await tester.pumpWidget(_wrap(() => _FixedProjectsNotifier(projects)));
      await tester.pump();
      await tester.pump();

      expect(find.text('Alpha Projekt'), findsOneWidget);
      expect(find.text('Beta Projekt'), findsOneWidget);
    });

    testWidgets('zeigt AppBar-Titel "Projekte"', (tester) async {
      await tester.pumpWidget(_wrap(_EmptyProjectsNotifier.new));
      await tester.pump();
      await tester.pump();

      expect(find.text('Projekte'), findsOneWidget);
    });

    testWidgets('zeigt FAB mit Label "Neues Projekt"', (tester) async {
      await tester.pumpWidget(_wrap(_EmptyProjectsNotifier.new));
      await tester.pump();
      await tester.pump();

      expect(find.text('Neues Projekt'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('zeigt Fehlermeldung bei Provider-Fehler', (tester) async {
      await tester.pumpWidget(_wrap(_ErrorProjectsNotifier.new));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Netzwerkfehler'), findsOneWidget);
    });

    testWidgets(
        'ListTile zeigt chevron_right Icon für jedes Projekt', (tester) async {
      final projects = [_fakeProject('p1', 'Projekt X')];
      await tester.pumpWidget(_wrap(() => _FixedProjectsNotifier(projects)));
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });
}
