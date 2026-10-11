import 'package:flutter/material.dart';

/// Brillo sutil que recorre al [child] (verde claro → blanco → verde claro)
/// cada pocos segundos. Para insignias, checks y elementos destacados.
/// Con "reducir movimiento" del sistema queda quieto.
class LiquidShimmer extends StatefulWidget {
  const LiquidShimmer({
    super.key,
    required this.child,
    this.color = const Color(0xFFB8F2D0),
    this.periodo = const Duration(milliseconds: 2400),
  });

  final Widget child;
  // Verde claro de los extremos del brillo.
  final Color color;
  final Duration periodo;

  @override
  State<LiquidShimmer> createState() => _LiquidShimmerState();
}

class _LiquidShimmerState extends State<LiquidShimmer>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.periodo,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // La franja blanca cruza en el primer 60 % del ciclo y luego
        // descansa, para que el brillo no distraiga.
        final t = (_controller.value / 0.6).clamp(0.0, 1.0);
        final centro = -1.0 + 3.0 * t;
        return ShaderMask(
          // srcATop: el brillo solo se pinta sobre el propio child.
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.color.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.8),
              widget.color.withValues(alpha: 0),
            ],
            stops: [
              (centro - 0.35).clamp(0.0, 1.0),
              centro.clamp(0.0, 1.0),
              (centro + 0.35).clamp(0.0, 1.0),
            ],
          ).createShader(rect),
          child: child,
        );
      },
    ),
  );
}
