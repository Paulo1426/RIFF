import 'sala.dart';

/// Qué tan difícil es conseguir una insignia; define su color.
enum NivelInsignia { facil, media, dificil }

/// Una insignia: cuánto lleva el jugador ([actual]) de lo que pide ([meta]).
class Logro {
  const Logro({
    required this.emoji,
    required this.nombre,
    required this.condicion,
    required this.actual,
    required this.meta,
    required this.nivel,
    this.extra = true,
    this.dorada = false,
  });

  final String emoji;
  final String nombre;
  final String condicion;
  final int actual;
  final int meta;
  // Otra condición que también debe cumplirse (Vallenatólogo pide además el
  // 100 % del progreso).
  final bool extra;
  final NivelInsignia nivel;
  // Vallenatólogo: borde y letras doradas, y una corona al conseguirla.
  final bool dorada;

  // Sin meta (p. ej. aún no se sabe cuántas intros hay) no cuenta.
  bool get logrado => meta > 0 && actual >= meta && extra;
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
      nivel: NivelInsignia.facil,
      condicion: 'Completa la dificultad Fácil',
      actual: juego.facil,
      meta: n,
    ),
    Logro(
      emoji: '🪗',
      nombre: 'Me gusta el vallenato',
      nivel: NivelInsignia.facil,
      condicion: 'Completa la dificultad Media',
      actual: juego.media,
      meta: n,
    ),
    Logro(
      emoji: '🇨🇴',
      nombre: 'Orgullo vallenato',
      nivel: NivelInsignia.media,
      condicion: 'Completa todos los niveles de Adivina la canción',
      actual: juego.niveles,
      meta: juego.totalNiveles,
    ),
    Logro(
      emoji: '🎶',
      nombre: 'Música para mis oídos',
      nivel: NivelInsignia.dificil,
      condicion: 'Completa todos los niveles comprando un solo instrumento',
      actual: juego.unInstrumento,
      meta: juego.totalNiveles,
    ),
    Logro(
      emoji: '🎧',
      nombre: 'Así se empieza la parranda',
      nivel: NivelInsignia.dificil,
      condicion: 'Adivina todas las intros',
      actual: juego.introsAdivinadas,
      meta: juego.totalIntros,
    ),
    Logro(
      emoji: '🥇',
      nombre: 'El mejor',
      nivel: NivelInsignia.media,
      condicion: 'Queda de primero en 5 salas',
      actual: salas.ganadas,
      meta: 5,
    ),
    Logro(
      emoji: '🎼',
      nombre: 'Coleccionador de música',
      nivel: NivelInsignia.media,
      condicion: 'Queda de primero en 10 salas',
      actual: salas.ganadas,
      meta: 10,
    ),
    Logro(
      emoji: '👑',
      nombre: 'Vallenatólogo',
      nivel: NivelInsignia.dificil,
      condicion: 'Queda de primero en 30 salas y completa el 100 % del juego',
      actual: salas.ganadas,
      meta: 30,
      extra: juego.todoCompleto,
      dorada: true,
    ),
    Logro(
      emoji: '🎉',
      nombre: 'El alma de la fiesta',
      nivel: NivelInsignia.dificil,
      condicion: 'Queda de primero en 25 salas',
      actual: salas.ganadas,
      meta: 25,
    ),
    Logro(
      emoji: '💪',
      nombre: 'No rendirse',
      nivel: NivelInsignia.facil,
      condicion: 'Termina último en una sala acertando canciones',
      actual: salas.noRendirse,
      meta: 1,
    ),
  ];
}
