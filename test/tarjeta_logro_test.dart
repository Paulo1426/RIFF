import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riff/models/logros.dart';
import 'package:riff/models/sala.dart';
import 'package:riff/screens/home_screen.dart';
import 'package:riff/theme/liquid_glass_theme.dart';

void main() {
  // Teléfono chico (320 px) con letra grande: el ancho y alto que les da la
  // pestaña Progreso.
  testWidgets('las insignias caben en su alto fijo', (tester) async {
    const escala = TextScaler.linear(1.3);
    const ancho = (320 - 32 - 40 - 10) / 2;
    for (final completo in [false, true]) {
      final juego = AvanceJuego(
        facil: completo ? 5 : 0,
        media: completo ? 5 : 0,
        avanzada: completo ? 5 : 0,
        nivelesPorDificultad: 5,
        introsAdivinadas: completo ? 30 : 0,
        totalIntros: 30,
        unInstrumento: completo ? 15 : 0,
      );
      final salas = SaldoSalas(
        ganadasCancion: completo ? 30 : 0,
        noRendirse: completo ? 1 : 0,
      );
      for (final logro in logrosDe(salas, juego)) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildLiquidGlassTheme(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: escala),
              child: Center(
                child: SizedBox(
                  width: ancho,
                  height: escala.scale(224),
                  child: TarjetaLogro(logro: logro),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: logro.nombre);
      }
    }
  });
}
