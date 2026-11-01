import 'package:flutter/material.dart';

/// Fundido cruzado, la única transición de la app: la pantalla que sale se
/// desvanece subiendo un poco (el primer 35 %) y la nueva aparece después
/// subiendo desde más abajo. Solo cambia opacidad y posición, lo más barato de
/// animar: sin tirones aunque haya vidrio desenfocado.
class TransicionMusical extends StatelessWidget {
  const TransicionMusical({super.key, required this.child});

  final Widget child;

  // Lo bastante larga y con desplazamiento suficiente para que se note.
  static const duracion = Duration(milliseconds: 350);
  // Fracción del alto que sube la que entra (~30 px en un teléfono).
  static const subida = 0.04;

  @override
  Widget build(BuildContext context) {
    final quieto = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: duracion,
      transitionBuilder: (hijo, animacion) {
        final entra = hijo.key == child.key;
        // La que entra aparece después de que la otra se fue; la que sale
        // (su animación va de 1 a 0) se va al principio.
        final tramo = CurvedAnimation(
          parent: animacion,
          curve: entra
              ? const Interval(0.35, 1, curve: Curves.easeOutCubic)
              : const Interval(0.65, 1, curve: Curves.easeIn),
        );
        return FadeTransition(
          opacity: tramo,
          child: SlideTransition(
            position: quieto
                ? const AlwaysStoppedAnimation(Offset.zero)
                : Tween(
                    // Entra desde abajo; sale hacia arriba.
                    begin: Offset(0, entra ? subida : -subida / 2),
                    end: Offset.zero,
                  ).animate(tramo),
            child: hijo,
          ),
        );
      },
      child: child,
    );
  }
}
