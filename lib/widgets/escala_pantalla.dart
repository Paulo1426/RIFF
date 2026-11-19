import 'package:flutter/material.dart';

/// Ancho de referencia (dp) para el que está diseñada la interfaz.
const anchoBaseDiseno = 400.0;

/// Escala de la interfaz para un lado corto de pantalla de [lado] dp.
/// Nunca reduce (las pantallas chicas ya se ajustan solas) y deja tablets
/// (>= 600 dp) como están.
double escalaPantalla(double lado) =>
    lado < 600 ? (lado / anchoBaseDiseno).clamp(1.0, 1.5) : 1.0;

/// Agranda toda la app en proporción al ancho real del teléfono: la misma
/// interfaz se ve igual de llena en un teléfono de 360 dp que en uno grande o
/// con la pantalla configurada en "tamaño pequeño". Los widgets ven un
/// [MediaQuery] ya dividido por la escala, así que su layout no cambia.
class EscalaPantalla extends StatelessWidget {
  const EscalaPantalla({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final k = escalaPantalla(media.size.shortestSide);
    if (k == 1.0) return child;
    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(
        width: media.size.width / k,
        height: media.size.height / k,
        child: MediaQuery(
          data: media.copyWith(
            size: media.size / k,
            padding: media.padding / k,
            viewPadding: media.viewPadding / k,
            viewInsets: media.viewInsets / k,
            systemGestureInsets: media.systemGestureInsets / k,
          ),
          child: child,
        ),
      ),
    );
  }
}
