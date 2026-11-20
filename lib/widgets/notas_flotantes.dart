import 'dart:math';

import 'package:flutter/material.dart';

import '../animations/ciclo_lento.dart';

/// Pocas notas musicales tenues que suben despacio por los dos márgenes y se
/// desvanecen. Solo ambientan: no reciben toques, no tienen semántica y no
/// reaccionan al audio. Quietas si [activo] es false o con "reducir
/// animaciones".
class NotasFlotantes extends StatefulWidget {
  const NotasFlotantes({super.key, required this.color, this.activo = true});

  final Color color;
  final bool activo;

  @override
  State<NotasFlotantes> createState() => _NotasFlotantesState();
}

class _NotasFlotantesState extends State<NotasFlotantes> {
  final _ciclo = CicloLento(periodo: const Duration(seconds: 14));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ciclo.activo =
        widget.activo &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
  }

  @override
  void didUpdateWidget(NotasFlotantes old) {
    super.didUpdateWidget(old);
    if (old.activo != widget.activo) didChangeDependencies();
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _NotasPainter(_ciclo, widget.color),
        ),
      ),
    ),
  );
}

class _NotasPainter extends CustomPainter {
  _NotasPainter(this.ciclo, this.color) : super(repaint: ciclo);

  final CicloLento ciclo;
  final Color color;

  // (x como fracción del margen, fase de salida, tamaño, doble). Alternan
  // lado izquierdo y derecho.
  static const _notas = [
    (0.3, 0.00, 11.0, false),
    (0.6, 0.20, 14.0, true),
    (0.4, 0.40, 10.0, false),
    (0.7, 0.60, 13.0, false),
    (0.5, 0.80, 12.0, true),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Margen libre a cada lado del casete (el casete mide hasta ~248).
    final margen = max(0.0, (size.width - 248) / 2);
    if (margen < 24) return;
    for (var i = 0; i < _notas.length; i++) {
      final (fx, fase, tam, doble) = _notas[i];
      final t = (ciclo.value + fase) % 1.0;
      // Sube por toda la altura; entra y sale con fundido.
      final alfa = sin(t * pi) * 0.3;
      final izquierda = i.isEven;
      final x = izquierda
          ? 8 + (margen - 36) * fx
          : size.width - margen + 12 + (margen - 36) * fx;
      final y = size.height * (0.9 - 0.8 * t);
      _nota(
        canvas,
        Offset(x + 3 * sin(t * 2 * pi + i), y),
        tam,
        color.withValues(alpha: alfa),
        doble,
      );
    }
  }

  void _nota(Canvas canvas, Offset o, double tam, Color c, bool doble) {
    final p = Paint()..color = c;
    final trazo = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = tam * 0.14
      ..strokeCap = StrokeCap.round;
    void cabeza(Offset a) {
      canvas.save();
      canvas.translate(a.dx, a.dy);
      canvas.rotate(-0.4);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: tam * 0.7,
          height: tam * 0.5,
        ),
        p,
      );
      canvas.restore();
    }

    final base = o + Offset(0, tam * 0.9);
    cabeza(base);
    final alto = o + Offset(tam * 0.3, -tam * 0.4);
    canvas.drawLine(base + Offset(tam * 0.3, 0), alto, trazo);
    if (doble) {
      final base2 = base + Offset(tam * 0.9, -tam * 0.2);
      cabeza(base2);
      final alto2 = alto + Offset(tam * 0.9, -tam * 0.2);
      canvas.drawLine(base2 + Offset(tam * 0.3, 0), alto2, trazo);
      canvas.drawLine(alto, alto2, trazo..strokeWidth = tam * 0.22);
    } else {
      canvas.drawLine(alto, alto + Offset(tam * 0.5, tam * 0.5), trazo);
    }
  }

  @override
  bool shouldRepaint(_NotasPainter old) => old.color != color;
}
