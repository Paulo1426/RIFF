import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme.dart';
import 'liquid_glass_card.dart';

/// Barra de navegación inferior flotante de vidrio. La pestaña activa se
/// marca con una gota líquida (verde en el menú, naranja en las demás) que
/// salta de una a otra con rebote y, en reposo, se deforma despacio.
class LiquidGlassBottomNav extends StatefulWidget {
  const LiquidGlassBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.claves,
  });

  final List<({IconData icon, String label})> items;
  // Una por pestaña, para que el recorrido guiado pueda resaltarlas.
  final List<GlobalKey>? claves;
  // Fuera de rango (p. ej. Ajustes, que no está en la barra) no marca ninguna.
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  State<LiquidGlassBottomNav> createState() => _LiquidGlassBottomNavState();
}

class _LiquidGlassBottomNavState extends State<LiquidGlassBottomNav>
    with SingleTickerProviderStateMixin {
  // Rebote al llegar a la pestaña: se pasa un poco y vuelve.
  static const _salto = Cubic(0.68, -0.55, 0.27, 1.55);
  // Colores de la app: verde para el menú, naranja para las demás.
  static Color _colorDe(int index) =>
      index == 0 ? AppColors.verde : AppColors.signalOrange;

  late final _reposo = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Con "reducir animaciones" del sistema la gota se queda quieta.
    if (MediaQuery.disableAnimationsOf(context)) {
      _reposo.stop();
    } else if (!_reposo.isAnimating) {
      _reposo.repeat();
    }
  }

  @override
  void dispose() {
    _reposo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final n = widget.items.length;
    final actual = widget.currentIndex;
    final hayActiva = actual >= 0 && actual < n;
    final sinAnimar = MediaQuery.disableAnimationsOf(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: LiquidGlassCard(
          borderRadius: 28,
          opacity: 0.55,
          padding: const EdgeInsets.all(6),
          child: LayoutBuilder(
            builder: (context, espacio) {
              final ancho = espacio.maxWidth / n;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: sinAnimar
                        ? Duration.zero
                        : const Duration(milliseconds: 600),
                    curve: _salto,
                    left: (hayActiva ? actual : 0) * ancho,
                    top: 0,
                    bottom: 0,
                    width: ancho,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: hayActiva ? 1 : 0,
                      child: IgnorePointer(
                        child: TweenAnimationBuilder<Color?>(
                          duration: const Duration(milliseconds: 400),
                          tween: ColorTween(
                            end: _colorDe(hayActiva ? actual : 0),
                          ),
                          builder: (context, color, _) => _gota(color!),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < n; i++)
                        Expanded(
                          key: widget.claves?[i],
                          child: _pestana(context, text, i, i == actual),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// La gota: degradado de [color] con brillo; las esquinas cambian despacio
  /// para que parezca líquida.
  Widget _gota(Color color) => AnimatedBuilder(
    animation: _reposo,
    builder: (context, _) {
      final t = _reposo.value * 2 * pi;
      double radio(double fase) => 20 + 6 * sin(t + fase);
      return Transform.scale(
        scaleX: 1 + 0.03 * sin(t),
        scaleY: 1 - 0.03 * sin(t),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(color, AppColors.paperWhite, 0.35)!,
                color,
                Color.lerp(color, Colors.black, 0.15)!,
              ],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(radio(0)),
              topRight: Radius.circular(radio(pi / 2)),
              bottomRight: Radius.circular(radio(pi)),
              bottomLeft: Radius.circular(radio(3 * pi / 2)),
            ),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 18),
              BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 32),
            ],
          ),
        ),
      );
    },
  );

  Widget _pestana(BuildContext context, TextTheme text, int i, bool activa) {
    // Sobre la gota de color, ícono y texto en blanco.
    final color = activa ? AppColors.paperWhite : context.paleta.tintaSuave;
    return Semantics(
      selected: activa,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => widget.onTap(i),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 300),
                scale: activa ? 1.12 : 1,
                child: Icon(widget.items[i].icon, color: color),
              ),
              Text(
                widget.items[i].label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
