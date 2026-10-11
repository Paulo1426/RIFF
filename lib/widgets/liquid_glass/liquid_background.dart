import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme.dart';

/// Fondo líquido: gris claro con manchas verdes/menta muy suaves que flotan
/// despacio, para que el vidrio tenga algo que desenfocar. [acento] tiñe
/// dos de las manchas (p. ej. con el color de la dificultad) y cambia con una
/// transición suave.
class LiquidBackground extends StatefulWidget {
  const LiquidBackground({super.key, required this.child, this.acento});

  final Widget child;
  final Color? acento;

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground>
    with SingleTickerProviderStateMixin {
  // Un ciclo completo dura 24 s: el movimiento casi no se nota.
  late final _ciclo = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Con "reducir movimiento" del sistema las manchas quedan quietas.
    if (MediaQuery.disableAnimationsOf(context)) {
      _ciclo.stop();
    } else if (!_ciclo.isAnimating) {
      _ciclo.repeat();
    }
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      // Gris base: la pantalla es transparente para que el fondo cubra
      // también la barra, así que el color lo pone este widget.
      const Positioned.fill(child: ColoredBox(color: AppColors.cloudMist)),
      Positioned.fill(
        // Capa propia: animar el fondo no repinta el contenido de encima.
        child: RepaintBoundary(
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: widget.acento ?? AppColors.verde),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            builder: (context, color, _) =>
                CustomPaint(painter: _BlobsPainter(_ciclo, color!)),
          ),
        ),
      ),
      widget.child,
    ],
  );
}

class _BlobsPainter extends CustomPainter {
  _BlobsPainter(this.ciclo, this.acento) : super(repaint: ciclo);

  final Animation<double> ciclo;
  final Color acento;

  // Menta suave de la paleta.
  static const _menta = Color(0xFFB8F2D0);

  @override
  void paint(Canvas canvas, Size size) {
    final t = ciclo.value * 2 * pi;
    // (x, y, radio, color, fase): posición base relativa y desfase de cada
    // mancha para que no se muevan al unísono.
    for (final (x, y, r, color, fase) in [
      (0.05, 0.08, 0.85, acento, 0.0),
      (0.95, 0.35, 0.7, _menta, 1.6),
      (0.2, 0.75, 0.8, AppColors.verde, 3.1),
      (0.9, 1.0, 0.75, acento, 4.4),
    ]) {
      final center = Offset(
        size.width * (x + 0.06 * sin(t + fase)),
        size.height * (y + 0.04 * cos(t + fase)),
      );
      final radius = size.width * r;
      // Degradado radial en vez de un blur real de sigma 80: se ve igual de
      // difuso y cuesta mucho menos pintarlo en cada cuadro.
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_BlobsPainter oldDelegate) => oldDelegate.acento != acento;
}
