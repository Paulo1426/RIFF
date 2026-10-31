import 'genero.dart';
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
  // Otra condición que también debe cumplirse (la insignia maestra del género,
  // p. ej. Vallenatólogo, pide además el 100 % del progreso).
  final bool extra;
  final NivelInsignia nivel;
  // La maestra del género: borde y letras doradas, y una corona al
  // conseguirla.
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

/// Nombres y emojis de las insignias propias de cada género; los requisitos
/// son los mismos en todos.
typedef InsigniasGenero = ({
  String emojiFacil,
  String facil,
  String oido,
  String emojiMedia,
  String media,
  String emojiTodo,
  String todo,
  String intros,
  String maestro,
});

InsigniasGenero insigniasDe(Genero genero) => switch (genero) {
  Genero.vallenato => (
    emojiFacil: '🌊',
    facil: 'Nueva ola',
    oido: 'Música para mis oídos',
    emojiMedia: '🪗',
    media: 'Me gusta el vallenato',
    emojiTodo: '🇨🇴',
    todo: 'Orgullo vallenato',
    intros: 'Así se empieza la parranda',
    maestro: 'Vallenatólogo',
  ),
  Genero.reggaeton => (
    emojiFacil: '🆕',
    facil: 'Nueva escuela',
    oido: 'Flow de oído',
    emojiMedia: '🎧',
    media: 'Me gusta el reggaetón',
    emojiTodo: '🔥',
    todo: 'Reggaetonero de corazón',
    intros: 'Que suene el dembow',
    maestro: 'Rey del perreo',
  ),
  Genero.rockPop => (
    emojiFacil: '🎤',
    facil: 'Banda de garaje',
    oido: 'Oído de rockero',
    emojiMedia: '🎸',
    media: 'Me gusta el rock',
    emojiTodo: '🤘',
    todo: 'Rockero de corazón',
    intros: 'Que empiece el concierto',
    maestro: 'Rockero legendario',
  ),
  Genero.salsa => (
    emojiFacil: '🥁',
    facil: 'Sabor de barrio',
    oido: 'Oído sabroso',
    emojiMedia: '🎺',
    media: 'Me gusta la salsa',
    emojiTodo: '💃',
    todo: 'La salsa es para mí',
    intros: 'Que suene la clave',
    maestro: 'Salsero mayor',
  ),
  Genero.popular => (
    emojiFacil: '🍺',
    facil: 'Primera ronda',
    oido: 'Oído despechado',
    emojiMedia: '🎻',
    media: 'Me gusta la popular',
    emojiTodo: '🍻',
    todo: 'Despechado de corazón',
    intros: 'Sírvame la otra',
    maestro: 'Rey del despecho',
  ),
};

/// Insignias con el avance de [genero]; las de salas son de todos los géneros.
List<Logro> logrosDe(
  SaldoSalas salas,
  AvanceJuego juego, [
  Genero genero = Genero.vallenato,
]) {
  final n = juego.nivelesPorDificultad;
  final g = insigniasDe(genero);
  return [
    Logro(
      emoji: g.emojiFacil,
      nombre: g.facil,
      nivel: NivelInsignia.facil,
      condicion: 'Completa la dificultad Fácil',
      actual: juego.facil,
      meta: n,
    ),
    Logro(
      emoji: g.emojiMedia,
      nombre: g.media,
      nivel: NivelInsignia.facil,
      condicion: 'Completa la dificultad Media',
      actual: juego.media,
      meta: n,
    ),
    Logro(
      emoji: g.emojiTodo,
      nombre: g.todo,
      nivel: NivelInsignia.media,
      condicion: 'Completa todos los niveles de Adivina la canción',
      actual: juego.niveles,
      meta: juego.totalNiveles,
    ),
    Logro(
      emoji: '🎶',
      nombre: g.oido,
      nivel: NivelInsignia.dificil,
      condicion: 'Completa todos los niveles comprando un solo instrumento',
      actual: juego.unInstrumento,
      meta: juego.totalNiveles,
    ),
    Logro(
      emoji: '🎧',
      nombre: g.intros,
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
      nombre: g.maestro,
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

/// Insignias del avance general: suman lo de todos los géneros disponibles
/// ([avances], uno por género) y las salas, que ya son de todos.
List<Logro> logrosGenerales(SaldoSalas salas, List<AvanceJuego> avances) {
  int contar(bool Function(AvanceJuego a) cumple) =>
      avances.where(cumple).length;
  final niveles = avances.fold(0, (total, a) => total + a.niveles);
  final intros = avances.fold(0, (total, a) => total + a.introsAdivinadas);
  final jugados = contar((a) => a.niveles > 0);
  Logro logro(
    String emoji,
    String nombre,
    NivelInsignia nivel,
    String condicion,
    int actual,
    int meta, {
    bool extra = true,
    bool dorada = false,
  }) => Logro(
    emoji: emoji,
    nombre: nombre,
    nivel: nivel,
    condicion: condicion,
    actual: actual,
    meta: meta,
    extra: extra,
    dorada: dorada,
  );
  const f = NivelInsignia.facil, m = NivelInsignia.media;
  const d = NivelInsignia.dificil;
  return [
    logro('🎵', 'Primeros acordes', f, 'Completa tu primer nivel', niveles, 1),
    logro(
      '🧭',
      'Explorador musical',
      f,
      'Completa niveles en 2 géneros',
      jugados,
      2,
    ),
    logro(
      '🗺️',
      'Trotamundos sonoro',
      m,
      'Completa niveles en 3 géneros',
      jugados,
      3,
    ),
    logro('🔟', 'Diez de diez', f, 'Completa 10 niveles en total', niveles, 10),
    logro('🎚️', 'Mezclador', m, 'Completa 25 niveles en total', niveles, 25),
    logro('💿', 'Disco de oro', m, 'Completa 50 niveles en total', niveles, 50),
    logro(
      '📀',
      'Disco de platino',
      d,
      'Completa 75 niveles en total',
      niveles,
      75,
    ),
    logro('📻', 'Oído entrenado', f, 'Adivina 10 intros en total', intros, 10),
    logro('🎙️', 'Radio humana', m, 'Adivina 50 intros en total', intros, 50),
    logro(
      '📚',
      'Enciclopedia musical',
      d,
      'Adivina 100 intros en total',
      intros,
      100,
    ),
    logro(
      '🌟',
      'Políglota musical',
      m,
      'Completa Fácil en 3 géneros',
      contar((a) => a.facil >= a.nivelesPorDificultad),
      3,
    ),
    logro(
      '⚡',
      'Todoterreno',
      m,
      'Completa Media en 3 géneros',
      contar((a) => a.media >= a.nivelesPorDificultad),
      3,
    ),
    logro(
      '🏔️',
      'Cumbre sonora',
      m,
      'Completa Difícil en un género',
      contar((a) => a.avanzada >= a.nivelesPorDificultad),
      1,
    ),
    logro(
      '🏅',
      'Doble corona',
      d,
      'Completa todos los niveles de 2 géneros',
      contar((a) => a.niveles >= a.totalNiveles),
      2,
    ),
    logro(
      '🎓',
      'Maestro de géneros',
      d,
      'Completa todos los niveles de 3 géneros',
      contar((a) => a.niveles >= a.totalNiveles),
      3,
    ),
    logro(
      '💎',
      'Cazador de intros',
      m,
      'Adivina todas las intros de un género',
      contar((a) => a.todasLasIntros),
      1,
    ),
    logro(
      '🎪',
      'Festival completo',
      d,
      'Adivina todas las intros de 3 géneros',
      contar((a) => a.todasLasIntros),
      3,
    ),
    logro('🤝', 'Buen anfitrión', f, 'Juega 10 salas', salas.jugadas, 10),
    logro('⚔️', 'Retador incansable', m, 'Juega 50 salas', salas.jugadas, 50),
    logro(
      '🌍',
      'Leyenda de RIFF',
      d,
      'Completa el 100 % de todos los géneros disponibles',
      contar((a) => a.todoCompleto),
      avances.length,
      dorada: true,
    ),
  ];
}
