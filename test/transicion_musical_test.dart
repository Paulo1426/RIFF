import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riff/animations/desintegrar.dart';
import 'package:riff/animations/transicion_musical.dart';

void main() {
  Widget pantalla(int pestana, int direccion, {bool polvo = false}) =>
      MaterialApp(
        home: TransicionMusical(
          direccion: direccion,
          polvo: polvo,
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
    await tester.pumpWidget(pantalla(0, 0));
    await tester.pumpWidget(pantalla(1, 1));
    // Al 30 %: la vieja ya casi se fue y la nueva todavía no aparece.
    await tester.pump(const Duration(milliseconds: 75));
    expect(opacidad(tester, 'Pestaña 1'), 0);
    expect(opacidad(tester, 'Pestaña 0'), lessThan(0.3));

    await tester.pumpAndSettle();
    expect(find.text('Pestaña 0'), findsNothing);
    expect(opacidad(tester, 'Pestaña 1'), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('solo con polvo la que sale al regresar se deshace', (
    tester,
  ) async {
    bool polvoActivo() => tester
        .widgetList<Desintegrar>(find.byType(Desintegrar))
        .any((d) => d.activo);

    await tester.pumpWidget(pantalla(1, 1));
    await tester.pumpWidget(pantalla(0, -1));
    await tester.pump(const Duration(milliseconds: 50));
    expect(polvoActivo(), isFalse);
    await tester.pumpAndSettle();

    await tester.pumpWidget(pantalla(1, 1, polvo: true));
    await tester.pumpAndSettle();
    await tester.pumpWidget(pantalla(0, -1, polvo: true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(polvoActivo(), isTrue);
    // A mitad siguen las dos: la que sale (polvo) y la que entra.
    expect(find.text('Pestaña 1'), findsOneWidget);
    expect(find.text('Pestaña 0'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Pestaña 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
