import 'package:flutter/material.dart';

import 'transicion_activa.dart';
import 'transicion_musical.dart';

/// Transición entre pantallas, pensada para gama media: la nueva aparece con
/// fundido subiendo unos píxeles y, al cerrarse, se desvanece. La de atrás no
/// se toca (sin segundo fundido ni escala sobre pantallas con vidrio) y el
/// desenfoque se salta mientras dura (ver [TransicionActiva]). Se registra en
/// el tema (`pageTransitionsTheme`).
class LiquidMorphPageTransitionsBuilder extends PageTransitionsBuilder {
  const LiquidMorphPageTransitionsBuilder();

  static const duracion = Duration(milliseconds: 280);

  @override
  Duration get transitionDuration => duracion;

  @override
  Duration get reverseTransitionDuration => duracion;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => TransicionActiva.escuchando(
    animation,
    LiquidMorphTransition(animation: animation, child: child),
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
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final contenido = RepaintBoundary(child: child);
    final quieto = MediaQuery.disableAnimationsOf(context);
    return FadeTransition(
      opacity: entrada,
      child: quieto
          ? contenido
          : SlideTransition(
              position: Tween(
                begin: const Offset(0, TransicionMusical.subida / 2),
                end: Offset.zero,
              ).animate(entrada),
              child: contenido,
            ),
    );
  }
}
