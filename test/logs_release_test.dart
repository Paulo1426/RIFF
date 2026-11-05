import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riff/services/logs_release.dart';

List<String> _capturar(void Function() accion) {
  final salida = <String>[];
  runZoned(
    accion,
    zoneSpecification: ZoneSpecification(
      print: (_, _, _, linea) => salida.add(linea),
    ),
  );
  return salida;
}

void main() {
  final original = debugPrint;
  tearDown(() => debugPrint = original);

  test('en release debugPrint no escribe nada (sin fuga a Logcat)', () {
    silenciarLogsEnRelease(release: true);
    expect(_capturar(() => debugPrint('token=abc123')), isEmpty);
  });

  test('en debug debugPrint sigue funcionando', () {
    silenciarLogsEnRelease(release: false);
    expect(_capturar(() => debugPrint('hola')), ['hola']);
  });
}
