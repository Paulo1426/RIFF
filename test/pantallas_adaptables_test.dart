import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riff/models/instrumento.dart';
import 'package:riff/models/nivel.dart';
import 'package:riff/screens/game_screen.dart';
import 'package:riff/screens/home_screen.dart';
import 'package:riff/screens/instrucciones_dialog.dart';
import 'package:riff/services/offline_game_store.dart';

void main() {
  final nivel = Nivel.generar(
    id: 'nivel-1',
    numero: 1,
    dificultad: Dificultad.facil,
    cancionId: 'cancion-1',
    cancionTitulo: 'Cancion',
    audios: {for (final tipo in TipoInstrumento.values) tipo: 'audio.mp3'},
  );

  // Teléfono chico con letra grande, teléfono normal y tablet.
  for (final (nombre, tamano, escalaTexto) in [
    ('telefono chico', const Size(320, 568), 1.3),
    ('telefono', const Size(393, 851), 1.0),
    ('tablet', const Size(1024, 1366), 1.0),
  ]) {
    testWidgets('el nivel no se desborda en $nombre', (tester) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: tamano,
                textScaler: TextScaler.linear(escalaTexto),
              ),
              child: GameScreen(nivel: nivel, gameId: 'partida-1'),
            ),
          ),
        ),
      );
      await tester.pump();
      // Recorre toda la pantalla: un desborde de layout se reporta como
      // excepción y hace fallar el test.
      await tester.scrollUntilVisible(
        find.text('Comprobar respuesta'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('el login no se desborda en $nombre', (tester) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: tamano,
                textScaler: TextScaler.linear(escalaTexto),
              ),
              child: HomeScreen(authStateChanges: Stream<User?>.value(null)),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('las instrucciones no se desbordan en $nombre', (tester) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: tamano,
              textScaler: TextScaler.linear(escalaTexto),
            ),
            child: const Scaffold(body: InstruccionesDialog()),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('el reproductor al acertar no se desborda en $nombre', (
      tester,
    ) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: tamano,
                textScaler: TextScaler.linear(escalaTexto),
              ),
              // Offline valida la respuesta en el dispositivo, sin backend.
              child: GameScreen(
                nivel: nivel,
                gameId: 'offline-1',
                offlineMode: true,
                onSiguiente: () {},
                offlineLevel: OfflineLevelData(
                  nivel: nivel,
                  completado: false,
                  puedeIniciar: true,
                  respuesta: 'cancion',
                  audioPaths: const {},
                ),
                onOfflineCompleted: (_, _) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Comprobar respuesta'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextField), 'Cancion');
      await tester.tap(find.text('Comprobar respuesta'));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Terminar nivel'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Cancion'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
