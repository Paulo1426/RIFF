import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riff/models/genero.dart';
import 'package:riff/widgets/genre_landscape/genre_landscape.dart';

void main() {
  testWidgets('dibuja todos los géneros con niveles fuera de rango', (
    tester,
  ) async {
    for (final genero in Genero.values) {
      for (final nivel in [-2, 0, 1, 2, 3, 4, 15]) {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              disableAnimations: true,
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: GenreLandscape(genero: genero, level: nivel),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('dibuja los fondos de intros y de salas', (tester) async {
    final fondos = <Widget>[
      for (final genero in Genero.values) FondoIntros.genero(genero),
      const FondoIntros.sala(intros: true),
      const FondoIntros.sala(intros: false),
    ];
    for (final fondo in fondos) {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            disableAnimations: true,
          ),
          child: Directionality(textDirection: TextDirection.ltr, child: fondo),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
