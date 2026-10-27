import 'package:flutter_test/flutter_test.dart';
import 'package:riff/models/sala.dart';

Map<String, dynamic> _jugador(
  String nombre, {
  int puntos = 0,
  bool eliminado = false,
  int? ronda,
}) => {
  'nombre': nombre,
  'puntos': puntos,
  'aciertos': puntos ~/ 100,
  'eliminado': eliminado,
  'eliminadoEnRonda': ronda,
};

Sala _sala(String modo, Map<String, dynamic> jugadores) =>
    Sala.fromMap(_mapa(modo, jugadores));

Map<String, dynamic> _mapa(String modo, Map<String, dynamic> jugadores) => {
  'codigo': 'ABC234',
  'creadorUid': 'a',
  'publica': true,
  'modo': modo,
  'dificultad': 'medio',
  'maxJugadores': 5,
  'estado': 'jugando',
  'jugadores': jugadores,
  'orden': jugadores.keys.toList(),
  'ronda': 3,
  'acertaronRonda': ['b'],
  'finEn': '2026-10-18T12:05:00.000Z',
};

void main() {
  test('lee la sala en orden de llegada', () {
    final sala = _sala('contrarreloj', {
      'a': _jugador('Ana'),
      'b': _jugador('Beto'),
    });
    expect(sala.nombre, 'Sala de Ana');
    expect(sala.jugadores.map((j) => j.nombre), ['Ana', 'Beto']);
    expect(sala.finEn, DateTime.utc(2026, 10, 18, 12, 5));
    expect(sala.llena, isFalse);
  });

  test('las salas viejas son de instrumentos y los premios se leen', () {
    final vieja = _sala('contrarreloj', {'a': _jugador('Ana')});
    expect(vieja.tipo, TipoSala.instrumentos);
    expect(vieja.premios, isEmpty);
    final intros = Sala.fromMap({
      ..._mapa('eliminacion', {'a': _jugador('Ana')}),
      'tipo': 'intros',
      'premios': {'a': 10},
    });
    expect(intros.tipo, TipoSala.intros);
    expect(intros.premios, {'a': 10});
  });

  test('contrarreloj ordena por puntos', () {
    final sala = _sala('contrarreloj', {
      'a': _jugador('Ana', puntos: 120),
      'b': _jugador('Beto', puntos: 340),
      'c': _jugador('Caro', puntos: 200),
    });
    expect(sala.clasificacion.map((j) => j.nombre), ['Beto', 'Caro', 'Ana']);
  });

  test('eliminación pone primero a los vivos y luego a quien cayó tarde', () {
    final sala = _sala('eliminacion', {
      'a': _jugador('Ana', eliminado: true, ronda: 1),
      'b': _jugador('Beto'),
      'c': _jugador('Caro', eliminado: true, ronda: 2),
    });
    expect(sala.clasificacion.map((j) => j.nombre), ['Beto', 'Caro', 'Ana']);
  });

  test('lee una sala del historial y tolera campos que faltan', () {
    final sala = HistorialSala.fromMap({
      'codigo': 'ABC234',
      'nombre': 'Sala de Ana',
      'tipo': 'intros',
      'modo': 'eliminacion',
      'ganadorNombre': 'Luis',
      'ganaste': false,
      'puesto': 2,
      'jugadores': 4,
      'terminadaEn': '2026-10-26T20:00:00.000Z',
    });
    expect(sala.tipo, TipoSala.intros);
    expect(sala.modo, ModoSala.eliminacion);
    expect(sala.ganadorNombre, 'Luis');
    expect(sala.puesto, 2);
    expect(sala.terminadaEn, DateTime.utc(2026, 10, 26, 20));

    final vacia = HistorialSala.fromMap({'tipo': 'otro'});
    expect(vacia.tipo, TipoSala.instrumentos);
    expect(vacia.modo, isNull);
    expect(vacia.ganadorNombre, isNull);
  });
}
