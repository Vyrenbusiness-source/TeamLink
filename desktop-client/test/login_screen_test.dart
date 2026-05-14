// ignore_for_file: lines_longer_than_80_chars

import 'package:desktop_client/features/auth/login_screen.dart';
import 'package:desktop_client/l10n/app_locale.dart';
import 'package:desktop_client/models/user.dart';
import 'package:desktop_client/providers/auth_provider.dart';
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

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<User?> build() async => null;

  @override
  Future<void> login(String email, String password) async {}
}

class _FailingAuthNotifier extends AuthNotifier {
  @override
  Future<User?> build() async => null;

  @override
  Future<void> login(String email, String password) async {
    throw Exception('Ungültige Anmeldedaten');
  }
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _wrap({bool failLogin = false}) {
  return ProviderScope(
    overrides: [
      localeProvider.overrideWith(_FakeLocaleNotifier.new),
      authProvider.overrideWith(
        failLogin ? _FailingAuthNotifier.new : _FakeAuthNotifier.new,
      ),
    ],
    child: const MaterialApp(home: LoginScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('LoginScreen', () {
    testWidgets('zeigt E-Mail- und Passwort-Felder', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      expect(find.text('E-Mail'), findsOneWidget);
      expect(find.text('Passwort'), findsOneWidget);
    });

    testWidgets('zeigt TeamLink-Titel und Anmelden-Überschrift', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      expect(find.text('TeamLink'), findsOneWidget);
      expect(find.text('Anmelden'), findsWidgets);
    });

    testWidgets('zeigt Validierungsfehler bei leerem E-Mail-Feld', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
      await tester.pump();

      expect(find.text('E-Mail eingeben'), findsOneWidget);
    });

    testWidgets('zeigt Validierungsfehler bei ungültiger E-Mail', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.enterText(
        find.byType(TextFormField).first,
        'kein-at-zeichen',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
      await tester.pump();

      expect(find.text('Ungültige E-Mail'), findsOneWidget);
    });

    testWidgets('zeigt Validierungsfehler bei leerem Passwort', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.enterText(
        find.byType(TextFormField).first,
        'user@test.de',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
      await tester.pump();

      expect(find.text('Passwort eingeben'), findsOneWidget);
    });

    testWidgets('Passwort-Sichtbarkeits-Toggle wechselt Icon', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('zeigt Fehler-Banner bei fehlgeschlagenem Login', (tester) async {
      await tester.pumpWidget(_wrap(failLogin: true));
      await tester.pump();

      await tester.enterText(
        find.byType(TextFormField).first,
        'user@test.de',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'passwort123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('zeigt Registrierungs-Link', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      expect(find.text('Noch kein Konto? Registrieren'), findsOneWidget);
    });
  });
}
