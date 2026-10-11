import 'package:flutter/material.dart';

import '../theme.dart';

Future<void> mostrarInstrucciones(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const InstruccionesDialog(),
);

// Una vez por apertura de la app; cerrar sesión y volver a entrar no las repite.
var _instruccionesMostradas = false;

/// Muestra las instrucciones una vez cada vez que se abre la app.
class InstruccionesAlAbrir extends StatefulWidget {
  const InstruccionesAlAbrir({super.key, required this.child});

  final Widget child;

  @override
  State<InstruccionesAlAbrir> createState() => _InstruccionesAlAbrirState();
}

class _InstruccionesAlAbrirState extends State<InstruccionesAlAbrir> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _mostrarSiEsNueva());
  }

  void _mostrarSiEsNueva() {
    if (_instruccionesMostradas || !mounted) return;
    _instruccionesMostradas = true;
    mostrarInstrucciones(context);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class InstruccionesDialog extends StatelessWidget {
  const InstruccionesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Column(
                children: [
                  Image.asset(
                    'lib/assets/images/logo/riff_logo.png',
                    height: 120,
                    semanticLabel: 'Riff',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '¿Cómo funciona?',
                    style: text.bodyLarge?.copyWith(color: AppColors.ash),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: [
                    _Paso(
                      numero: 1,
                      titulo: 'Dificultades',
                      icono: Icons.stairs_rounded,
                      children: [
                        const Text(
                          'El juego tiene 3 dificultades, en este orden:',
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: const [
                            _Etiqueta('Fácil'),
                            Icon(Icons.chevron_right, size: 18),
                            _Etiqueta('Media'),
                            Icon(Icons.chevron_right, size: 18),
                            _Etiqueta('Avanzada'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const _Vineta(
                          'Cada dificultad usa hasta 5 niveles publicados.',
                        ),
                        const _Vineta(
                          'Completa los 5 niveles de una dificultad para desbloquear la siguiente.',
                        ),
                      ],
                    ),
                    const _Paso(
                      numero: 2,
                      titulo: 'Los niveles',
                      icono: Icons.queue_music_rounded,
                      children: [
                        Text(
                          'Cada nivel tiene 4 instrumentos con fragmentos de 30 segundos:',
                        ),
                        SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _Etiqueta('🥁 Batería'),
                            _Etiqueta('🪗 Acordeón'),
                            _Etiqueta('🎸 Guitarra'),
                            _Etiqueta('🎵 Bajo'),
                          ],
                        ),
                      ],
                    ),
                    _Paso(
                      numero: 3,
                      titulo: 'Compra y juega',
                      icono: Icons.paid_rounded,
                      children: [
                        const Text(
                          'Cada partida empieza con un presupuesto de:',
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(40),
                              border: Border.all(color: AppColors.charcoal),
                            ),
                            child: Text(
                              '\$1.000.000',
                              style: text.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const _Vineta('Compras 3 de los 4 instrumentos.'),
                        const _Vineta(
                          'Cada precio (\$300.000 o \$400.000) se asigna al comprar; las 3 compras suman el presupuesto completo.',
                        ),
                      ],
                    ),
                    const _Paso(
                      numero: 4,
                      titulo: 'Descubre la melodía',
                      icono: Icons.hearing_rounded,
                      children: [
                        Text(
                          'Cada partida esconde la melodía en un instrumento elegido al azar.',
                        ),
                        SizedBox(height: 8),
                        _Vineta(
                          'Al descubrirla se habilitan los demás instrumentos y la mezcla sin voz.',
                          icono: Icons.check_circle_rounded,
                        ),
                        _Vineta(
                          'Si adivinas la canción, escuchas la grabación original.',
                          icono: Icons.check_circle_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                children: [
                  Text(
                    '¡ESCUCHA · COMPRA · ADIVINA!',
                    textAlign: TextAlign.center,
                    style: text.titleSmall?.copyWith(letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('¡A jugar!'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({
    required this.numero,
    required this.titulo,
    required this.icono,
    required this.children,
  });

  final int numero;
  final String titulo;
  final IconData icono;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$numero', style: text.displaySmall?.copyWith(height: 1)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          titulo.toUpperCase(),
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Icon(icono, color: AppColors.ash),
                    ],
                  ),
                  const SizedBox(height: 6),
                  DefaultTextStyle.merge(
                    style: text.bodyMedium,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.khakiPaper,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      texto,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppColors.charcoal,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Vineta extends StatelessWidget {
  const _Vineta(this.texto, {this.icono = Icons.circle});

  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(
            icono,
            size: icono == Icons.circle ? 8 : 16,
            color: AppColors.inkStone,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(texto)),
      ],
    ),
  );
}
