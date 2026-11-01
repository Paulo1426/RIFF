/// Géneros del catálogo. Solo los [disponible] tienen canciones cargadas; los
/// demás se muestran bloqueados en el selector.
enum Genero {
  vallenato('vallenato', 'Vallenato', '🥁🪗🎸', disponible: true),
  reggaeton('reggaeton', 'Reggaetón', '🎧🎤🔊', disponible: true),
  rockPop('rock_pop', 'Rock / Pop', '🎸🥁🎤', disponible: true),
  salsa('salsa', 'Salsa', '🎺🪘🎹', disponible: true),
  popular('popular', 'Popular', '🎸🎻🎺', disponible: true),
  // Mezcla los cinco: niveles e intros al azar de todos los géneros.
  aleatorio('aleatorio', 'Popurrí', '🎲🎶🔀', disponible: true);

  const Genero(
    this.id,
    this.nombre,
    this.instrumentos, {
    this.disponible = false,
  });

  // Nombre en el servidor (supabase/functions/_shared/genero.ts).
  final String id;
  final String nombre;
  // Instrumentos más representativos, animados en su tarjeta.
  final String instrumentos;
  final bool disponible;

  /// Género de un documento del servidor; los viejos, sin campo, son de
  /// vallenato.
  static Genero deId(Object? id) =>
      values.where((genero) => genero.id == id).firstOrNull ?? vallenato;

  bool get esPopurri => this == aleatorio;

  /// Los cinco géneros con catálogo propio (sin Popurrí).
  static List<Genero> get reales =>
      values.where((genero) => !genero.esPopurri).toList();

  /// Popurrí sortea 15 niveles por dificultad y hasta 100 intros entre los
  /// cinco géneros; cada género tiene 5 y 45.
  int get nivelesPorDificultad => esPopurri ? 15 : 5;
  int get totalIntros => esPopurri ? 100 : 45;

  /// Prefijo para lo guardado en el teléfono (caché de audio, copias
  /// offline). Vallenato va sin prefijo para conservar lo ya descargado.
  String get prefijo => this == vallenato ? '' : '$id:';
}

/// Género que se está jugando; lo cambia el selector. Lo leen el repositorio
/// (lo manda al servidor), la caché de audio y las copias offline. Las tareas
/// en segundo plano lo capturan al empezar y paran si cambia.
Genero generoActivo = Genero.vallenato;
