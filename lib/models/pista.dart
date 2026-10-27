enum TipoPista {
  artista,
  iniciales,
  cuartoInstrumento,
}

extension TipoPistaExtension on TipoPista {
  String get id {
    switch (this) {
      case TipoPista.artista:
        return 'artist';
      case TipoPista.iniciales:
        return 'initials';
      case TipoPista.cuartoInstrumento:
        return 'fourth_instrument';
    }
  }

  int get costoMonedas {
    switch (this) {
      case TipoPista.artista:
        return 1;
      case TipoPista.iniciales:
        return 2;
      case TipoPista.cuartoInstrumento:
        return 3;
    }
  }

  String get titulo {
    switch (this) {
      case TipoPista.artista:
        return 'Nombre del Artista';
      case TipoPista.iniciales:
        return 'Iniciales del Título';
      case TipoPista.cuartoInstrumento:
        return '4to Instrumento';
    }
  }

  String get descripcion {
    switch (this) {
      case TipoPista.artista:
        return 'Revela quién canta o interpreta la canción.';
      case TipoPista.iniciales:
        return 'Muestra la primera letra de cada palabra del título.';
      case TipoPista.cuartoInstrumento:
        return 'Desbloquea el instrumento faltante para escuchar.';
    }
  }

  static TipoPista fromId(String value) {
    switch (value) {
      case 'artist':
        return TipoPista.artista;
      case 'initials':
        return TipoPista.iniciales;
      case 'fourth_instrument':
        return TipoPista.cuartoInstrumento;
      default:
        throw FormatException('Tipo de pista desconocido: $value');
    }
  }
}

/// Oculta letras manteniendo las iniciales visibles y respetando puntuación/espacios
/// (ej: "L__ c______ d_ l_ v___").
String maskInitials(String title) {
  return title.split(' ').map((word) {
    var firstLetterSeen = false;
    final buffer = StringBuffer();
    for (var i = 0; i < word.length; i++) {
      final char = word[i];
      final isAlphaNum = RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(char);
      if (isAlphaNum) {
        if (!firstLetterSeen) {
          firstLetterSeen = true;
          buffer.write(char);
        } else {
          buffer.write('_');
        }
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }).join(' ');
}

/// Catálogo de canciones y artistas para resolución de pistas local/fallback.
const Map<String, ({String titulo, String artista})> catalogoCancionesFallback = {
  'facil-01': (titulo: 'Por supuesto que no', artista: 'Martín Elías Díaz'),
  'facil-02': (titulo: 'A blanco y negro', artista: 'Silvestre Dangond'),
  'facil-03': (titulo: 'Tira que jala', artista: 'Kvrass'),
  'facil-04': (titulo: 'Los caminos de la vida', artista: 'Los Diablitos'),
  'facil-05': (titulo: 'Y como hago', artista: 'Peter Manjarrés'),
  'cancion-001': (titulo: 'Por supuesto que no', artista: 'Martín Elías Díaz'),
  'cancion-002': (titulo: 'A blanco y negro', artista: 'Silvestre Dangond'),
  'cancion-003': (titulo: 'Tira que jala', artista: 'Kvrass'),
  'cancion-004': (titulo: 'Los caminos de la vida', artista: 'Los Diablitos'),
  'cancion-005': (titulo: 'Y como hago', artista: 'Peter Manjarrés'),
};

class ResultadoPista {
  final TipoPista tipo;
  final String valor;
  final String? cuartoInstrumento;
  final bool yaComprada;
  final int costo;
  final List<String> pistasUsadas;
  final int monedasRestantes;
  final List<String> instrumentosComprados;

  const ResultadoPista({
    required this.tipo,
    required this.valor,
    this.cuartoInstrumento,
    this.yaComprada = false,
    this.costo = 0,
    this.pistasUsadas = const [],
    required this.monedasRestantes,
    this.instrumentosComprados = const [],
  });

  factory ResultadoPista.fromJson(Map<String, dynamic> json) {
    return ResultadoPista(
      tipo: TipoPistaExtension.fromId(json['tipo'] as String),
      valor: json['valor'] as String? ?? '',
      cuartoInstrumento: json['cuartoInstrumento'] as String?,
      yaComprada: json['yaComprada'] as bool? ?? false,
      costo: (json['costo'] as num?)?.toInt() ?? 0,
      pistasUsadas: (json['pistasUsadas'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
      monedasRestantes: (json['monedasRestantes'] as num?)?.toInt() ?? 0,
      instrumentosComprados: (json['instrumentosComprados'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
    );
  }
}
