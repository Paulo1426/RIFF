import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:riff/services/audio_service.dart';

void main() {
  test(
    'la caché no se cuelga y comparte las descargas de la misma clave',
    () async {
      final carpeta = await Directory.systemTemp.createTemp('audio');
      addTearDown(() => carpeta.delete(recursive: true));
      var pedidos = 0;
      final audio = AudioService(
        carpeta: () async => carpeta,
        cliente: MockClient((_) async {
          pedidos++;
          return http.Response.bytes([1, 2, 3], 200);
        }),
      );
      const espera = Duration(seconds: 5);

      // Dos pedidos a la vez de la misma clave: una sola descarga.
      final (a, b) = await (
        audio.descargarYGuardar('https://x/a.mp3', 'clave'),
        audio.descargarYGuardar('https://x/a.mp3', 'clave'),
      ).wait.timeout(espera);
      expect(a.path, b.path);
      expect(pedidos, 1);

      // Ya guardado: vuelve sin descargar y sin quedarse esperando.
      final otra = await audio
          .descargarYGuardar('https://x/a.mp3', 'clave')
          .timeout(espera);
      expect(await otra.readAsBytes(), [1, 2, 3]);
      expect(pedidos, 1);
    },
  );
}
