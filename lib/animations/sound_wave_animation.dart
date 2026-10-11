import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Ondas sonoras: barras verticales de ecualizador que suben y bajan
/// mientras [activo] es true (al reproducir instrumentos o la canción).
class SoundWaveAnimation extends StatefulWidget {
  const SoundWaveAnimation({
    super.key,
    this.activo = true,
    this.color = AppColors.verde,
    this.width = 64,
    this.height = 26,
  });

  final bool activo;
  final Color color;
  final double width;
  final double height;

  @override
  State<SoundWaveAnimation> createState() => _SoundWaveAnimationState();
}

class _SoundWaveAnimationState extends State<SoundWaveAnimation>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.activo) _controller.repeat();
  }

  @override
  void didUpdateWidget(SoundWaveAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activo && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.activo) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.activo ? 'Sonando' : 'En pausa',
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size(widget.width, widget.height),
        painter: _BarrasPainter(_controller.value, widget.color),
      ),
    ),
  );
}

class _BarrasPainter extends CustomPainter {
  const _BarrasPainter(this.t, this.color);

  final double t;
  final Color color;

  static const _barras = 9;

  @override
  void paint(Canvas canvas, Size size) {
    final grosor = size.width / (_barras * 2);
    final base = size.height - grosor / 2;
    final pincel = Paint()
      ..color = color
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, base), Offset(size.width, base), pincel);
    for (var i = 0; i < _barras; i++) {
      // Cada barra oscila con su propia velocidad y fase; las velocidades
      // son enteras para que el ciclo empalme sin saltos.
      final onda = sin(2 * pi * (t * (1 + i % 3) + i * 0.37));
      final alto = (0.35 + 0.65 * (onda + 1) / 2) * (base - grosor * 1.5);
      final x = grosor * (1 + 2 * i);
      canvas.drawLine(
        Offset(x, base - grosor),
        Offset(x, base - grosor - alto),
        pincel,
      );
    }
  }

  @override
  bool shouldRepaint(_BarrasPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.color != color;
}
