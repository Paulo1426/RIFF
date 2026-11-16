import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Entrada escalonada (fundido + subida suave) para listas. [indice] retrasa
/// cada elemento 45 ms, hasta un máximo, para que una lista larga no tarde.
/// Sin animación si el sistema pide reducir el movimiento.
class Entrada extends StatelessWidget {
  const Entrada({super.key, required this.child, this.indice = 0});

  final Widget child;
  final int indice;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return child
        .animate(delay: (45 * indice.clamp(0, 8)).ms)
        .fadeIn(duration: 320.ms, curve: Curves.easeOut)
        .slideY(
          begin: 0.12,
          end: 0,
          duration: 380.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
