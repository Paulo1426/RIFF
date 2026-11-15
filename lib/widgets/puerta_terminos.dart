import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/terminos.dart';
import '../screens/informacion_dialog.dart';
import 'liquid_glass/liquid_glass_button.dart';

/// Pide aceptar los términos, una sola vez por cuenta, antes de mostrar
/// [child]. La aceptación se guarda en el teléfono con la versión de los
/// términos: si la versión cambia, se vuelve a pedir. [onRechazar] cierra la
/// sesión.
class PuertaTerminos extends StatefulWidget {
  const PuertaTerminos({
    super.key,
    required this.uid,
    required this.onRechazar,
    required this.child,
  });

  final String uid;
  final VoidCallback onRechazar;
  final Widget child;

  @override
  State<PuertaTerminos> createState() => _PuertaTerminosState();
}

class _PuertaTerminosState extends State<PuertaTerminos> {
  // null mientras se lee el archivo.
  bool? _aceptados;
  bool _leidos = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  String get _clave => 'terminos_aceptados_${widget.uid}';

  Future<File> _archivo() async {
    final directorio = await getApplicationSupportDirectory();
    return File('${directorio.path}/terminos_aceptados_${widget.uid}');
  }

  Future<void> _cargar() async {
    var aceptados = false;
    try {
      if (kIsWeb) {
        aceptados =
            (await SharedPreferences.getInstance()).getString(_clave) ==
            versionTerminos;
        if (mounted) setState(() => _aceptados = aceptados);
        return;
      }
      final archivo = await _archivo();
      aceptados =
          await archivo.exists() &&
          (await archivo.readAsString()).trim() == versionTerminos;
    } catch (error) {
      debugPrint('No se pudo leer la aceptación de términos: $error');
    }
    if (mounted) setState(() => _aceptados = aceptados);
  }

  Future<void> _aceptar() async {
    try {
      if (kIsWeb) {
        await (await SharedPreferences.getInstance()).setString(
          _clave,
          versionTerminos,
        );
      } else {
        await (await _archivo()).writeAsString(versionTerminos);
      }
    } catch (error) {
      // Si no se puede guardar, se acepta igual y se pedirá la próxima vez.
      debugPrint('No se pudo guardar la aceptación de términos: $error');
    }
    if (mounted) setState(() => _aceptados = true);
  }

  @override
  Widget build(BuildContext context) {
    final aceptados = _aceptados;
    if (aceptados == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (aceptados) return widget.child;
    // Fondo azul del login con texto blanco.
    final tema = Theme.of(context);
    final text = tema.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    );
    return Theme(
      data: tema.copyWith(
        textTheme: text,
        checkboxTheme: CheckboxThemeData(
          side: const BorderSide(color: Colors.white, width: 2),
          checkColor: const WidgetStatePropertyAll(Colors.white),
        ),
      ),
      child: Scaffold(
        backgroundColor: fondoTerminos,
        body: Container(
          color: fondoTerminos,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Text(
                        'Términos y condiciones',
                        style: text.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: TextoTerminos(),
                      ),
                    ),
                    CheckboxListTile(
                      value: _leidos,
                      onChanged: (valor) =>
                          setState(() => _leidos = valor ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'He leído y acepto los términos y condiciones.',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: LiquidGlassButton(
                              onPressed: widget.onRechazar,
                              label: 'No acepto',
                              variant: LiquidGlassButtonVariant.secondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: LiquidGlassButton(
                              onPressed: _leidos ? _aceptar : null,
                              label: 'Aceptar y continuar',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
