import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riff/models/instrumento.dart';
import 'package:riff/models/nivel.dart';
import 'package:riff/models/pista.dart';
import 'package:riff/screens/game_screen.dart';
import 'package:riff/widgets/liquid_glass/pistas_dialog.dart';

void main() {
  final nivel = Nivel(
    id: 'facil-01',
    numero: 1,
    dificultad: Dificultad.facil,
    cancionId: 'cancion-001',
    cancionTitulo: 'Canción misteriosa',
    instrumentos: [
      for (final type in TipoInstrumento.values)
        Instrumento(tipo: type, precio: 0, audioUrl: ''),
    ],
  );

  Future<void> abrir(
    WidgetTester tester, {
    bool offline = false,
    bool pistas = true,
  }) async {
    tester.view.physicalSize = const Size(393, 851);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: GameScreen(
            nivel: nivel,
            gameId: 'partida-1',
            offlineMode: offline,
            pistas: pistas,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('con conexión, el botón abre las cinco pistas sin desbordarse', (
    tester,
  ) async {
    await abrir(tester);
    await tester.tap(find.byIcon(Icons.lightbulb_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PistasDialog), findsOneWidget);
    for (final tipo in TipoPista.values) {
      expect(find.text(tipo.titulo), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin conexión las pistas no se pueden pedir', (tester) async {
    await abrir(tester, offline: true);
    await tester.tap(find.byIcon(Icons.lightbulb_rounded));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PistasDialog), findsNothing);
  });

  testWidgets('en las salas no hay botón de pistas', (tester) async {
    await abrir(tester, pistas: false);

    expect(find.byIcon(Icons.lightbulb_rounded), findsNothing);
  });
}
