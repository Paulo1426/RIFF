import 'package:flutter/widgets.dart';

/// Avisa a los vidrios de abajo de que su pantalla se está animando. Mientras
/// dura, se salta el desenfoque (BackdropFilter dentro de un fundido obliga a
/// repintar capas enteras en cada cuadro, lo que tira los fps en gama media);
/// el vidrio es translúcido, así que casi no se nota y vuelve al terminar.
class TransicionActiva extends InheritedWidget {
  const TransicionActiva({
    super.key,
    required this.activa,
    required super.child,
  });

  final bool activa;

  static bool de(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TransicionActiva>()?.activa ??
      false;

  /// Envuelve [hijo] y marca la transición como activa mientras [animacion] no
  /// haya terminado. El hijo no se reconstruye en cada cuadro: solo avisa
  /// cuando cambia el estado.
  static Widget escuchando(Animation<double> animacion, Widget hijo) =>
      AnimatedBuilder(
        animation: animacion,
        child: hijo,
        builder: (_, hijo) => TransicionActiva(
          activa: animacion.status != AnimationStatus.completed,
          child: hijo!,
        ),
      );

  @override
  bool updateShouldNotify(TransicionActiva oldWidget) =>
      oldWidget.activa != activa;
}
