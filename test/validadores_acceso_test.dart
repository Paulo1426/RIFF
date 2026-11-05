import 'package:flutter_test/flutter_test.dart';
import 'package:riff/services/validadores_acceso.dart';

void main() {
  group('correo', () {
    test('rechaza lo que solo trae @', () {
      for (final malo in ['@', 'a@', '@b', 'a b@c.com', 'a@b', 'a@@b.com']) {
        expect(validarCorreo(malo, registrando: true), isNotNull, reason: malo);
      }
    });
    test('acepta correos normales', () {
      expect(validarCorreo(' ana@mail.com ', registrando: true), isNull);
    });
    test('al iniciar sesión acepta usuario sin @', () {
      expect(validarCorreo('ana', registrando: false), isNull);
    });
  });

  group('contraseña', () {
    test('al registrar exige 8+ con letra y número', () {
      for (final mala in ['123456', 'abcdefg', 'abcdefgh', '12345678']) {
        expect(validarClave(mala, registrando: true), isNotNull, reason: mala);
      }
      expect(validarClave('riff2026x', registrando: true), isNull);
    });
    test('al iniciar sesión no impone reglas a cuentas viejas', () {
      expect(validarClave('123456', registrando: false), isNull);
    });
  });
}
