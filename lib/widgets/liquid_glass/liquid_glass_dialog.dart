import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'liquid_glass_card.dart';

/// Diálogo de vidrio con la misma forma de uso que [AlertDialog] (ícono,
/// título, contenido y acciones). Con [child] se usa un contenido libre en su
/// lugar. El vidrio es más opaco que una tarjeta para que el texto se lea
/// bien sobre la pantalla de atrás.
class LiquidGlassDialog extends StatelessWidget {
  const LiquidGlassDialog({
    super.key,
    this.icon,
    this.title,
    this.content,
    this.actions,
    this.child,
    this.insetPadding = const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 24,
    ),
  });

  final Widget? icon;
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final Widget? child;
  final EdgeInsets insetPadding;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dialogo = Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: insetPadding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: LiquidGlassCard(
          // Casi sólido: el fondo apenas se adivina y el texto se lee bien.
          opacity: 0.92,
          padding: child == null ? const EdgeInsets.all(24) : null,
          child:
              child ??
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (icon != null) ...[
                    IconTheme.merge(
                      data: IconThemeData(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      child: Center(child: icon),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (title != null) ...[
                    DefaultTextStyle.merge(
                      style: text.headlineSmall,
                      child: title!,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (content != null)
                    Flexible(
                      child: SingleChildScrollView(
                        child: DefaultTextStyle.merge(
                          style: text.bodyMedium,
                          child: content!,
                        ),
                      ),
                    ),
                  if (actions != null) ...[
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: actions!,
                    ),
                  ],
                ],
              ),
        ),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return dialogo;
    // Aparece con un leve rebote, como los diálogos de los ejemplos de Flutter.
    return dialogo
        .animate()
        .fadeIn(duration: 180.ms)
        .scale(
          begin: const Offset(0.92, 0.92),
          duration: 320.ms,
          curve: Curves.easeOutBack,
        );
  }
}
