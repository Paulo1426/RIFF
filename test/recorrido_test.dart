import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riff/widgets/recorrido.dart';

void main() {
  final uno = GlobalKey();
  final dos = GlobalKey();
  final pasos = [
    PasoRecorrido(clave: uno, titulo: 'Primero', texto: 'Explica uno'),
    PasoRecorrido(clave: dos, titulo: 'Segundo', texto: 'Explica dos'),
  ];

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                SizedBox(key: uno, height: 50, width: 50),
                SizedBox(key: dos, height: 50, width: 50),
                TextButton(
                  onPressed: () => mostrarRecorrido(context, pasos),
                  child: const Text('Abrir'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('avanza paso a paso y termina con Listo', (tester) async {
    await abrir(tester);
    expect(find.text('Primero'), findsOneWidget);
    expect(find.text('1 de 2'), findsOneWidget);
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Segundo'), findsOneWidget);
    expect(find.text('Omitir'), findsNothing);
    await tester.tap(find.text('¡Listo!'));
    await tester.pumpAndSettle();
    expect(find.text('Segundo'), findsNothing);
  });

  testWidgets('con un elemento que ocupa toda la pantalla la burbuja se ve', (
    tester,
  ) async {
    final grande = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => mostrarRecorrido(context, [
                PasoRecorrido(clave: grande, titulo: 'Panel', texto: 'Todo'),
              ]),
              child: SizedBox.expand(key: grande),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(grande));
    await tester.pumpAndSettle();
    final caja = tester.getRect(find.text('Panel'));
    final pantalla = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(caja.top, greaterThanOrEqualTo(0));
    expect(caja.bottom, lessThanOrEqualTo(pantalla.height));
  });

  testWidgets('Omitir cierra el recorrido', (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Omitir'));
    await tester.pumpAndSettle();
    expect(find.text('Primero'), findsNothing);
  });
}
