import 'package:riff/iconos_phosphor.dart';
import 'package:flutter/material.dart';

/// Pistas que se compran con monedas de Adivina la intro. El servidor las
/// calcula y cobra; la app nunca tiene el título ni el artista.
enum TipoPista {
  // Se compra; el servidor la convierte en primera letra, última o artista.
  sorpresa,
  primeraLetra,
  ultimaLetra,
  artista,
  iniciales,
  cuartoInstrumento,
}

extension TipoPistaExtension on TipoPista {
  /// Las que aparecen en el diálogo para comprar.
  static const comprables = [
    TipoPista.sorpresa,
    TipoPista.iniciales,
    TipoPista.cuartoInstrumento,
  ];

  /// Lo que puede salir en la pista sorpresa.
  static const sorpresas = [
    TipoPista.primeraLetra,
    TipoPista.ultimaLetra,
    TipoPista.artista,
  ];

  String get id {
    switch (this) {
      case TipoPista.sorpresa:
        return 'random';
      case TipoPista.primeraLetra:
        return 'first_letter';
      case TipoPista.ultimaLetra:
        return 'last_letter';
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
      case TipoPista.sorpresa:
      case TipoPista.primeraLetra:
      case TipoPista.ultimaLetra:
      case TipoPista.artista:
        return 3;
      case TipoPista.iniciales:
        return 4;
      case TipoPista.cuartoInstrumento:
        return 5;
    }
  }

  String get titulo {
    switch (this) {
      case TipoPista.sorpresa:
        return 'Pista sorpresa';
      case TipoPista.primeraLetra:
        return 'Primera letra';
      case TipoPista.ultimaLetra:
        return 'Última letra';
      case TipoPista.artista:
        return 'Nombre del Artista';
      case TipoPista.iniciales:
        return 'Iniciales del Título';
      case TipoPista.cuartoInstrumento:
        return 'Instrumento faltante';
    }
  }

  String get descripcion {
    switch (this) {
      case TipoPista.sorpresa:
        return 'Revela al azar la primera letra, la última letra o el artista.';
      case TipoPista.primeraLetra:
        return 'Revela con qué letra empieza el título.';
      case TipoPista.ultimaLetra:
        return 'Revela con qué letra termina el título.';
      case TipoPista.artista:
        return 'Revela quién canta o interpreta la canción.';
      case TipoPista.iniciales:
        return 'Muestra la primera letra de cada palabra del título.';
      case TipoPista.cuartoInstrumento:
        return 'Si con 3 instrumentos no encontraste la melodía, desbloquea '
            'el que falta: tiene la melodía.';
    }
  }

  /// Texto corto que acompaña al valor en la pantalla del nivel.
  String get etiqueta {
    switch (this) {
      case TipoPista.sorpresa:
        return 'Sorpresa';
      case TipoPista.primeraLetra:
        return 'Empieza por';
      case TipoPista.ultimaLetra:
        return 'Termina en';
      case TipoPista.artista:
        return 'Artista';
      case TipoPista.iniciales:
        return 'Iniciales';
      case TipoPista.cuartoInstrumento:
        return '4.º instrumento';
    }
  }

  IconData get icono {
    switch (this) {
      case TipoPista.sorpresa:
        return Icons.casino_rounded;
      case TipoPista.primeraLetra:
        return Icons.first_page_rounded;
      case TipoPista.ultimaLetra:
        return Icons.last_page_rounded;
      case TipoPista.artista:
        return Icons.person_rounded;
      case TipoPista.iniciales:
        return Icons.text_fields_rounded;
      case TipoPista.cuartoInstrumento:
        return PhosphorIconsFill.musicNotes;
    }
  }

  static TipoPista fromId(String value) {
    switch (value) {
      case 'random':
        return TipoPista.sorpresa;
      case 'first_letter':
        return TipoPista.primeraLetra;
      case 'last_letter':
        return TipoPista.ultimaLetra;
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

class ResultadoPista {
  final TipoPista tipo;
  final String valor;
  final String? cuartoInstrumento;
  final bool yaComprada;
  final int costo;
  final List<String> pistasUsadas;
  final int monedasRestantes;
  final Map<String, int> monedasPorGenero;
  final List<String> instrumentosComprados;

  const ResultadoPista({
    required this.tipo,
    required this.valor,
    this.cuartoInstrumento,
    this.yaComprada = false,
    this.costo = 0,
    this.pistasUsadas = const [],
    required this.monedasRestantes,
    this.monedasPorGenero = const {},
    this.instrumentosComprados = const [],
  });

  factory ResultadoPista.fromJson(Map<String, dynamic> json) {
    return ResultadoPista(
      tipo: TipoPistaExtension.fromId(json['tipo'] as String),
      valor: json['valor'] as String? ?? '',
      cuartoInstrumento: json['cuartoInstrumento'] as String?,
      yaComprada: json['yaComprada'] as bool? ?? false,
      costo: (json['costo'] as num?)?.toInt() ?? 0,
      pistasUsadas:
          (json['pistasUsadas'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
      monedasRestantes: (json['monedasRestantes'] as num?)?.toInt() ?? 0,
      monedasPorGenero: {
        for (final entry in (json['monedasPorGenero'] as Map? ?? {}).entries)
          entry.key as String: (entry.value as num).toInt(),
      },
      instrumentosComprados:
          (json['instrumentosComprados'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
    );
  }
}
