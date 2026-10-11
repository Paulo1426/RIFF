import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../theme/liquid_glass_theme.dart';

/// Tarjeta de vidrio líquido: desenfoca lo de atrás bajo un blanco
/// translúcido con un tinte suave, borde de luz en degradado, brillo interior
/// arriba y sombra suave.
///
/// Usa [BackdropFilter.grouped]: si hay un [BackdropGroup] arriba (está en
/// `main.dart`), todas las tarjetas comparten una sola captura del fondo, lo
/// que abarata tener varias en pantalla. Con [blur] en 0 no se desenfoca nada,
/// útil en listas largas.
class LiquidGlassCard extends StatelessWidget {
  const LiquidGlassCard({
    super.key,
    required this.child,
    this.blur = LiquidGlass.glassBlur,
    this.opacity = LiquidGlass.glassOpacity,
    this.borderRadius = LiquidGlass.glassRadius,
    this.padding,
    this.margin,
    this.tintColor,
    this.borderColor,
  });

  final Widget child;
  final double blur;
  // Opacidad del relleno blanco base.
  final double opacity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  // Tinte de color muy suave (al 8 %); por defecto verde.
  final Color? tintColor;
  // Borde sólido de color en vez del borde de luz (p. ej. elemento activo).
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(borderRadius);
    final tinte = tintColor == null
        ? LiquidGlass.verdeGlassBase
        : tintColor!.withValues(alpha: 0.12);
    final relleno = Color.alphaBlend(
      tinte,
      Colors.white.withValues(alpha: opacity),
    );
    Widget contenido = DecoratedBox(
      decoration: BoxDecoration(
        color: relleno,
        gradient: LiquidGlass.glassGradient,
        borderRadius: forma,
      ),
      child: CustomPaint(
        foregroundPainter: _BordeLuzPainter(
          radio: borderRadius,
          color: borderColor,
        ),
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
    if (blur > 0) {
      contenido = BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: contenido,
      );
    }
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: CustomPaint(
        painter: _SombraExteriorPainter(radio: borderRadius),
        child: ClipRRect(borderRadius: forma, child: contenido),
      ),
    );
  }
}

/// Pinta el borde de luz (degradado blanco) o un borde de color, más una
/// línea de brillo interior en la parte de arriba.
class _BordeLuzPainter extends CustomPainter {
  const _BordeLuzPainter({required this.radio, this.color});

  final double radio;
  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    const ancho = LiquidGlass.glassBorderWidth;
    final rect = Offset.zero & size;
    final borde = RRect.fromRectAndRadius(
      rect.deflate(ancho / 2),
      Radius.circular(radio),
    );
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = color == null ? ancho : 2;
    if (color == null) {
      pincel.shader = LiquidGlass.glassBorderGradient.createShader(rect);
    } else {
      pincel.color = color!;
    }
    canvas.drawRRect(borde, pincel);

    // Brillo interior: línea blanca fina justo bajo el borde superior.
    final brillo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.3);
    canvas.drawLine(
      Offset(radio, ancho + 1),
      Offset(size.width - radio, ancho + 1),
      brillo,
    );
  }

  @override
  bool shouldRepaint(_BordeLuzPainter oldDelegate) =>
      oldDelegate.radio != radio || oldDelegate.color != color;
}

/// Sombra suave solo por fuera de la tarjeta: una BoxShadow normal se vería a
/// través del vidrio translúcido y lo ensuciaría de gris.
class _SombraExteriorPainter extends CustomPainter {
  const _SombraExteriorPainter({required this.radio});

  final double radio;

  @override
  void paint(Canvas canvas, Size size) {
    final forma = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radio),
    );
    final fuera = Path.combine(
      PathOperation.difference,
      Path()..addRect(
        (Offset.zero & size).inflate(LiquidGlass.glassShadowBlur * 2),
      ),
      Path()..addRRect(forma),
    );
    canvas
      ..save()
      ..clipPath(fuera)
      ..drawRRect(
        forma.shift(const Offset(0, 10)),
        Paint()
          ..color = Colors.black.withValues(
            alpha: LiquidGlass.glassShadowOpacity,
          )
          ..maskFilter = const MaskFilter.blur(
            BlurStyle.normal,
            LiquidGlass.glassShadowBlur / 2,
          ),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_SombraExteriorPainter oldDelegate) =>
      oldDelegate.radio != radio;
}
