// ignore_for_file: lines_longer_than_80_chars

import 'package:desktop_client/features/projects/widgets/create_project_dialog.dart';
import 'package:desktop_client/l10n/app_locale.dart';
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
// Helper – Dialog via showDialog öffnen (wie in Produktion)
// ---------------------------------------------------------------------------

Future<void> _openDialog(
  WidgetTester tester,
  CreateProjectCallback onCreate,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localeProvider.overrideWith(_FakeLocaleNotifier.new)],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: ctx,
                builder: (_) => CreateProjectDialog(onCreate: onCreate),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('open'));
  await tester.pump(); // Dialog rendern
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('CreateProjectDialog', () {
    testWidgets('zeigt Dialog-Titel "Neues Projekt"', (tester) async {
      await _openDialog(tester, (_) async {});

      expect(find.text('Neues Projekt'), findsOneWidget);
    });

    testWidgets('zeigt Projektname-Eingabefeld mit Label', (tester) async {
      await _openDialog(tester, (_) async {});

      expect(find.text('Projektname'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('zeigt Abbrechen- und Erstellen-Button', (tester) async {
      await _openDialog(tester, (_) async {});

      expect(find.widgetWithText(TextButton, 'Abbrechen'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Erstellen'), findsOneWidget);
    });

    testWidgets('zeigt Validierungsfehler bei leerem Namen', (tester) async {
      await _openDialog(tester, (_) async {});

      await tester.tap(find.widgetWithText(FilledButton, 'Erstellen'));
      await tester.pump();

      expect(find.text('Name erforderlich'), findsOneWidget);
    });

    testWidgets('ruft onCreate mit eingegebenem Namen auf', (tester) async {
      String? capturedName;
      await _openDialog(tester, (name) async => capturedName = name);

      await tester.enterText(find.byType(TextFormField), 'Mein Testprojekt');
      await tester.tap(find.widgetWithText(FilledButton, 'Erstellen'));
      await tester.pump();
      await tester.pump();

      expect(capturedName, equals('Mein Testprojekt'));
    });

    testWidgets('zeigt Fehlertext wenn onCreate eine Exception wirft',
        (tester) async {
      await _openDialog(
        tester,
        (_) async => throw Exception('Serverfehler'),
      );

      await tester.enterText(find.byType(TextFormField), 'FehlerProjekt');
      await tester.tap(find.widgetWithText(FilledButton, 'Erstellen'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Serverfehler'), findsOneWidget);
    });
  });
}
