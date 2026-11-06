import 'package:flutter/material.dart';

import '../data/terminos.dart';
import '../theme.dart';
import '../widgets/liquid_glass/liquid_background.dart';
import '../widgets/liquid_glass/liquid_glass_button.dart';

Future<void> mostrarInformacion(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const InformacionDialog(),
);

/// Ajustes → Información: términos y condiciones.
class InformacionDialog extends StatelessWidget {
  const InformacionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: LiquidBackground(
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: LiquidGlassButton(
                        onPressed: () => Navigator.of(context).pop(),
                        label: 'Cerrar',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Texto completo de los términos; también lo usa la pantalla de aceptación.
class TextoTerminos extends StatelessWidget {
  const TextoTerminos({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Versión $versionTerminos · $fechaTerminos',
          style: text.bodySmall?.copyWith(color: context.paleta.tintaSuave),
        ),
        const SizedBox(height: 12),
        Text(introTerminos, style: text.bodyMedium),
        for (final (titulo, parrafos) in seccionesTerminos) ...[
          const SizedBox(height: 20),
          Text(titulo, style: text.titleMedium),
          for (final parrafo in parrafos)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: parrafo.startsWith('• ')
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(
                          child: Text(
                            parrafo.substring(2),
                            style: text.bodyMedium,
                          ),
                        ),
                      ],
                    )
                  : Text(parrafo, style: text.bodyMedium),
            ),
        ],
        const SizedBox(height: 28),
        Text(
          cierreTerminos,
          style: text.titleSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
