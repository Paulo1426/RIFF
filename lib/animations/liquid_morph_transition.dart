import 'package:flutter/material.dart';

import 'transicion_musical.dart';

/// Transición entre pantallas: el mismo fundido cruzado que las pestañas (ver
/// TransicionMusical). La nueva aparece con fundido subiendo unos píxeles y,
/// al cerrarse, se desvanece; la de atrás no se toca. Solo opacidad y
/// posición: sin tirones. Se registra en el tema (`pageTransitionsTheme`).
class LiquidMorphPageTransitionsBuilder extends PageTransitionsBuilder {
  const LiquidMorphPageTransitionsBuilder();

  @override
  Duration get transitionDuration => TransicionMusical.duracion;

  @override
  Duration get reverseTransitionDuration => TransicionMusical.duracion;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => LiquidMorphTransition(animation: animation, child: child);
}

class LiquidMorphTransition extends StatelessWidget {
  const LiquidMorphTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final entrada = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: entrada,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, TransicionMusical.subida),
          end: Offset.zero,
        ).animate(entrada),
        child: child,
      ),
    );
  }
}
