import 'package:flutter/material.dart';

import '../../theme.dart';
import 'liquid_glass_card.dart';

/// Barra de navegación inferior flotante de vidrio. La pestaña activa se
/// marca con una píldora verde translúcida.
///
/// Todavía no se usa: la app no tiene navegación inferior.
class LiquidGlassBottomNav extends StatelessWidget {
  const LiquidGlassBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<({IconData icon, String label})> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: LiquidGlassCard(
          borderRadius: 28,
          opacity: 0.55,
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == currentIndex,
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => onTap(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: i == currentIndex
                              ? AppColors.verde.withValues(alpha: 0.18)
                              : Colors.transparent,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              items[i].icon,
                              color: i == currentIndex
                                  ? context.paleta.tinta
                                  : context.paleta.tintaSuave,
                            ),
                            Text(
                              items[i].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
