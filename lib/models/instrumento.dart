import 'genero.dart';

enum TipoInstrumento { bateria, acordeon, bajo, guitarra }

extension TipoInstrumentoExtension on TipoInstrumento {
  String get id => name;

  String get nombre {
    switch (this) {
      case TipoInstrumento.bateria:
        return 'Batería';
      case TipoInstrumento.acordeon:
        return _melodico.$2;
      case TipoInstrumento.bajo:
        return 'Bajo';
      case TipoInstrumento.guitarra:
        return 'Guitarra';
    }
  }

  /// Emoji del instrumento en el juego.
  String get emoji => switch (this) {
    TipoInstrumento.bateria => '🥁',
    TipoInstrumento.acordeon => _melodico.$1,
    TipoInstrumento.guitarra => '🎸',
    TipoInstrumento.bajo => '🎵',
  };

  // La pista "acordeon" lleva el instrumento melódico del género que se
  // juega; batería, bajo y guitarra sirven para todos.
  static (String, String) get _melodico => switch (generoActivo) {
    Genero.vallenato => ('🪗', 'Acordeón'),
    Genero.reggaeton => ('🎹', 'Sintetizador'),
    Genero.rockPop => ('🎹', 'Teclado'),
    Genero.salsa => ('🎺', 'Metales'),
    Genero.popular => ('🎺', 'Trompeta'),
    // Cada nivel es de un género distinto: la pista melódica sin nombre fijo.
    Genero.aleatorio => ('🎼', 'Solista'),
  };

  static TipoInstrumento fromId(String value) {
    return TipoInstrumento.values.firstWhere(
      (tipo) => tipo.id == value,
      orElse: () => throw FormatException('Instrumento desconocido: $value'),
    );
  }
}

class Instrumento {
  final TipoInstrumento tipo;
  final int precio;
  final String audioUrl;
  final bool comprable;

  const Instrumento({
    required this.tipo,
    required this.precio,
    required this.audioUrl,
    this.comprable = true,
  }) : assert(precio == 0 || precio == 300000 || precio == 400000);

  String get id => tipo.id;
  String get nombre => tipo.nombre;

  factory Instrumento.fromJson(Map<String, dynamic> json) {
    final rawTipo = json['tipo'] ?? json['instrumento'];
    if (rawTipo == null) {
      throw const FormatException('Falta el tipo del instrumento');
    }
    final rawPrecio = json['precio'];
    final rawAudioUrl = json['audio_url'] ?? json['audioUrl'] ?? '';
    return Instrumento(
      tipo: TipoInstrumentoExtension.fromId(rawTipo.toString()),
      precio: rawPrecio == null ? 0 : (rawPrecio as num).toInt(),
      audioUrl: rawAudioUrl.toString(),
      comprable: json['comprable'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'tipo': id,
    'precio': precio,
    'audio_url': audioUrl,
    'comprable': comprable,
  };

  Instrumento copyWith({
    TipoInstrumento? tipo,
    int? precio,
    String? audioUrl,
    bool? comprable,
  }) {
    return Instrumento(
      tipo: tipo ?? this.tipo,
      precio: precio ?? this.precio,
      audioUrl: audioUrl ?? this.audioUrl,
      comprable: comprable ?? this.comprable,
    );
  }
}
