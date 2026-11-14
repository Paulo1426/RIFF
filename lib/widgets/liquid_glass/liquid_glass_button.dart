import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../animations/transicion_activa.dart';
import '../../theme.dart';
import '../../theme/liquid_glass_theme.dart';

enum LiquidGlassButtonVariant { primary, secondary }

/// Botón con efecto vidrio: color de la paleta translúcido sobre el fondo
/// desenfocado, con brillo arriba. Al presionarlo se encoge a 0,96 y el
/// desenfoque aumenta.
///
/// - [LiquidGlassButtonVariant.primary]: naranja.
/// - [LiquidGlassButtonVariant.secondary]: verde.
/// - [color]: otro color de fondo (p. ej. los azules del login en Salas).
class LiquidGlassButton extends StatefulWidget {
  const LiquidGlassButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.variant = LiquidGlassButtonVariant.primary,
    this.precio,
    this.color,
    this.precioBlanco = false,
  });

  // null deshabilita el botón.
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  // Costo resaltado en una píldora al final del botón (p. ej. "🎟️ 10").
  final String? precio;
  // El costo en un cuadro blanco, para que se vea mejor.
  final bool precioBlanco;
  final LiquidGlassButtonVariant variant;
  // Si está, reemplaza el color de la variante.
  final Color? color;

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
    final propio = widget.color;
    final color = !activo
        ? context.paleta.borde
        : propio ??
              (primario
                  ? LiquidGlass.naranjaGlass
                  : AppColors.verde.withValues(alpha: 0.9));
    // Texto oscuro sobre verde o sobre un color propio claro: el blanco no da
    // contraste suficiente.
    final colorTexto = !activo
        ? context.paleta.tintaSuave
        : propio != null
        ? (propio.computeLuminance() > 0.45
              ? AppColors.graphiteInk
              : AppColors.paperWhite)
        : primario
        ? AppColors.paperWhite
        : AppColors.graphiteInk;
    final forma = BorderRadius.circular(_radio);
    final blur = _presionado ? 8.0 : 4.0;

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
            tween: Tween(end: TransicionActiva.de(context) ? 0.0 : blur),
            duration: const Duration(milliseconds: 120),
            builder: (context, sigma, child) => sigma <= 0
                ? child!
                : BackdropFilter.grouped(
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
                          if (widget.precio case final precio?) ...[
                            const SizedBox(width: 10),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: widget.precioBlanco
                                    ? Colors.white
                                    : colorTexto.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(
                                  widget.precioBlanco ? 10 : 99,
                                ),
                                border: Border.all(
                                  color: widget.precioBlanco
                                      ? Colors.white
                                      : colorTexto.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                child: Text(
                                  precio,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: widget.precioBlanco
                                            ? AppColors.graphiteInk
                                            : colorTexto,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                            ),
                          ],
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
