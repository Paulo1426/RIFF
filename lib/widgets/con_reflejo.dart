import 'package:flutter/material.dart';

/// Tarjeta con su reflejo debajo, como sobre un piso de vidrio: una copia
/// volteada que se desvanece hacia abajo y una sombra suave de su color.
class ConReflejo extends StatelessWidget {
  const ConReflejo({
    super.key,
    required this.color,
    required this.tarjeta,
    required this.reflejo,
  });

  final Color color;
  final Widget tarjeta;
  final Widget reflejo;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, espacio) {
      final alto = espacio.maxHeight;
      // Fracción de la tarjeta que se ve reflejada.
      const parte = 0.22;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          // Sombra: una elipse difusa del color de la tarjeta bajo su borde.
          Positioned(
            left: espacio.maxWidth * 0.1,
            right: espacio.maxWidth * 0.1,
            top: alto - 10,
            height: 34,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: 0.45),
                    color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(child: tarjeta),
          Positioned(
            left: 0,
            right: 0,
            top: alto + 6,
            height: alto * parte,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.35),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ).createShader(rect),
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      minHeight: alto,
                      maxHeight: alto,
                      // Volteada: lo más cercano a la tarjeta es su borde
                      // inferior, como en un espejo.
                      child: Transform.flip(flipY: true, child: reflejo),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
