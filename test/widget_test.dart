import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flipbook_app/screens/welcome_screen.dart';

void main() {
  testWidgets("WelcomeScreen affiche le titre et les boutons d'authentification",
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));

    expect(find.text('Flipbook'), findsOneWidget);
    expect(find.text("S'inscrire"), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });
}
