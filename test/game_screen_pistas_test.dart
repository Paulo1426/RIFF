import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riff/models/instrumento.dart';
import 'package:riff/models/nivel.dart';
import 'package:riff/screens/game_screen.dart';
import 'package:riff/services/offline_game_store.dart';
import 'package:riff/widgets/liquid_glass/pistas_dialog.dart';

void main() {
  final nivel = Nivel(
    id: 'facil-01',
    numero: 1,
    dificultad: Dificultad.facil,
    cancionId: 'cancion-001',
    cancionTitulo: 'La gota fria',
    instrumentos: [
      for (final type in TipoInstrumento.values)
        Instrumento(tipo: type, precio: 0, audioUrl: ''),
    ],
  );

  testWidgets('hint button is visible and opens PistasDialog', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: GameScreen(
            nivel: nivel,
            gameId: 'test-game-1',
            offlineMode: true,
            offlineLevel: OfflineLevelData(
              nivel: nivel,
              completado: false,
              puedeIniciar: true,
              respuesta: 'la gota fria',
              artista: 'Carlos Vives',
              audioPaths: const {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify hint icon button is in the app bar
    final hintButton = find.byIcon(Icons.lightbulb_rounded);
    expect(hintButton, findsOneWidget);

    // Tap hint button
    await tester.tap(hintButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify PistasDialog opened
    expect(find.byType(PistasDialog), findsOneWidget);
    expect(find.text('Pistas y Comodines'), findsOneWidget);
    expect(find.text('Nombre del Artista'), findsOneWidget);
    expect(find.text('Iniciales del Título'), findsOneWidget);
    expect(find.text('4to Instrumento'), findsOneWidget);
  });
}
