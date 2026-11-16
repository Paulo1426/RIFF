import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riff/animations/logo_animado.dart';

void main() {
  testWidgets('el logo animado se arma en cualquier instante', (tester) async {
    for (final t in [0.0, 0.2, 0.5, 0.8, 1.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: ColoredBox(
            color: const Color(0xFFF5F5F5),
            child: Center(child: LogoAnimado(t: t, ancho: 300)),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('la intro se funde y deja ver la pantalla', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: IntroLogo(child: Text('inicio'))),
    );
    expect(find.byType(LogoAnimado), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2700));
    await tester.pumpAndSettle();
    expect(find.byType(LogoAnimado), findsNothing);
    expect(find.text('inicio'), findsOneWidget);
  });
}
