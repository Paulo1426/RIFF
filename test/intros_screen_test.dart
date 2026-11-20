import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riff/models/genero.dart';
import 'package:riff/providers/providers.dart';
import 'package:riff/screens/intros_screen.dart';
import 'package:riff/services/firebase_game_repository.dart';
import 'package:riff/theme.dart' show esperaMinimaCarga;

class _AuthFalsa implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RepositorioFalso extends FirebaseGameRepository {
  _RepositorioFalso() : super(auth: _AuthFalsa());

  @override
  Future<EstadoIntros> cargarIntros({
    Genero? genero,
  }) async => EstadoIntros.fromJson({
    'monedas': 7,
    'monedas_ganadas': 9,
    'restantes': 27,
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
      {
        'id': 'cancion-05',
        'numero': 3,
        'estado': 'completada',
        'titulo': 'Abre la puerta',
        'artista': 'Otro',
      },
    ],
  });
}

class _RepositorioSinRed extends _RepositorioFalso {
  @override
  Future<EstadoIntros> cargarIntros({Genero? genero}) async =>
      throw const SocketException('sin red');
}

void main() {
  testWidgets('sin red las intros piden conexión y dejan reintentar', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseGameRepositoryProvider.overrideWithValue(
            _RepositorioSinRed(),
          ),
        ],
        child: const MaterialApp(home: IntrosScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(esperaMinimaCarga);
    expect(find.text('No hay conexión a internet'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

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
      await tester.pump(esperaMinimaCarga);
      expect(tester.takeException(), isNull);
      expect(find.text('7'), findsOneWidget);
      // Las cartas salen directo: la descubierta con su título.
      expect(find.textContaining('Quedan 27'), findsOneWidget);
      expect(find.textContaining('Sacar carta'), findsOneWidget);
      expect(find.textContaining('Una canción'), findsOneWidget);
      // Descubiertas en orden alfabético, aunque "Una" salió primero.
      final abre = tester.getTopLeft(find.text('Abre la puerta'));
      final una = tester.getTopLeft(find.textContaining('Una canción'));
      expect(
        abre.dy < una.dy || (abre.dy == una.dy && abre.dx < una.dx),
        isTrue,
      );
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
