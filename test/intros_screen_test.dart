import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riff/providers/providers.dart';
import 'package:riff/screens/intros_screen.dart';
import 'package:riff/services/firebase_game_repository.dart';

class _AuthFalsa implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RepositorioFalso extends FirebaseGameRepository {
  _RepositorioFalso() : super(auth: _AuthFalsa());

  // Sin usuario no se toca la copia offline (no hay disco en los tests).
  @override
  String? get uid => null;

  @override
  Future<EstadoIntros> cargarIntros() async => EstadoIntros.fromJson({
    'monedas': 7,
    'monedas_ganadas': 9,
    'restantes': 43,
    'intros': [
      {
        'id': 'cancion-17',
        'numero': 1,
        'estado': 'completada',
        'titulo':
            'Una canción con un título larguísimo que no cabe en la tarjeta',
        'artista': 'Artista',
      },
      {'id': 'cancion-03', 'numero': 2, 'estado': 'desbloqueada'},
    ],
  });
}

void main() {
  test('el color depende del artista principal', () {
    expect(
      colorArtista('Martín Elías y Rolando Ochoa'),
      colorArtista('Martín Elías'),
    );
    expect(colorArtista('Diomedes Díaz'), isNot(colorArtista('Martín Elías')));
  });

  for (final (nombre, tamano, escalaTexto) in [
    ('telefono chico', const Size(320, 568), 1.3),
    ('telefono', const Size(393, 851), 1.0),
    ('tablet', const Size(1024, 1366), 1.0),
  ]) {
    testWidgets('las intros no se desbordan en $nombre', (tester) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseGameRepositoryProvider.overrideWithValue(
              _RepositorioFalso(),
            ),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: tamano,
                textScaler: TextScaler.linear(escalaTexto),
              ),
              child: const IntrosScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('7'), findsOneWidget);
      // La colección agrupa por artista; las sin adivinar van aparte.
      expect(find.text('Por descubrir'), findsOneWidget);
      expect(find.text('1 por adivinar'), findsOneWidget);
      expect(find.text('Artista'), findsOneWidget);
      expect(find.text('1 canción'), findsOneWidget);
      expect(find.textContaining('Quedan 43'), findsOneWidget);
      expect(find.text('Sacar carta · 🪙 1'), findsOneWidget);

      // Al tocar el artista se ven sus cartas, sin desbordes.
      await tester.tap(find.text('Artista'));
      // El fondo líquido se anima sin fin; pumpAndSettle nunca terminaría.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Una canción'), findsOneWidget);
    });
  }
}
