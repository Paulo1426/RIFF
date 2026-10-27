import 'package:flutter_test/flutter_test.dart';
import 'package:riff/models/nivel.dart';
import 'package:riff/models/pista.dart';
import 'package:riff/services/firebase_game_repository.dart';

void main() {
  test('TipoPista extension properties and parsing work correctly', () {
    expect(TipoPista.artista.id, 'artist');
    expect(TipoPista.artista.costoMonedas, 1);
    expect(TipoPista.iniciales.id, 'initials');
    expect(TipoPista.iniciales.costoMonedas, 2);
    expect(TipoPista.cuartoInstrumento.id, 'fourth_instrument');
    expect(TipoPista.cuartoInstrumento.costoMonedas, 3);

    expect(TipoPistaExtension.fromId('artist'), TipoPista.artista);
    expect(TipoPistaExtension.fromId('initials'), TipoPista.iniciales);
    expect(
      TipoPistaExtension.fromId('fourth_instrument'),
      TipoPista.cuartoInstrumento,
    );
    expect(() => TipoPistaExtension.fromId('unknown'), throwsFormatException);
  });

  test('ResultadoPista parses json from backend properly', () {
    final result = ResultadoPista.fromJson({
      'tipo': 'artist',
      'valor': 'Diomedes Díaz',
      'costo': 1,
      'yaComprada': false,
      'pistasUsadas': ['artist'],
      'monedasRestantes': 4,
      'instrumentosComprados': ['bateria', 'bajo'],
    });

    expect(result.tipo, TipoPista.artista);
    expect(result.valor, 'Diomedes Díaz');
    expect(result.costo, 1);
    expect(result.yaComprada, isFalse);
    expect(result.pistasUsadas, ['artist']);
    expect(result.monedasRestantes, 4);
    expect(result.instrumentosComprados, ['bateria', 'bajo']);
  });

  test('retains backend status for actionable error messages', () {
    const error = GameRepositoryException(
      statusCode: 429,
      message: 'Espera 30 segundos antes de volver a intentarlo',
    );

    expect(error.statusCode, 429);
    expect(error.toString(), contains('30 segundos'));
  });

  test('parses previously completed levels as replayable', () {
    final state = EstadoJuegoRemoto.fromJson({
      'dificultades': [
        {
          'dificultad': 'facil',
          'desbloqueada': true,
          'completados': 1,
          'total': 1,
        },
        {
          'dificultad': 'medio',
          'desbloqueada': true,
          'completados': 0,
          'total': 0,
        },
        {
          'dificultad': 'avanzado',
          'desbloqueada': false,
          'completados': 0,
          'total': 0,
        },
      ],
      'dificultad_activa': 'medio',
      'niveles': [],
      'niveles_repetibles': [
        {
          'nivel': {
            'id': 'facil-01',
            'numero': 1,
            'dificultad': 'facil',
            'cancion_id': 'cancion-001',
            'cancion_titulo': 'Canción misteriosa',
            'instrumentos': [
              {'tipo': 'bateria', 'precio': 0, 'audio_url': ''},
              {'tipo': 'bajo', 'precio': 0, 'audio_url': ''},
              {'tipo': 'acordeon', 'precio': 0, 'audio_url': ''},
            ],
            'puntos_inicio': [0],
            'modo_prueba': true,
            'duracion_fragmento_segundos': 20,
          },
          'completado': true,
          'puede_iniciar': true,
        },
      ],
    });

    expect(state.dificultadActiva, Dificultad.medio);
    expect(state.niveles, isEmpty);
    expect(state.nivelesRepetibles, hasLength(1));
    expect(state.nivelesRepetibles.single.completado, isTrue);
    expect(state.nivelesRepetibles.single.nivel.id, 'facil-01');
  });

  test('parses the purchased instrument price for disclosure', () {
    final result = ResultadoCompraInstrumento.fromJson({
      'presupuestoRestante': 600000,
      'instrumentosComprados': ['acordeon'],
      'melodiaDescubierta': false,
      'compraRealizada': true,
      'precioInstrumento': 400000,
    });

    expect(result.precioInstrumento, 400000);
    expect(result.presupuestoRestante, 600000);
  });
}
