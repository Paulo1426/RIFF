import 'package:flutter/material.dart';

import 'desintegrar.dart';

/// Transición líquida entre pantallas: la nueva aparece con fundido y crece
/// de 0,94 a 1. La de atrás se desvanece
/// un poco al quedar cubierta. Al cerrarse (botón atrás) se deshace en polvo
/// como un chasquido (ver [Desintegrar]). Se registra en el tema
/// (`pageTransitionsTheme`).
class LiquidMorphPageTransitionsBuilder extends PageTransitionsBuilder {
  const LiquidMorphPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);

  // Más larga al cerrar: el polvo necesita tiempo para verse volar.
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 800);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => LiquidMorphTransition(
    animation: animation,
    secondaryAnimation: secondaryAnimation,
    child: child,
  );
}

class LiquidMorphTransition extends StatelessWidget {
  const LiquidMorphTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final entrada = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final quieto = MediaQuery.disableAnimationsOf(context);
    return Desintegrar(
      animacion: animation,
      activo: !quieto,
      child: FadeTransition(
        // La pantalla de atrás baja al 60 % mientras la cubren.
        opacity: Tween(begin: 1.0, end: 0.6).animate(secondaryAnimation),
        child: FadeTransition(
          opacity: entrada,
          child: ScaleTransition(
            scale: Tween(begin: 0.94, end: 1.0).animate(entrada),
            // Sin desenfoque: en pantalla completa era lo más caro de cada
            // cuadro de la transición.
            child: child,
          ),
        ),
      ),
    );
  }
}
