import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riff/animations/transicion_musical.dart';

void main() {
  Widget pantalla(int pestana) => MaterialApp(
    home: TransicionMusical(
      child: Text('Pestaña $pestana', key: ValueKey(pestana)),
    ),
  );

  // Opacidad con la que se ve [texto] ahora mismo.
  double opacidad(WidgetTester tester, String texto) => tester
      .widget<FadeTransition>(
        find
            .ancestor(
              of: find.text(texto),
              matching: find.byType(FadeTransition),
            )
            .first,
      )
      .opacity
      .value;

  testWidgets('fundido cruzado: la que sale se va antes de que entre la otra', (
    tester,
  ) async {
    await tester.pumpWidget(pantalla(0));
    await tester.pumpWidget(pantalla(1));
    // Al 30 %: la vieja ya casi se fue y la nueva todavía no aparece.
    await tester.pump(const Duration(milliseconds: 105));
    expect(opacidad(tester, 'Pestaña 1'), 0);
    expect(opacidad(tester, 'Pestaña 0'), lessThan(0.3));

    await tester.pumpAndSettle();
    expect(find.text('Pestaña 0'), findsNothing);
    expect(opacidad(tester, 'Pestaña 1'), 1);
    expect(tester.takeException(), isNull);
  });
}
