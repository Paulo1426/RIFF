import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:riff/models/logros.dart';
import 'package:riff/models/sala.dart';
import 'package:riff/services/insignias_vistas.dart';
import 'package:riff/services/recordatorios.dart';

void main() {
  test(
    'solo avisa de las insignias nuevas; la primera vez de ninguna',
    () async {
      final carpeta = await Directory.systemTemp.createTemp('insignias');
      addTearDown(() => carpeta.delete(recursive: true));
      final vistas = InsigniasVistas('u1', carpeta: () async => carpeta);

      expect(await vistas.registrar({'Nueva ola'}), isEmpty);
      expect(await vistas.registrar({'Nueva ola', 'El mejor'}), {'El mejor'});
      // Datos a medias (sin una que ya tenía) no la vuelven a avisar después.
      expect(await vistas.registrar({'El mejor'}), isEmpty);
      expect(await vistas.registrar({'Nueva ola', 'El mejor'}), isEmpty);

      await vistas.borrar();
      expect(await vistas.registrar(const {}), isEmpty);
      expect(await vistas.registrar({'Nueva ola'}), {'Nueva ola'});
    },
  );

  test('colores por dificultad y Vallenatólogo dorada', () {
    const juego = AvanceJuego(
      facil: 0,
      media: 0,
      avanzada: 0,
      nivelesPorDificultad: 5,
      introsAdivinadas: 0,
      totalIntros: 0,
    );
    final logros = {
      for (final l in logrosDe(const SaldoSalas(), juego)) l.nombre: l,
    };
    expect(logros['No rendirse']!.nivel, NivelInsignia.facil);
    expect(logros['El mejor']!.nivel, NivelInsignia.media);
    expect(logros['El alma de la fiesta']!.nivel, NivelInsignia.dificil);
    expect(logros['Vallenatólogo']!.dorada, isTrue);
    // Sin saber cuántas intros hay, la de intros no cuenta como conseguida.
    expect(logros['Así se empieza la parranda']!.logrado, isFalse);
  });

  test('recordatorios cada 12 h turnando los textos', () {
    final desde = DateTime(2026, 1, 1, 8);
    final plan = Recordatorios.plan(desde, cantidad: 4);
    expect(plan.map((p) => p.$1), [
      DateTime(2026, 1, 1, 20),
      DateTime(2026, 1, 2, 8),
      DateTime(2026, 1, 2, 20),
      DateTime(2026, 1, 3, 8),
    ]);
    expect(plan.map((p) => p.$2), [
      ...Recordatorios.mensajes,
      Recordatorios.mensajes.first,
    ]);
  });
}
