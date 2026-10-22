import 'sala.dart';

/// Una insignia: cuánto lleva el jugador ([actual]) de lo que pide ([meta]).
class Logro {
  const Logro({
    required this.emoji,
    required this.nombre,
    required this.condicion,
    required this.actual,
    required this.meta,
    this.extra = true,
  });

  final String emoji;
  final String nombre;
  final String condicion;
  final int actual;
  final int meta;
  // Otra condición que también debe cumplirse (Vallenatólogo pide además el
  // 100 % del progreso).
  final bool extra;

  bool get logrado => actual >= meta && extra;
}

/// Avance del jugador en el juego, para calcular las insignias.
class AvanceJuego {
  const AvanceJuego({
    required this.facil,
    required this.media,
    required this.avanzada,
    required this.nivelesPorDificultad,
    required this.introsAdivinadas,
    required this.totalIntros,
    this.unInstrumento = 0,
  });

  // Niveles completados en cada dificultad.
  final int facil;
  final int media;
  final int avanzada;
  final int nivelesPorDificultad;
  final int introsAdivinadas;
  final int totalIntros;
  // Niveles ganados comprando un solo instrumento.
  final int unInstrumento;

  int get niveles => facil + media + avanzada;
  int get totalNiveles => nivelesPorDificultad * 3;
  bool get todasLasIntros => totalIntros > 0 && introsAdivinadas >= totalIntros;
  bool get todoCompleto => niveles >= totalNiveles && todasLasIntros;
}

List<Logro> logrosDe(SaldoSalas salas, AvanceJuego juego) {
  final n = juego.nivelesPorDificultad;
  return [
    Logro(
      emoji: '🌊',
      nombre: 'Nueva ola',
      condicion: 'Completa la dificultad Fácil',
      actual: juego.facil,
      meta: n,
    ),
    Logro(
      emoji: '🪗',
      nombre: 'Me gusta el vallenato',
      condicion: 'Completa la dificultad Media',
      actual: juego.media,
      meta: n,
    ),
    Logro(
      emoji: '🇨🇴',
      nombre: 'Orgullo vallenato',
      condicion: 'Completa todos los niveles de Adivina la canción',
      actual: juego.niveles,
      meta: juego.totalNiveles,
    ),
    Logro(
      emoji: '🎶',
      nombre: 'Música para mis oídos',
      condicion: 'Completa todos los niveles comprando un solo instrumento',
      actual: juego.unInstrumento,
      meta: juego.totalNiveles,
    ),
    Logro(
      emoji: '🎧',
      nombre: 'Así se empieza la parranda',
      condicion: 'Adivina todas las intros',
      actual: juego.introsAdivinadas,
      meta: juego.totalIntros,
    ),
    Logro(
      emoji: '🥇',
      nombre: 'El mejor',
      condicion: 'Queda de primero en 5 salas',
      actual: salas.ganadas,
      meta: 5,
    ),
    Logro(
      emoji: '🎼',
      nombre: 'Coleccionador de música',
      condicion: 'Queda de primero en 10 salas',
      actual: salas.ganadas,
      meta: 10,
    ),
    Logro(
      emoji: '👑',
      nombre: 'Vallenatólogo',
      condicion: 'Queda de primero en 20 salas y completa el 100 % del juego',
      actual: salas.ganadas,
      meta: 20,
      extra: juego.todoCompleto,
    ),
    Logro(
      emoji: '🎉',
      nombre: 'El alma de la fiesta',
      condicion: 'Queda de primero en 25 salas',
      actual: salas.ganadas,
      meta: 25,
    ),
    Logro(
      emoji: '💪',
      nombre: 'No rendirse',
      condicion: 'Termina último en una sala acertando canciones',
      actual: salas.noRendirse,
      meta: 1,
    ),
  ];
}
