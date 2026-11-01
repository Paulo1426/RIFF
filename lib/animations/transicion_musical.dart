import 'package:flutter/material.dart';

import 'desintegrar.dart';

/// Fundido cruzado, la única transición de la app: la pantalla que sale se
/// desvanece rápido (el primer 35 %) y la nueva aparece después subiendo unos
/// píxeles. Solo cambia opacidad y posición, lo más barato de animar: sin
/// tirones aunque haya vidrio desenfocado. Con [polvo], al regresar
/// ([direccion] -1) la que sale se deshace en polvo (ver [Desintegrar]).
class TransicionMusical extends StatelessWidget {
  const TransicionMusical({
    super.key,
    required this.direccion,
    required this.child,
    this.polvo = false,
  });

  // 1 al avanzar, -1 al regresar, 0 sin animación (al abrir).
  final int direccion;
  final Widget child;
  // Solo al volver al selector de géneros: es lo único que lo usa.
  final bool polvo;

  static const _duracion = Duration(milliseconds: 250);
  // El polvo necesita algo más de tiempo para verse volar.
  static const _duracionPolvo = Duration(milliseconds: 800);

  @override
  Widget build(BuildContext context) {
    final quieto = MediaQuery.disableAnimationsOf(context);
    final conPolvo = polvo && direccion < 0 && !quieto;
    return AnimatedSwitcher(
      duration: _duracion,
      // Flutter fija la duración de salida cuando la pantalla entra: con polvo
      // va siempre larga (al salir hacia delante solo se desvanece al inicio).
      reverseDuration: polvo && !quieto ? _duracionPolvo : _duracion,
      transitionBuilder: (hijo, animacion) {
        final entra = hijo.key == child.key;
        final hacePolvo = conPolvo && !entra;
        // Misma estructura para la que entra y la que sale, así el contenido
        // conserva su estado al pasar de una a otra.
        return Desintegrar(
          animacion: animacion,
          activo: hacePolvo,
          child: FadeTransition(
            opacity: hacePolvo
                ? kAlwaysCompleteAnimation
                : CurvedAnimation(
                    parent: animacion,
                    // La que entra aparece después de que la otra se fue; la
                    // que sale (su animación va de 1 a 0) se va al principio.
                    curve: entra
                        ? const Interval(0.35, 1, curve: Curves.easeOut)
                        : const Interval(0.65, 1, curve: Curves.easeIn),
                  ),
            child: SlideTransition(
              position: entra && !quieto
                  ? Tween(
                      begin: const Offset(0, 0.012),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animacion,
                        curve: const Interval(
                          0.35,
                          1,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                    )
                  : const AlwaysStoppedAnimation(Offset.zero),
              child: hijo,
            ),
          ),
        );
      },
      child: child,
    );
  }
}
