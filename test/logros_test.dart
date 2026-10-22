import 'package:flutter_test/flutter_test.dart';
import 'package:riff/models/logros.dart';
import 'package:riff/models/sala.dart';

AvanceJuego _avance({
  int facil = 0,
  int media = 0,
  int avanzada = 0,
  int intros = 0,
}) => AvanceJuego(
  facil: facil,
  media: media,
  avanzada: avanzada,
  nivelesPorDificultad: 5,
  introsAdivinadas: intros,
  totalIntros: 45,
);

bool _tiene(List<Logro> logros, String nombre) =>
    logros.firstWhere((logro) => logro.nombre == nombre).logrado;

void main() {
  test('las insignias del juego salen del avance', () {
    final logros = logrosDe(const SaldoSalas(), _avance(facil: 5, media: 2));
    expect(_tiene(logros, 'Nueva ola'), isTrue);
    expect(_tiene(logros, 'Me gusta el vallenato'), isFalse);
    expect(_tiene(logros, 'Orgullo vallenato'), isFalse);
  });

  test('las insignias de salas cuentan las victorias', () {
    final logros = logrosDe(
      const SaldoSalas(ganadasCancion: 7, ganadasIntros: 3, noRendirse: 1),
      _avance(),
    );
    expect(_tiene(logros, 'El mejor'), isTrue);
    expect(_tiene(logros, 'Coleccionador de música'), isTrue);
    expect(_tiene(logros, 'El alma de la fiesta'), isFalse);
    expect(_tiene(logros, 'No rendirse'), isTrue);
  });

  test('Vallenatólogo pide 30 victorias y el 100 % del juego', () {
    const veinte = SaldoSalas(ganadasCancion: 30);
    expect(
      _tiene(logrosDe(veinte, _avance(intros: 45)), 'Vallenatólogo'),
      isFalse,
    );
    final completo = _avance(facil: 5, media: 5, avanzada: 5, intros: 45);
    expect(_tiene(logrosDe(veinte, completo), 'Vallenatólogo'), isTrue);
    expect(
      _tiene(logrosDe(veinte, completo), 'Así se empieza la parranda'),
      isTrue,
    );
  });

  test('Música para mis oídos pide los 15 niveles con un instrumento', () {
    AvanceJuego avance(int uno) => AvanceJuego(
      facil: 5,
      media: 5,
      avanzada: 5,
      nivelesPorDificultad: 5,
      introsAdivinadas: 0,
      totalIntros: 45,
      unInstrumento: uno,
    );
    const nombre = 'Música para mis oídos';
    expect(_tiene(logrosDe(const SaldoSalas(), avance(14)), nombre), isFalse);
    expect(_tiene(logrosDe(const SaldoSalas(), avance(15)), nombre), isTrue);
  });

  test('el porcentaje de victorias no pasa de 100 %', () {
    // Victorias anteriores a contar partidas.
    const saldo = SaldoSalas(ganadasCancion: 3, jugadas: 2);
    expect(saldo.porcentajeVictorias, 1);
    expect(saldo.derrotas, 0);
  });
}
