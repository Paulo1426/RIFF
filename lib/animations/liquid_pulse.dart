import 'package:flutter/material.dart';

/// Pulso suave: escala 1,0 → 1,02 → 1,0 cada 2 segundos. Para el botón
/// "Jugar" y elementos activos. Con "reducir movimiento" queda quieto.
class LiquidPulse extends StatefulWidget {
  const LiquidPulse({super.key, required this.child});

  final Widget child;

  @override
  State<LiquidPulse> createState() => _LiquidPulseState();
}

class _LiquidPulseState extends State<LiquidPulse>
    with SingleTickerProviderStateMixin {
  // Ida en 1 s y vuelta en 1 s: un pulso cada 2 s.
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  late final _escala = Tween(
    begin: 1.0,
    end: 1.02,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _escala, child: widget.child);
}
