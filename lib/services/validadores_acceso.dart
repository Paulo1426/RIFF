// H-05: validación de entradas del formulario de acceso.
final _correo = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

String? validarCorreo(String? value, {required bool registrando}) {
  if (value == null || value.trim().isEmpty) return 'Escribe un correo';
  return registrando && !_correo.hasMatch(value.trim())
      ? 'Escribe un correo válido'
      : null;
}

// Al iniciar sesión no se imponen reglas: las cuentas viejas pueden tener claves cortas.
String? validarClave(String? value, {required bool registrando}) {
  if (value == null || value.isEmpty) return 'Escribe una contraseña';
  if (!registrando) return null;
  final fuerte =
      value.length >= 8 &&
      value.contains(RegExp(r'[A-Za-z]')) &&
      value.contains(RegExp(r'\d'));
  return fuerte ? null : 'Usa 8 o más caracteres con letras y números';
}
