import 'dart:math' show pi;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../animations/transicion_activa.dart';
import '../../theme.dart';
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
    this.borderGradient,
    this.giroBorde,
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
  // Borde en degradado; gana sobre [borderColor].
  final Gradient? borderGradient;
  // 0..1 = una vuelta del [borderGradient]; solo aplica si es SweepGradient.
  final Animation<double>? giroBorde;

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(borderRadius);
    final tinte = tintColor == null
        ? LiquidGlass.verdeGlassBase
        : tintColor!.withValues(alpha: 0.12);
    final paleta = context.paleta;
    final relleno = Color.alphaBlend(
      tinte,
      paleta.vidrio.withValues(alpha: opacity),
    );
    Widget contenido = DecoratedBox(
      decoration: BoxDecoration(
        // Con degradado, BoxDecoration ignora [color]: el relleno va en una
        // capa propia debajo cuando se pide más opacidad que la estándar
        // (diálogos, tarjetas del menú), para que de verdad tape el fondo.
        color: opacity > LiquidGlass.glassOpacity ? relleno : null,
        borderRadius: forma,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LiquidGlass.glassGradient(paleta),
          borderRadius: forma,
        ),
        child: CustomPaint(
          foregroundPainter: _BordeLuzPainter(
            radio: borderRadius,
            paleta: paleta,
            color: borderColor,
            degradado: borderGradient,
            giro: giroBorde,
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
    if (blur > 0 && !TransicionActiva.de(context)) {
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
  const _BordeLuzPainter({
    required this.radio,
    required this.paleta,
    this.color,
    this.degradado,
    this.giro,
  }) : super(repaint: giro);

  final double radio;
  final Paleta paleta;
  final Color? color;
  final Gradient? degradado;
  final Animation<double>? giro;

  @override
  void paint(Canvas canvas, Size size) {
    const ancho = LiquidGlass.glassBorderWidth;
    final rect = Offset.zero & size;
    final grosor = degradado != null ? 3.5 : (color == null ? ancho : 2.0);
    final borde = RRect.fromRectAndRadius(
      rect.deflate(grosor / 2),
      Radius.circular(radio),
    );
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor;
    if (degradado != null) {
      final g = degradado!;
      pincel.shader = g is SweepGradient && giro != null
          ? SweepGradient(
              colors: g.colors,
              stops: g.stops,
              transform: GradientRotation(giro!.value * 2 * pi),
            ).createShader(rect)
          : g.createShader(rect);
    } else if (color == null) {
      pincel.shader = LiquidGlass.glassBorderGradient(
        paleta,
      ).createShader(rect);
    } else {
      pincel.color = color!;
    }
    canvas.drawRRect(borde, pincel);

    // Brillo interior: línea blanca fina justo bajo el borde superior.
    final brillo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = paleta.brillo.withValues(alpha: 0.3);
    canvas.drawLine(
      Offset(radio, ancho + 1),
      Offset(size.width - radio, ancho + 1),
      brillo,
    );
  }

  @override
  bool shouldRepaint(_BordeLuzPainter oldDelegate) =>
      oldDelegate.radio != radio ||
      oldDelegate.paleta != paleta ||
      oldDelegate.color != color ||
      oldDelegate.degradado != degradado ||
      oldDelegate.giro != giro;
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
