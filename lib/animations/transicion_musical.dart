import 'dart:math';

import 'package:flutter/material.dart';

import 'desintegrar.dart';

/// Cambio de pestaña "musical". Al avanzar, la pantalla nueva entra
/// deslizándose, creciendo y apareciendo con un pequeño rebote como un golpe
/// de tambor. Al regresar, la que sale se deshace en polvo (ver
/// [Desintegrar]) y la nueva aparece encogiéndose a su tamaño. Una onda de
/// ecualizador cruza la pantalla con el color de la pestaña. Con "reducir
/// animaciones" del sistema queda solo el fundido.
class TransicionMusical extends StatelessWidget {
  const TransicionMusical({
    super.key,
    required this.pestana,
    required this.direccion,
    required this.color,
    required this.child,
  });

  // Identifica la pestaña: al cambiar arranca la onda.
  final int pestana;
  // 1 hacia la derecha, -1 hacia la izquierda, 0 sin onda (al abrir).
  final int direccion;
  final Color color;
  final Widget child;

  static const _duracion = Duration(milliseconds: 450);
  // El polvo necesita algo más de tiempo para verse volar.
  static const _duracionPolvo = Duration(milliseconds: 800);

  @override
  Widget build(BuildContext context) {
    final quieto = MediaQuery.disableAnimationsOf(context);
    return Stack(
      children: [
        AnimatedSwitcher(
          duration: _duracion,
          reverseDuration: direccion < 0 && !quieto
              ? _duracionPolvo
              : _duracion,
          transitionBuilder: (hijo, animacion) {
            if (quieto) return FadeTransition(opacity: animacion, child: hijo);
            final entra = hijo.key == child.key;
            final atras = direccion < 0;
            // La que sale al regresar se hace polvo: sin fundido ni movimiento.
            final polvo = atras && !entra;
            final golpe = CurvedAnimation(
              parent: animacion,
              curve: Curves.easeOutBack,
            );
            // Misma estructura para la que entra y la que sale, así el
            // contenido conserva su estado al pasar de una a otra.
            return Desintegrar(
              animacion: animacion,
              activo: polvo,
              child: FadeTransition(
                opacity: polvo
                    ? kAlwaysCompleteAnimation
                    : CurvedAnimation(parent: animacion, curve: Curves.easeOut),
                child: SlideTransition(
                  // Al avanzar entra desde el lado al que se va y la otra
                  // sale hacia el contrario (su animación corre de 1 a 0).
                  position: Tween(
                    begin: polvo || atras
                        ? Offset.zero
                        : Offset((entra ? 0.12 : -0.12) * direccion, 0),
                    end: Offset.zero,
                  ).animate(golpe),
                  child: ScaleTransition(
                    // Al avanzar crece; al regresar aparece encogiéndose.
                    scale: Tween(
                      begin: polvo ? 1.0 : (atras ? 1.06 : 0.92),
                      end: 1.0,
                    ).animate(golpe),
                    child: hijo,
                  ),
                ),
              ),
            );
          },
          child: child,
        ),
        if (!quieto && direccion != 0)
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: _OndaEcualizador(
                  key: ValueKey(pestana),
                  direccion: direccion,
                  color: color,
                  duracion: _duracion + const Duration(milliseconds: 150),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Barras de ecualizador que cruzan la pantalla una vez y desaparecen.
class _OndaEcualizador extends StatefulWidget {
  const _OndaEcualizador({
    super.key,
    required this.direccion,
    required this.color,
    required this.duracion,
  });

  final int direccion;
  final Color color;
  final Duration duracion;

  @override
  State<_OndaEcualizador> createState() => _OndaEcualizadorState();
}

class _OndaEcualizadorState extends State<_OndaEcualizador>
    with SingleTickerProviderStateMixin {
  late final _avance = AnimationController(
    vsync: this,
    duration: widget.duracion,
  )..forward();

  @override
  void dispose() {
    _avance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _Barras(_avance, widget.direccion, widget.color),
    ),
  );
}

class _Barras extends CustomPainter {
  _Barras(this.avance, this.direccion, this.color) : super(repaint: avance);

  final Animation<double> avance;
  final int direccion;
  final Color color;

  static const _barras = 11;

  @override
  void paint(Canvas canvas, Size size) {
    final t = avance.value;
    if (t >= 1) return;
    // Aparece y se apaga a la vez que cruza.
    final brillo = sin(pi * t);
    final ida = Curves.easeInOut.transform(t);
    final centro =
        size.width * (direccion > 0 ? -0.2 + 1.4 * ida : 1.2 - 1.4 * ida);
    final ancho = size.width * 0.018;
    final paso = ancho * 2.2;
    final pincel = Paint()..color = color.withValues(alpha: 0.35 * brillo);
    for (var i = 0; i < _barras; i++) {
      final desfase = i - _barras ~/ 2;
      // Más altas en el centro de la onda y "bailando" con el tiempo.
      final forma = cos(desfase / _barras * pi);
      final baile = 0.55 + 0.45 * sin(t * 4 * pi + i * 1.3).abs();
      final alto = size.height * 0.32 * forma * baile;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(centro + desfase * paso, size.height / 2),
            width: ancho,
            height: alto,
          ),
          Radius.circular(ancho / 2),
        ),
        pincel,
      );
    }
  }

  @override
  bool shouldRepaint(_Barras old) =>
      old.direccion != direccion || old.color != color;
}
