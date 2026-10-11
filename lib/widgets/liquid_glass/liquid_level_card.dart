import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../animations/liquid_pulse.dart';
import '../../animations/liquid_ripple_effect.dart';
import '../../animations/liquid_shimmer.dart';
import '../../theme.dart';
import 'liquid_glass_button.dart';
import 'liquid_glass_card.dart';

enum EstadoNivel { bloqueado, disponible, completado }

/// Tarjeta de un nivel dentro de la tarjeta de dificultad: número en cuadro
/// de color, "Nivel X" con su estado y a la derecha el botón o el candado.
///
/// - Disponible: borde verde luminoso y botón naranja "Jugar".
/// - Completado: check verde y botón "Repetir".
/// - Bloqueado: velo oscuro muy suave, contenido levemente desenfocado y
///   candado sobre vidrio.
///
/// Sin desenfoque de fondo propio: ya está dentro del vidrio de la tarjeta de
/// dificultad, y apilar BackdropFilter sale caro.
class LiquidLevelCard extends StatefulWidget {
  const LiquidLevelCard({
    super.key,
    required this.numero,
    required this.estado,
    required this.color,
    this.onJugar,
  });

  final int numero;
  final EstadoNivel estado;
  // Color de la dificultad.
  final Color color;
  final VoidCallback? onJugar;

  @override
  State<LiquidLevelCard> createState() => _LiquidLevelCardState();
}

class _LiquidLevelCardState extends State<LiquidLevelCard> {
  bool _presionada = false;

  bool get _bloqueado => widget.estado == EstadoNivel.bloqueado;

  String get _textoEstado => switch (widget.estado) {
    EstadoNivel.completado => 'Completado',
    EstadoNivel.disponible => 'Canción por descubrir',
    EstadoNivel.bloqueado => 'Bloqueado',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = widget.color;
    final onTap = _bloqueado ? null : widget.onJugar;

    Widget contenido = Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Text(
            '${widget.numero}',
            style: text.headlineSmall?.copyWith(color: AppColors.graphiteInk),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Una línea: al encogerse la tarjeta mientras gira no se desborda.
              Text(
                'Nivel ${widget.numero}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium,
              ),
              Text(
                _textoEstado,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: AppColors.slatePencil),
              ),
            ],
          ),
        ),
        if (widget.estado == EstadoNivel.completado) ...[
          const LiquidShimmer(
            child: Icon(Icons.check_circle_rounded, color: AppColors.verde),
          ),
          const SizedBox(width: 6),
        ],
      ],
    );
    if (_bloqueado) {
      // Desenfoque leve del propio contenido (no del fondo): barato.
      contenido = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 1.2, sigmaY: 1.2),
        child: Opacity(opacity: 0.6, child: contenido),
      );
    }

    final accion = switch (widget.estado) {
      EstadoNivel.completado => OutlinedButton(
        onPressed: widget.onJugar,
        child: const Text('Repetir'),
      ),
      // Más bajo que el estándar para caber en la casilla de 64.
      EstadoNivel.disponible => SizedBox(
        height: 44,
        child: LiquidPulse(
          child: LiquidGlassButton(onPressed: widget.onJugar, label: 'Jugar'),
        ),
      ),
      EstadoNivel.bloqueado => const _CandadoVidrio(),
    };

    return Semantics(
      label: 'Nivel ${widget.numero}, $_textoEstado',
      child: AnimatedScale(
        // Microanimación al tocar la tarjeta.
        scale: _presionada ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: LiquidGlassCard(
          blur: 0,
          borderRadius: 16,
          opacity: 0.6,
          tintColor: color,
          // Borde verde luminoso en el nivel que toca jugar.
          borderColor: widget.estado == EstadoNivel.disponible
              ? AppColors.verde
              : null,
          child: LiquidRippleEffect(
            onTap: onTap,
            onHighlightChanged: (valor) => setState(() => _presionada = valor),
            // expand: ocupa toda la casilla y el contenido queda centrado.
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
                  child: Row(
                    children: [
                      Expanded(child: contenido),
                      // En tarjetas angostas el botón se encoge en vez de
                      // desbordar; nunca ocupa más de la mitad.
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: accion,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_bloqueado)
                  // Velo oscuro muy sutil sobre el nivel bloqueado.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: AppColors.graphiteInk.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Candado gris sobre un círculo de vidrio.
class _CandadoVidrio extends StatelessWidget {
  const _CandadoVidrio();

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    margin: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: 0.5),
      border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
    ),
    child: const Icon(
      Icons.lock_outline,
      size: 20,
      color: AppColors.slatePencil,
    ),
  );
}
