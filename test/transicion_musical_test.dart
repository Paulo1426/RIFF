import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riff/animations/transicion_musical.dart';

// La onda es el único CustomPaint con el pintor de barras.
final _onda = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter.runtimeType.toString() == '_Barras',
);

void main() {
  Widget pantalla(int pestana, int direccion) => MaterialApp(
    home: TransicionMusical(
      pestana: pestana,
      direccion: direccion,
      color: Colors.green,
      child: Text('Pestaña $pestana', key: ValueKey(pestana)),
    ),
  );

  testWidgets('cambia de pestaña con la onda y termina limpia', (tester) async {
    await tester.pumpWidget(pantalla(0, 0));
    // Al abrir no hay onda.
    expect(_onda, findsNothing);

    await tester.pumpWidget(pantalla(1, 1));
    await tester.pump(const Duration(milliseconds: 200));
    // A mitad: salen las dos pantallas y la onda.
    expect(find.text('Pestaña 0'), findsOneWidget);
    expect(find.text('Pestaña 1'), findsOneWidget);
    expect(_onda, findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Pestaña 0'), findsNothing);
    expect(find.text('Pestaña 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('con reducir animaciones no hay onda', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: pantalla(1, 1),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(_onda, findsNothing);
  });
}
