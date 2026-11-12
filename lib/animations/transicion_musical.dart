import 'package:flutter/material.dart';

import 'transicion_activa.dart';

/// Fundido cruzado, la única transición de la app: la pantalla que sale se
/// desvanece subiendo un poco (el primer 35 %) y la nueva aparece después
/// subiendo desde más abajo. Solo cambia opacidad y posición, lo más barato de
/// animar: sin tirones aunque haya vidrio desenfocado.
class TransicionMusical extends StatelessWidget {
  const TransicionMusical({
    super.key,
    required this.child,
    this.retroceso = false,
  });

  final Widget child;
  // Al volver atrás la pantalla nueva entra desde arriba y la vieja se va hacia
  // abajo, como regresando; al avanzar, al revés.
  final bool retroceso;

  // Lo bastante larga y con desplazamiento suficiente para que se note.
  static const duracion = Duration(milliseconds: 300);
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
        return TransicionActiva.escuchando(
          animacion,
          FadeTransition(
            opacity: tramo,
            child: SlideTransition(
              position: quieto
                  ? const AlwaysStoppedAnimation(Offset.zero)
                  : Tween(
                      // Avanzando entra desde abajo y sale hacia arriba;
                      // retrocediendo, al revés.
                      begin: Offset(
                        0,
                        (entra ? subida : -subida / 2) * (retroceso ? -1 : 1),
                      ),
                      end: Offset.zero,
                    ).animate(tramo),
              child: hijo,
            ),
          ),
        );
      },
      child: child,
    );
  }
}
