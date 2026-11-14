import 'dart:math';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

import '../models/instrumento.dart';

/// Instrumentos que existen en todos los géneros (la melodía cambia de uno a
/// otro, estos tres no).
const instrumentosComunes = [
  TipoInstrumento.bateria,
  TipoInstrumento.bajo,
  TipoInstrumento.guitarra,
];

const _muestreo = 22050;

/// Sonido corto de cada instrumento, generado en el teléfono: así suena sin
/// conexión y sin archivos de audio aparte.
Uint8List sonidoDe(TipoInstrumento tipo) => _cache.putIfAbsent(tipo, () {
  final salida = switch (tipo) {
    TipoInstrumento.bateria => _bateria(),
    TipoInstrumento.bajo => _bajo(),
    _ => _guitarra(),
  };
  return _wav(salida);
});

final _cache = <TipoInstrumento, Uint8List>{};

// Cuerda pulsada (Karplus-Strong): ruido que se apaga como una cuerda real.
void _cuerda(
  Float64List salida,
  double frecuencia,
  double inicio,
  double fuerza, {
  double amortiguacion = 0.996,
}) {
  final n = max(2, (_muestreo / frecuencia).round());
  final azar = Random(frecuencia.round());
  final cuerda = List<double>.generate(n, (_) => azar.nextDouble() * 2 - 1);
  var i = 0;
  for (var s = (inicio * _muestreo).round(); s < salida.length; s++) {
    final actual = cuerda[i];
    salida[s] += actual * fuerza;
    cuerda[i] = amortiguacion * 0.5 * (actual + cuerda[(i + 1) % n]);
    i = (i + 1) % n;
  }
}

Float64List _guitarra() {
  final salida = Float64List((_muestreo * 1.8).round());
  // Rasgueo de un acorde de mi: las cuerdas entran una tras otra.
  const notas = [82.41, 123.47, 164.81, 207.65, 246.94, 329.63];
  for (var k = 0; k < notas.length; k++) {
    _cuerda(salida, notas[k], k * 0.035, 0.5, amortiguacion: 0.9975);
  }
  return salida;
}

Float64List _bajo() {
  final salida = Float64List((_muestreo * 1.4).round());
  _cuerda(salida, 55, 0, 1, amortiguacion: 0.9985);
  // Suaviza para quitar el brillo de la cuerda: queda grave y redondo.
  var previo = 0.0;
  for (var s = 0; s < salida.length; s++) {
    previo = previo * 0.8 + salida[s] * 0.2;
    salida[s] = previo;
  }
  return salida;
}

Float64List _bateria() {
  final salida = Float64List((_muestreo * 0.75).round());
  // Bombo: un tono grave que baja rápido.
  var fase = 0.0;
  for (var s = 0; s < (_muestreo * 0.4).round(); s++) {
    final t = s / _muestreo;
    fase += 2 * pi * (48 + 120 * exp(-t * 20)) / _muestreo;
    salida[s] += sin(fase) * exp(-t * 9) * 1.1;
  }
  // Caja: ruido seco con un poco de tono.
  final azar = Random(3);
  final inicio = (_muestreo * 0.3).round();
  for (var s = 0; s < (_muestreo * 0.25).round(); s++) {
    final t = s / _muestreo;
    final ruido = (azar.nextDouble() * 2 - 1) * exp(-t * 22) * 0.7;
    final tono = sin(2 * pi * 190 * t) * exp(-t * 30) * 0.4;
    salida[inicio + s] += ruido + tono;
  }
  return salida;
}

Uint8List _wav(Float64List muestras) {
  var pico = 0.0;
  for (final m in muestras) {
    pico = max(pico, m.abs());
  }
  final escala = pico == 0 ? 0.0 : 0.9 / pico;
  final datos = ByteData(44 + muestras.length * 2);
  void texto(int pos, String t) {
    for (var i = 0; i < t.length; i++) {
      datos.setUint8(pos + i, t.codeUnitAt(i));
    }
  }

  texto(0, 'RIFF');
  datos.setUint32(4, 36 + muestras.length * 2, Endian.little);
  texto(8, 'WAVEfmt ');
  datos.setUint32(16, 16, Endian.little);
  datos.setUint16(20, 1, Endian.little);
  datos.setUint16(22, 1, Endian.little);
  datos.setUint32(24, _muestreo, Endian.little);
  datos.setUint32(28, _muestreo * 2, Endian.little);
  datos.setUint16(32, 2, Endian.little);
  datos.setUint16(34, 16, Endian.little);
  texto(36, 'data');
  datos.setUint32(40, muestras.length * 2, Endian.little);
  for (var i = 0; i < muestras.length; i++) {
    datos.setInt16(
      44 + i * 2,
      (muestras[i] * escala * 32767).round().clamp(-32768, 32767),
      Endian.little,
    );
  }
  return datos.buffer.asUint8List();
}

/// Reproduce los bytes de un WAV en memoria.
// ignore: experimental_member_use
class FuenteBytes extends StreamAudioSource {
  FuenteBytes(this._bytes) : super(tag: 'instrumento');

  final Uint8List _bytes;

  @override
  // ignore: experimental_member_use
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final desde = start ?? 0;
    final hasta = end ?? _bytes.length;
    // ignore: experimental_member_use
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: hasta - desde,
      offset: desde,
      stream: Stream.value(_bytes.sublist(desde, hasta)),
      contentType: 'audio/wav',
    );
  }
}
