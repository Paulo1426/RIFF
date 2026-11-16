import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riff/models/instrumento.dart';
import 'package:riff/models/nivel.dart';
import 'package:riff/screens/game_screen.dart';
import 'package:riff/screens/home_screen.dart';
import 'package:riff/screens/instrucciones_dialog.dart';
import 'package:riff/widgets/reproductor_cancion.dart';

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
      // El botón de comprobar solo aparece al escribir una respuesta.
      expect(find.text('Comprobar respuesta'), findsNothing);
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump(const Duration(milliseconds: 300));
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
      final confeti = ConfettiController();
      addTearDown(confeti.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: tamano,
              textScaler: TextScaler.linear(escalaTexto),
            ),
            child: Scaffold(
              body: ReproductorCancion(
                color: Colors.orange,
                titulo: 'Cancion',
                artista: 'Artista',
                insignia: '¡ADIVINASTE! · NIVEL 1',
                portada: null,
                reproduciendo: false,
                enPausa: false,
                posicion: () => Duration.zero,
                duracion: () => Duration.zero,
                onReproducirPausar: () {},
                onDesdeInicio: () {},
                onDetener: null,
                onBuscar: null,
                confeti: confeti,
                botones: const Text('Terminar nivel'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Cancion'), findsOneWidget);
      expect(find.byTooltip('Reproducir'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
