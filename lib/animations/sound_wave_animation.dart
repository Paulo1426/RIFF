import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Ondas sonoras: barras redondeadas que crecen desde la línea central,
/// más altas en el centro, con un degradado del color hacia un tono claro.
/// Al pausar ([activo] en false) bajan suavemente a un reposo en vez de
/// congelarse, y al reanudar vuelven a subir.
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
    with TickerProviderStateMixin {
  // Movimiento continuo de las barras.
  late final _onda = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  // 1 = sonando, 0 = en reposo; anima el paso entre ambos.
  late final _energia = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
    value: widget.activo ? 1 : 0,
  );

  @override
  void initState() {
    super.initState();
    if (widget.activo) _onda.repeat();
    // En reposo las barras no se mueven: detener la onda ahorra repintar.
    _energia.addStatusListener((estado) {
      if (estado == AnimationStatus.dismissed) _onda.stop();
    });
  }

  @override
  void didUpdateWidget(SoundWaveAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activo != oldWidget.activo) {
      if (widget.activo) {
        _onda.repeat();
        _energia.forward();
      } else {
        _energia.reverse();
      }
    }
  }

  @override
  void dispose() {
    _onda.dispose();
    _energia.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.activo ? 'Sonando' : 'En pausa',
    child: RepaintBoundary(
      child: CustomPaint(
        size: Size(widget.width, widget.height),
        painter: _OndasPainter(
          onda: _onda,
          energia: CurvedAnimation(parent: _energia, curve: Curves.easeOut),
          color: widget.color,
        ),
      ),
    ),
  );
}

class _OndasPainter extends CustomPainter {
  _OndasPainter({
    required this.onda,
    required this.energia,
    required this.color,
  }) : super(repaint: Listenable.merge([onda, energia]));

  final Animation<double> onda;
  final Animation<double> energia;
  final Color color;

  static const _barras = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final t = onda.value * 2 * pi;
    final e = energia.value;
    // Barras más anchas que los huecos.
    final ancho = size.width / (_barras * 1.6);
    final hueco = (size.width - ancho * _barras) / (_barras - 1);
    final centroY = size.height / 2;
    final pincel = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [color, Color.lerp(color, Colors.white, 0.45)!],
      ).createShader(Offset.zero & size);

    for (var i = 0; i < _barras; i++) {
      // Envolvente: las del centro llegan más alto que las de los bordes.
      final posicion = (i - (_barras - 1) / 2) / ((_barras - 1) / 2);
      final envolvente = 1 - 0.45 * posicion * posicion;
      // Dos ondas con velocidades enteras distintas: movimiento orgánico que
      // empalma sin saltos al repetir.
      final mezcla =
          0.6 * sin(t * (1 + i % 3) + i * 0.9) + 0.4 * sin(t * 2 - i * 1.3);
      final nivel = 0.5 + 0.5 * mezcla;
      // En reposo quedan como puntos bajos.
      final alto = max(
        ancho,
        size.height * envolvente * (0.18 + 0.82 * nivel * e),
      );
      final x = i * (ancho + hueco);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centroY - alto / 2, ancho, alto),
          Radius.circular(ancho / 2),
        ),
        pincel,
      );
    }
  }

  @override
  bool shouldRepaint(_OndasPainter oldDelegate) => oldDelegate.color != color;
}
