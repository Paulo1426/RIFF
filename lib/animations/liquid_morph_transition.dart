import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Transición líquida entre pantallas: la nueva aparece con fundido, crece
/// de 0,94 a 1 y se enfoca (desenfoque de 8 a 0). La de atrás se desvanece
/// un poco al quedar cubierta. Se registra en el tema
/// (`pageTransitionsTheme`).
class LiquidMorphPageTransitionsBuilder extends PageTransitionsBuilder {
  const LiquidMorphPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);

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
    return FadeTransition(
      // La pantalla de atrás baja al 60 % mientras la cubren.
      opacity: Tween(begin: 1.0, end: 0.6).animate(secondaryAnimation),
      child: FadeTransition(
        opacity: entrada,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(entrada),
          child: AnimatedBuilder(
            animation: entrada,
            child: child,
            builder: (context, child) {
              final sigma = 8 * (1 - entrada.value);
              // Sin filtro en reposo: el desenfoque solo cuesta durante la
              // transición.
              if (sigma < 0.1) return child!;
              return ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: child,
              );
            },
          ),
        ),
      ),
    );
  }
}
