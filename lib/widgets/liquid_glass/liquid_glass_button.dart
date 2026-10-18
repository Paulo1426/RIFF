import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../theme/liquid_glass_theme.dart';

enum LiquidGlassButtonVariant { primary, secondary }

/// Botón con efecto vidrio: color de la paleta translúcido sobre el fondo
/// desenfocado, con brillo arriba. Al presionarlo se encoge a 0,96 y el
/// desenfoque aumenta.
///
/// - [LiquidGlassButtonVariant.primary]: naranja.
/// - [LiquidGlassButtonVariant.secondary]: verde.
class LiquidGlassButton extends StatefulWidget {
  const LiquidGlassButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.variant = LiquidGlassButtonVariant.primary,
  });

  // null deshabilita el botón.
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final LiquidGlassButtonVariant variant;

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton> {
  bool _presionado = false;

  static const _radio = 16.0;

  @override
  Widget build(BuildContext context) {
    final activo = widget.onPressed != null;
    final primario = widget.variant == LiquidGlassButtonVariant.primary;
    final color = !activo
        ? context.paleta.borde
        : primario
        ? LiquidGlass.naranjaGlass
        : AppColors.verde.withValues(alpha: 0.9);
    // Texto oscuro sobre verde: el blanco no da contraste suficiente.
    final colorTexto = !activo
        ? context.paleta.tintaSuave
        : primario
        ? AppColors.paperWhite
        : AppColors.graphiteInk;
    final forma = BorderRadius.circular(_radio);
    final blur = _presionado ? 16.0 : 8.0;

    return AnimatedScale(
      scale: _presionado ? 0.96 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: forma,
          boxShadow: activo
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: forma,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: blur),
            duration: const Duration(milliseconds: 120),
            builder: (context, sigma, child) => BackdropFilter.grouped(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: child,
            ),
            child: Material(
              color: color,
              child: InkWell(
                onTap: widget.onPressed,
                onHighlightChanged: (valor) =>
                    setState(() => _presionado = valor),
                splashColor: AppColors.paperWhite.withValues(alpha: 0.25),
                child: DecoratedBox(
                  // Brillo de vidrio en la mitad superior.
                  decoration: BoxDecoration(
                    borderRadius: forma,
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: LiquidGlass.glassBorderOpacity,
                      ),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [
                        Colors.white.withValues(alpha: 0.3),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                  child: ConstrainedBox(
                    // Altura mínima táctil de 48.
                    constraints: const BoxConstraints(minHeight: 52),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: colorTexto, size: 20),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              widget.label,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: colorTexto),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
