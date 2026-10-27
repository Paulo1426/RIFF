import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riff/screens/carrusel_dificultades.dart';

void main() {
  testWidgets('al girar no reconstruye las tarjetas en cada cuadro', (
    tester,
  ) async {
    var construcciones = 0;
    int? cambio;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CarruselGiratorio(
            itemCount: 3,
            onCambio: (index) => cambio = index,
            itemBuilder: (context, index, alFrente) {
              construcciones++;
              return ColoredBox(
                color: Colors.blue,
                child: Text('Tarjeta $index ${alFrente ? 'frente' : ''}'),
              );
            },
          ),
        ),
      ),
    );
    final inicial = construcciones;
    await tester.tap(find.byTooltip('Siguiente'));
    // ~40 cuadros de animación.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(cambio, 1);
    expect(find.text('Tarjeta 1 frente'), findsOneWidget);
    // Una sola reconstrucción (3 tarjetas) al cambiar el frente, no 40.
    expect(construcciones - inicial, lessThanOrEqualTo(6));
  });

  testWidgets('con autoGiro avanza solo de izquierda a derecha', (
    tester,
  ) async {
    final cambios = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CarruselGiratorio(
            itemCount: 3,
            autoGiro: const Duration(seconds: 1),
            onCambio: cambios.add,
            itemBuilder: (context, index, alFrente) =>
                Text('Tarjeta $index ${alFrente ? 'frente' : ''}'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    // De izquierda a derecha: la tarjeta anterior (la última) pasa al frente.
    expect(cambios, [2]);
    expect(find.text('Tarjeta 2 frente'), findsOneWidget);
  });
}
