import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// "Chasquido": al salir, la pantalla se deshace en polvo. Se toma una foto
/// de [child] al empezar la salida, se parte en granos y cada uno vuela hacia
/// arriba a la derecha girando y apagándose, en un barrido de izquierda a
/// derecha. Mientras [activo] es false (o al entrar) solo pasa [child].
///
/// [animacion] es la de la transición: la salida la lleva de 1 a 0.
class Desintegrar extends StatefulWidget {
  const Desintegrar({
    super.key,
    required this.animacion,
    required this.activo,
    required this.child,
  });

  final Animation<double> animacion;
  final bool activo;
  final Widget child;

  @override
  State<Desintegrar> createState() => _DesintegrarState();
}

class _DesintegrarState extends State<Desintegrar> {
  final _foto = GlobalKey();
  ui.Image? _imagen;
  double _escala = 1;
  List<_Grano> _granos = const [];
  bool _capturando = false;

  @override
  void initState() {
    super.initState();
    widget.animacion.addStatusListener(_alCambiar);
  }

  @override
  void didUpdateWidget(Desintegrar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animacion != widget.animacion) {
      oldWidget.animacion.removeStatusListener(_alCambiar);
      widget.animacion.addStatusListener(_alCambiar);
    }
    _alCambiar(widget.animacion.status);
  }

  @override
  void dispose() {
    widget.animacion.removeStatusListener(_alCambiar);
    _imagen?.dispose();
    super.dispose();
  }

  void _alCambiar(AnimationStatus estado) {
    if (estado == AnimationStatus.reverse && widget.activo) {
      // Tras pintar este cuadro la foto ya está lista para tomarse.
      WidgetsBinding.instance.addPostFrameCallback((_) => _capturar());
    } else if (estado == AnimationStatus.forward && _imagen != null) {
      // Salida cancelada (p. ej. gesto de atrás a medias): vuelve entera.
      setState(_soltar);
    }
  }

  void _soltar() {
    _imagen?.dispose();
    _imagen = null;
    _granos = const [];
  }

  Future<void> _capturar() async {
    if (_capturando || _imagen != null || !mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    final caja = _foto.currentContext?.findRenderObject();
    if (caja is! RenderRepaintBoundary || !caja.hasSize) return;
    _capturando = true;
    try {
      // Media resolución: es polvo, no hace falta nitidez y pesa menos.
      final escala = MediaQuery.devicePixelRatioOf(context) * 0.5;
      final imagen = await caja.toImage(pixelRatio: escala);
      if (!mounted || widget.animacion.status != AnimationStatus.reverse) {
        imagen.dispose();
        return;
      }
      setState(() {
        _imagen = imagen;
        _escala = escala;
        _granos = _Grano.repartir(caja.size);
      });
    } catch (error) {
      // Sin foto la salida sigue con la transición normal.
      debugPrint('No se pudo desintegrar la pantalla: $error');
    } finally {
      _capturando = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final foto = RepaintBoundary(key: _foto, child: widget.child);
    final imagen = _imagen;
    if (imagen == null) return foto;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        // Oculta pero viva: si la salida se cancela, conserva su estado.
        Opacity(opacity: 0, child: foto),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _Polvo(imagen, _escala, _granos, widget.animacion),
            ),
          ),
        ),
      ],
    );
  }
}

/// Un grano de la foto: su lugar, cuándo se suelta y hacia dónde vuela.
class _Grano {
  const _Grano(this.origen, this.retraso, this.deriva, this.giro);

  // Rectángulo en coordenadas lógicas de la pantalla.
  final Rect origen;
  // De 0 a 1: los de la izquierda se sueltan antes.
  final double retraso;
  final Offset deriva;
  final double giro;

  static const _lado = 10.0;

  static List<_Grano> repartir(Size tamano) {
    final azar = Random(7);
    return [
      for (var y = 0.0; y < tamano.height; y += _lado)
        for (var x = 0.0; x < tamano.width; x += _lado)
          _Grano(
            Rect.fromLTWH(x, y, _lado, _lado),
            0.45 * (x / tamano.width) + 0.2 * azar.nextDouble(),
            Offset(
              40 + 110 * azar.nextDouble(),
              -(30 + 120 * azar.nextDouble()),
            ),
            (azar.nextDouble() - 0.5) * 3,
          ),
    ];
  }
}

class _Polvo extends CustomPainter {
  _Polvo(this.imagen, this.escala, this.granos, this.animacion)
    : super(repaint: animacion);

  final ui.Image imagen;
  final double escala;
  final List<_Grano> granos;
  final Animation<double> animacion;

  @override
  void paint(Canvas canvas, Size size) {
    // 0 al empezar la salida, 1 al terminar.
    final t = 1 - animacion.value;
    final transformaciones = <RSTransform>[];
    final recortes = <Rect>[];
    final colores = <Color>[];
    for (final grano in granos) {
      final avance = ((t - grano.retraso) / 0.35).clamp(0.0, 1.0);
      if (avance >= 1) continue;
      final suave = Curves.easeIn.transform(avance);
      final centro = grano.origen.center + grano.deriva * suave;
      final lado = grano.origen.width * escala;
      transformaciones.add(
        RSTransform.fromComponents(
          rotation: grano.giro * suave,
          // La foto está a [escala]: se vuelve al tamaño lógico y se encoge.
          scale: (1 - 0.5 * suave) / escala,
          anchorX: lado / 2,
          anchorY: lado / 2,
          translateX: centro.dx,
          translateY: centro.dy,
        ),
      );
      recortes.add(
        Rect.fromLTWH(
          grano.origen.left * escala,
          grano.origen.top * escala,
          lado,
          lado,
        ),
      );
      colores.add(Colors.white.withValues(alpha: 1 - suave));
    }
    if (transformaciones.isEmpty) return;
    canvas.drawAtlas(
      imagen,
      transformaciones,
      recortes,
      colores,
      BlendMode.modulate,
      null,
      Paint(),
    );
  }

  @override
  bool shouldRepaint(_Polvo old) =>
      old.imagen != imagen || old.granos != granos;
}
