import 'package:desktop_client/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TeamLinkApp renders without crashing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: TeamLinkApp()),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
