import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riff/models/pista.dart';
import 'package:riff/widgets/liquid_glass/pista_card.dart';
import 'package:riff/widgets/liquid_glass/pistas_dialog.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets(
    'PistaCard renders locked state with cost and triggers buy callback',
    (tester) async {
      var comprado = false;
      await tester.pumpWidget(
        buildTestableWidget(
          PistaCard(
            tipo: TipoPista.sorpresa,
            saldoMonedas: 5,
            desbloqueada: false,
            onComprar: () => comprado = true,
          ),
        ),
      );

      expect(find.text('Pista sorpresa'), findsOneWidget);
      expect(find.text('Desbloquear (🪙 3)'), findsOneWidget);

      await tester.tap(find.text('Desbloquear (🪙 3)'));
      await tester.pump();

      expect(comprado, isTrue);
    },
  );

  testWidgets('PistaCard disables button when coins are insufficient', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestableWidget(
        const PistaCard(
          tipo: TipoPista.cuartoInstrumento,
          saldoMonedas: 1, // cuesta 5
          desbloqueada: false,
        ),
      ),
    );

    expect(find.text('Faltan monedas (tienes 1)'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('Medley hints use only its own currency', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        const PistaCard(
          tipo: TipoPista.cuartoInstrumento,
          saldoMonedas: 0,
          simboloMoneda: '🎲',
        ),
      ),
    );

    expect(find.text('Faltan monedas (tienes 0)'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('PistaCard displays value when unlocked', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        const PistaCard(
          tipo: TipoPista.iniciales,
          saldoMonedas: 0,
          desbloqueada: true,
          valor: 'L__ c______ d_ l_ v___',
        ),
      ),
    );

    expect(find.text('L__ c______ d_ l_ v___'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
  });

  testWidgets('PistasDialog renders every hint type with user coin balance', (
    tester,
  ) async {
    TipoPista? selectedType;
    await tester.pumpWidget(
      buildTestableWidget(
        PistasDialog(
          saldoMonedas: 7,
          pistasDesbloqueadas: const {TipoPista.artista: 'Diomedes Díaz'},
          onComprarPista: (tipo) => selectedType = tipo,
        ),
      ),
    );

    expect(find.text('Pistas y Comodines'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Pista sorpresa'), findsOneWidget);
    // Las sorpresas que ya salieron se ven en su tarjeta.
    expect(find.text('Artista: Diomedes Díaz'), findsOneWidget);
    expect(find.text('Iniciales del Título'), findsOneWidget);
    expect(find.text('Instrumento faltante'), findsOneWidget);

    // Can purchase initials (puede quedar más abajo).
    await tester.ensureVisible(find.text('Desbloquear (🪙 4)'));
    await tester.pump();
    await tester.tap(find.text('Desbloquear (🪙 4)'));
    await tester.pump();

    expect(selectedType, TipoPista.iniciales);
    await tester.pumpAndSettle();
  });
}
