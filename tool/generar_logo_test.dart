// Genera los PNG de Riff (logo, icono, splash e iconos nativos) a partir de
// tool/riff_logo_fuente.png.
// Ejecutar: flutter test tool/generar_logo_test.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const cream = Color(0xFFF4F1EC);

void main() {
  test('genera el logo de Riff', () async {
    final fuente = File('tool/riff_logo_fuente.png').readAsBytesSync();

    // El códec reescala con buen filtrado; dibujar la imagen grande en
    // tamaños chicos (48px) la dejaría pixelada.
    Future<ui.Image> logo(int px) async {
      final codec = await ui.instantiateImageCodec(
        fuente,
        targetWidth: px,
        targetHeight: px,
      );
      return (await codec.getNextFrame()).image;
    }

    Future<void> conLogo(
      String path,
      int w,
      int h, {
      required double tamano,
      double centroY = 0.5,
      Color? fondo,
    }) async {
      final px = (min(w, h) * tamano).round();
      final imagen = await logo(px);
      await guardar(path, w, h, (c, s) {
        if (fondo != null) c.drawRect(Offset.zero & s, Paint()..color = fondo);
        c.drawImage(
          imagen,
          Offset((w - px) / 2, h * centroY - px / 2),
          Paint()..filterQuality = FilterQuality.high,
        );
      }, opaco: fondo != null);
    }

    const logos = 'lib/assets/images/logo';
    await conLogo('$logos/riff_logo.png', 1024, 1024, tamano: 1);
    await conLogo('$logos/riff_icon.png', 512, 512, tamano: 0.96);
    await conLogo(
      '$logos/riff_splash.png',
      1080,
      1920,
      tamano: 0.7,
      centroY: 0.45,
      fondo: cream,
    );
    await conLogo(
      'android/app/src/main/res/drawable-nodpi/riff_splash.png',
      1080,
      1920,
      tamano: 0.7,
      centroY: 0.45,
      fondo: cream,
    );

    const mipmaps = {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    for (final entry in mipmaps.entries) {
      await conLogo(
        'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
        entry.value,
        entry.value,
        tamano: 0.96,
      );
    }

    // iOS redondea el icono por su cuenta y rechaza el canal alfa.
    const iosIcons = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final iconos = RegExp(r'Icon-App-([\d.]+)x[\d.]+@(\d)x\.png');
    for (final file in Directory(iosIcons).listSync().whereType<File>()) {
      final match = iconos.firstMatch(file.path);
      if (match == null) continue;
      final size = (double.parse(match[1]!) * int.parse(match[2]!)).round();
      await conLogo(file.path, size, size, tamano: 0.86, fondo: cream);
    }
    const launch = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
    for (final (sufijo, escala) in [('', 1), ('@2x', 2), ('@3x', 3)]) {
      final size = 200 * escala;
      await conLogo('$launch/LaunchImage$sufijo.png', size, size, tamano: 1);
    }
  });
}

Future<void> guardar(
  String path,
  int w,
  int h,
  void Function(Canvas, Size) pintar, {
  bool opaco = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  pintar(canvas, Size(w.toDouble(), h.toDouble()));
  final image = await recorder.endRecording().toImage(w, h);
  final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png(rgba!.buffer.asUint8List(), w, h, opaco));
}

/// Codificador PNG mínimo; permite RGB sin alfa para los iconos de iOS.
Uint8List png(Uint8List rgba, int w, int h, bool opaco) {
  final filas = BytesBuilder();
  for (var y = 0; y < h; y++) {
    filas.addByte(0);
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      // rawRgba viene premultiplicado: se deshace para el PNG.
      final a = rgba[i + 3];
      for (var k = 0; k < 3; k++) {
        filas.addByte(
          opaco || a == 0 || a == 255
              ? rgba[i + k]
              : min(255, (rgba[i + k] * 255 / a).round()),
        );
      }
      if (!opaco) filas.addByte(a);
    }
  }
  final out = BytesBuilder()
    ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String tipo, List<int> datos) {
    final cuerpo = [...tipo.codeUnits, ...datos];
    out
      ..add(_u32(datos.length))
      ..add(cuerpo)
      ..add(_u32(_crc32(cuerpo)));
  }

  chunk('IHDR', [..._u32(w), ..._u32(h), 8, opaco ? 2 : 6, 0, 0, 0]);
  chunk('IDAT', ZLibCodec(level: 9).encode(filas.takeBytes()));
  chunk('IEND', const []);
  return out.takeBytes();
}

List<int> _u32(int v) => [v >> 24 & 255, v >> 16 & 255, v >> 8 & 255, v & 255];

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc ^= b;
    for (var k = 0; k < 8; k++) {
      crc = crc & 1 != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}
