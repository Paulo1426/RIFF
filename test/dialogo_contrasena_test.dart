import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riff/widgets/dialogo_contrasena.dart';

void main() {
  testWidgets('devuelve la contraseña y se cierra sin errores', (tester) async {
    String? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => resultado = await showDialog<String>(
              context: context,
              builder: (_) => const DialogoContrasena(accion: 'Reiniciar'),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'secreta');
    await tester.tap(find.text('Reiniciar'));
    // Toda la animación de cierre: el campo no debe liberarse antes.
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(resultado, 'secreta');
    expect(find.byType(DialogoContrasena), findsNothing);
  });

  testWidgets('sin escribir nada no confirma', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DialogoContrasena(accion: 'Reiniciar')),
      ),
    );
    await tester.tap(find.text('Reiniciar'));
    await tester.pump();
    expect(find.byType(DialogoContrasena), findsOneWidget);
  });
}
