import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riff/models/genero.dart';
import 'package:riff/widgets/monedas_genero.dart';

void main() {
  test('cada género tiene su cupo de intros y Medley recibe las restantes', () {
    for (final genero in Genero.reales) {
      expect(genero.totalIntros, 30);
    }
    expect(Genero.aleatorio.totalIntros, 75);
  });

  testWidgets('Medley despliega verticalmente monedas por género', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              MonedasGenero(
                genero: Genero.aleatorio,
                saldo: 10,
                saldos: {
                  'vallenato': 2,
                  'reggaeton': 3,
                  'rock_pop': 4,
                  'salsa': 5,
                  'popular': 6,
                  'aleatorio': 10,
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(PopupMenuButton<Genero>));
    await tester.pumpAndSettle();

    for (final genero in Genero.values) {
      expect(find.text(genero.nombre), findsOneWidget);
    }
    expect(find.text('2'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
  });
}
