import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../animations/liquid_shimmer.dart';
import '../theme.dart';
import 'liquid_glass/liquid_glass_card.dart';

/// Pantalla al acertar: reproductor de la canción con su portada, insignia
/// de acierto, barra de progreso y controles; debajo, [botones]. La usan el
/// juego de instrumentos y "Adivina la intro".
class ReproductorCancion extends StatelessWidget {
  const ReproductorCancion({
    super.key,
    required this.color,
    required this.titulo,
    required this.artista,
    required this.insignia,
    required this.portada,
    required this.reproduciendo,
    required this.enPausa,
    required this.posicion,
    required this.duracion,
    required this.onReproducirPausar,
    required this.onDesdeInicio,
    required this.onDetener,
    required this.onBuscar,
    required this.confeti,
    required this.botones,
    this.nota,
  });

  final Color color;
  final String? titulo;
  final String? artista;
  // Texto de la insignia, p. ej. "¡ADIVINASTE! · NIVEL 3".
  final String insignia;
  // Imagen de red o archivo descargado; null muestra el disco.
  final ImageProvider? portada;
  final bool reproduciendo;
  final bool enPausa;
  final Duration posicion;
  final Duration duracion;
  // null deshabilita el botón (p. ej. sin conexión).
  final VoidCallback? onReproducirPausar;
  final VoidCallback? onDesdeInicio;
  final VoidCallback? onDetener;
  final ValueChanged<Duration>? onBuscar;
  final ConfettiController confeti;
  final Widget botones;
  // Aviso bajo los controles, p. ej. que falta conexión.
  final String? nota;

  Widget _portada(double lado) {
    final disco = ColoredBox(
      color: color.withValues(alpha: 0.18),
      child: Center(
        child: DiscoGirando(
          size: lado * 0.62,
          girando: reproduciendo && !enPausa,
        ),
      ),
    );
    final imagen = portada;
    if (imagen == null) return disco;
    return Image(
      image: imagen,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => disco,
      loadingBuilder: (context, child, progreso) =>
          progreso == null ? child : disco,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = max(duracion.inMilliseconds, 1).toDouble();
    return LayoutBuilder(
      builder: (context, espacio) {
        final lado = min(
          espacio.maxWidth - 48,
          espacio.maxHeight * 0.36,
        ).clamp(160.0, 420.0);
        final vista = SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: max(24, (espacio.maxWidth - 520) / 2),
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: LiquidGlassCard(
                  borderRadius: 26,
                  tintColor: color,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox.square(
                        dimension: lado,
                        child: _portada(lado),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo ?? 'Canción descubierta',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.headlineMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          artista ?? 'Artista desconocido',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyLarge?.copyWith(
                            color: context.paleta.tintaSuave,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.check_circle_rounded, color: color, size: 32),
                ],
              ),
              const SizedBox(height: 12),
              // Insignia de acierto con brillo.
              Align(
                alignment: Alignment.centerLeft,
                child: LiquidShimmer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: color.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.music_note_rounded,
                          color: context.paleta.tonoTexto(color),
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            insignia,
                            style: text.labelMedium?.copyWith(
                              color: context.paleta.tonoTexto(color),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: color,
                  inactiveTrackColor: context.paleta.borde,
                  thumbColor: color,
                  overlayColor: color.withValues(alpha: 0.15),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: posicion.inMilliseconds.clamp(0, total).toDouble(),
                  max: total,
                  onChanged: onBuscar == null
                      ? null
                      : (valor) =>
                            onBuscar!(Duration(milliseconds: valor.round())),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_tiempo(posicion), style: text.bodySmall),
                    Text(_tiempo(duracion), style: text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Desde el inicio',
                    iconSize: 34,
                    onPressed: onDesdeInicio,
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  const SizedBox(width: 16),
                  IconButton.filled(
                    tooltip: reproduciendo && !enPausa
                        ? 'Pausar'
                        : 'Reproducir',
                    iconSize: 44,
                    style: IconButton.styleFrom(
                      backgroundColor: color,
                      // Ícono oscuro sobre colores claros (amarillo, verde).
                      foregroundColor:
                          ThemeData.estimateBrightnessForColor(color) ==
                              Brightness.light
                          ? AppColors.graphiteInk
                          : AppColors.paperWhite,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(14),
                    ),
                    onPressed: onReproducirPausar,
                    icon: Icon(
                      reproduciendo && !enPausa
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    tooltip: 'Detener',
                    iconSize: 34,
                    onPressed: onDetener,
                    icon: const Icon(Icons.stop_rounded),
                  ),
                ],
              ),
              if (nota != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    nota!,
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(
                      color: context.paleta.tintaSuave,
                    ),
                  ),
                ),
              const SizedBox(height: 28),
              botones,
            ],
          ),
        );
        return Stack(
          children: [
            vista,
            // Confeti verde/menta que cae desde arriba al acertar.
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: confeti,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 24,
                maxBlastForce: 18,
                minBlastForce: 6,
                gravity: 0.25,
                colors: const [
                  AppColors.verde,
                  Color(0xFFB8F2D0),
                  Color(0xFF7BE0A6),
                  AppColors.paperWhite,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

String _tiempo(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
