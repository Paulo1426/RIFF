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
  ) => FadeTransition(
    // La pantalla de atrás se apaga un poco mientras entra la nueva.
    opacity: Tween(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOut),
    ),
    child: LiquidMorphTransition(animation: animation, child: child),
  );
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
    // Empieza al instante (sin espera) y frena suave al final.
    final entrada = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeInCubic,
    );
    final quieto = MediaQuery.disableAnimationsOf(context);
    return FadeTransition(
      opacity: entrada,
      child: ScaleTransition(
        scale: Tween(begin: quieto ? 1.0 : 0.97, end: 1.0).animate(entrada),
        child: SlideTransition(
          position: Tween(
            begin: Offset(0, quieto ? 0 : TransicionMusical.subida / 2),
            end: Offset.zero,
          ).animate(entrada),
          child: child,
        ),
      ),
    );
  }
}
