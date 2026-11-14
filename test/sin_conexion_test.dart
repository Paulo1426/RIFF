import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riff/services/firebase_game_repository.dart';
import 'package:riff/services/sonidos_instrumento.dart';
import 'package:riff/widgets/sin_conexion.dart';

void main() {
  test('cada instrumento común genera un WAV válido y distinto', () {
    final sonidos = [for (final tipo in instrumentosComunes) sonidoDe(tipo)];
    for (final bytes in sonidos) {
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(bytes.length, greaterThan(10000));
    }
    expect(sonidos[0], isNot(equals(sonidos[1])));
    expect(sonidos[1], isNot(equals(sonidos[2])));
  });

  test('reconoce los fallos de red de Firebase', () {
    expect(esErrorDeRed(TimeoutException('x')), isTrue);
    expect(
      esErrorDeRed(
        Exception('[cloud_firestore/unavailable] The service is unavailable'),
      ),
      isTrue,
    );
    expect(esErrorDeRed(Exception('permiso denegado')), isFalse);
  });

  testWidgets('sin conexión: tres instrumentos, el aviso y reintentar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var reintentos = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SinConexion(onReintentar: () => reintentos++)),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('No hay conexión a internet'), findsOneWidget);
    expect(find.text('Batería'), findsOneWidget);
    expect(find.text('Bajo'), findsOneWidget);
    expect(find.text('Guitarra'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    expect(reintentos, 1);
  });
}
