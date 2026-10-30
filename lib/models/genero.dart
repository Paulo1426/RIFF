/// Géneros del catálogo. Solo los [disponible] tienen canciones cargadas; los
/// demás se muestran bloqueados en el selector.
enum Genero {
  vallenato('Vallenato', '🥁🪗🎸', disponible: true),
  reggaeton('Reggaetón', '🎧🎤🔊', disponible: true),
  rockPop('Rock / Pop', '🎸🥁🎤'),
  salsa('Salsa', '🎺🪘🎹'),
  popular('Popular', '🎸🎻🎺');

  const Genero(this.nombre, this.instrumentos, {this.disponible = false});

  final String nombre;
  // Instrumentos más representativos, animados en su tarjeta.
  final String instrumentos;
  final bool disponible;
}
