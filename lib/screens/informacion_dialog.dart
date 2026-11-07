import 'package:flutter/material.dart';

import '../data/creditos.dart';
import '../data/terminos.dart';
import '../theme.dart';
import '../widgets/liquid_glass/liquid_background.dart';
import '../widgets/liquid_glass/liquid_glass_button.dart';
import '../widgets/liquid_glass/liquid_glass_card.dart';

Future<void> mostrarInformacion(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const InformacionDialog(),
);

/// Ajustes → Información: términos y condiciones y créditos de la música.
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
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Text('Información', style: text.headlineMedium),
                    ),
                    const TabBar(
                      tabs: [
                        Tab(text: 'Términos y condiciones'),
                        Tab(text: 'Créditos'),
                      ],
                    ),
                    const Expanded(
                      child: TabBarView(
                        children: [
                          SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: TextoTerminos(),
                          ),
                          _Creditos(),
                        ],
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

class _Creditos extends StatelessWidget {
  const _Creditos();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Sin la línea divisoria que el ExpansionTile dibuja por defecto.
    final tema = Theme.of(context).copyWith(dividerColor: Colors.transparent);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: [
        LiquidGlassCard(
          padding: const EdgeInsets.all(16),
          child: Text(avisoCreditos, style: text.bodyMedium),
        ),
        const SizedBox(height: 12),
        for (final MapEntry(key: genero, value: canciones)
            in creditosPorGenero.entries)
          Theme(
            data: tema,
            child: ExpansionTile(
              title: Text(genero, style: text.titleMedium),
              subtitle: Text('${canciones.length} canciones'),
              children: [
                for (final (titulo, artista) in canciones)
                  ListTile(
                    dense: true,
                    title: Text(titulo),
                    subtitle: Text(artista),
                  ),
              ],
            ),
          ),
        Theme(
          data: tema,
          child: ExpansionTile(
            title: Text('Música de fondo de los menús', style: text.titleMedium),
            children: [
              for (final (grupo, pistas) in musicaMenuCreditos) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(grupo, style: text.titleSmall),
                  ),
                ),
                for (final (titulo, autor) in pistas)
                  ListTile(
                    dense: true,
                    title: Text(titulo),
                    subtitle: Text(autor),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
