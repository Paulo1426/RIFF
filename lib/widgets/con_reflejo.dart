import 'package:flutter/material.dart';

/// Tarjeta con una sombra suave de su color debajo. Antes llevaba además su
/// reflejo (una copia volteada); se quitó porque dibujaba cada tarjeta dos
/// veces.
class ConReflejo extends StatelessWidget {
  const ConReflejo({super.key, required this.color, required this.tarjeta});

  final Color color;
  final Widget tarjeta;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, espacio) {
      final alto = espacio.maxHeight;
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
        ],
      );
    },
  );
}
