import 'package:flutter/material.dart';

import '../theme.dart';

/// Onda verde translúcida al tocar. Envuelve tarjetas y casillas que no son
/// botones del tema; con [onTap] en null no reacciona.
class LiquidRippleEffect extends StatelessWidget {
  const LiquidRippleEffect({
    super.key,
    required this.child,
    this.onTap,
    this.onHighlightChanged,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  // Avisa al presionar/soltar, p. ej. para encoger la tarjeta.
  final ValueChanged<bool>? onHighlightChanged;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      onHighlightChanged: onHighlightChanged,
      borderRadius: borderRadius,
      splashColor: AppColors.verde.withValues(alpha: 0.18),
      highlightColor: AppColors.verde.withValues(alpha: 0.06),
      child: child,
    ),
  );
}
