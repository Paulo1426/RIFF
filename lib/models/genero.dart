/// Géneros del catálogo. Solo los [disponible] tienen canciones cargadas; los
/// demás se muestran bloqueados en el selector.
enum Genero {
  vallenato('vallenato', 'Vallenato', '🥁🪗🎸', disponible: true),
  reggaeton('reggaeton', 'Reggaetón', '🎧🎤🔊', disponible: true),
  rockPop('rock_pop', 'Rock / Pop', '🎸🥁🎤', disponible: true),
  salsa('salsa', 'Salsa', '🎺🪘🎹'),
  popular('popular', 'Popular', '🎸🎻🎺');

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

  /// Prefijo para lo guardado en el teléfono (caché de audio, copias
  /// offline). Vallenato va sin prefijo para conservar lo ya descargado.
  String get prefijo => this == vallenato ? '' : '$id:';
}

/// Género que se está jugando; lo cambia el selector. Lo leen el repositorio
/// (lo manda al servidor), la caché de audio y las copias offline. Las tareas
/// en segundo plano lo capturan al empezar y paran si cambia.
Genero generoActivo = Genero.vallenato;
