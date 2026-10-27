import 'package:flutter/material.dart';

import 'liquid_glass/liquid_glass_dialog.dart';

/// Pide la contraseña para confirmar la cuenta; devuelve lo escrito o null.
/// Es un widget con estado para liberar el campo de texto solo cuando la
/// ventana ya se cerró del todo (liberarlo antes rompe la animación).
class DialogoContrasena extends StatefulWidget {
  const DialogoContrasena({super.key, required this.accion});

  // Texto del botón que confirma ("Reiniciar").
  final String accion;

  @override
  State<DialogoContrasena> createState() => _DialogoContrasenaState();
}

class _DialogoContrasenaState extends State<DialogoContrasena> {
  final _clave = TextEditingController();

  @override
  void dispose() {
    _clave.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (_clave.text.isEmpty) return;
    Navigator.of(context).pop(_clave.text);
  }

  @override
  Widget build(BuildContext context) => LiquidGlassDialog(
    title: const Text('Confirma tu contraseña'),
    content: TextField(
      controller: _clave,
      autofocus: true,
      obscureText: true,
      decoration: const InputDecoration(labelText: 'Contraseña'),
      onSubmitted: (_) => _confirmar(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _confirmar, child: Text(widget.accion)),
    ],
  );
}
