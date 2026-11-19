import 'package:riff/iconos_phosphor.dart';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../animations/liquid_pulse.dart';
import '../../animations/liquid_ripple_effect.dart';
import '../../animations/liquid_shimmer.dart';
import '../../models/genero.dart';
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

  // Disponible y completado no llevan subtítulo, solo "Nivel X" (el completado
  // con su check al lado).
  String? get _textoEstado => switch (widget.estado) {
    EstadoNivel.completado => null,
    EstadoNivel.disponible => null,
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
            style: text.headlineSmall?.copyWith(color: context.paleta.tinta),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            // Centrado en vertical, a la altura del número y del botón.
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Una línea: al encogerse la tarjeta mientras gira no se desborda.
              // La palabra "Nivel" siempre se ve: se encoge en vez de cortarse.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Nivel ${widget.numero}',
                      maxLines: 1,
                      style: text.titleMedium,
                    ),
                    if (widget.estado == EstadoNivel.completado) ...[
                      const SizedBox(width: 6),
                      const LiquidShimmer(
                        child: Icon(
                          PhosphorIconsFill.checkCircle,
                          color: AppColors.verde,
                          size: 22,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_textoEstado != null)
                Text(
                  _textoEstado!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: context.paleta.tintaSuave,
                  ),
                ),
            ],
          ),
        ),
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
          child: LiquidGlassButton(
            // Del color del género que se juega, no el de la dificultad.
            color: context.paleta.legible(colorGenero(generoActivo)),
            onPressed: widget.onJugar,
            label: 'Jugar',
          ),
        ),
      ),
      EstadoNivel.bloqueado => const _CandadoVidrio(),
    };

    return Semantics(
      label: [
        'Nivel ${widget.numero}',
        if (widget.estado == EstadoNivel.completado) 'Completado',
        ?_textoEstado,
      ].join(', '),
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
                LayoutBuilder(
                  builder: (context, caja) {
                    // La tarjeta crece con el espacio: el contenido se agranda
                    // en proporción en vez de quedar chico en el centro.
                    final k = (caja.maxHeight / 64).clamp(1.0, 1.2);
                    final fila = Padding(
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
                    );
                    if (k < 1.05) return fila;
                    return FittedBox(
                      fit: BoxFit.fill,
                      child: SizedBox(
                        width: caja.maxWidth / k,
                        height: caja.maxHeight / k,
                        child: fila,
                      ),
                    );
                  },
                ),
                if (_bloqueado)
                  // Velo oscuro muy sutil sobre el nivel bloqueado.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: context.paleta.tinta.withValues(alpha: 0.04),
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
      color: context.paleta.vidrio.withValues(alpha: 0.5),
      border: Border.all(color: context.paleta.brillo.withValues(alpha: 0.8)),
    ),
    child: Icon(Icons.lock_outline, size: 20, color: context.paleta.tintaSuave),
  );
}
