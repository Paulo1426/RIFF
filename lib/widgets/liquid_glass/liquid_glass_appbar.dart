import 'package:flutter/material.dart';

import 'liquid_glass_card.dart';

/// Barra superior flotante de vidrio: una píldora separada de los bordes que
/// deja ver el fondo líquido. Al desplazar el contenido se vuelve más
/// transparente. Recibe lo mismo que un [AppBar] común (título, acciones,
/// botón atrás automático).
class LiquidGlassAppBar extends StatefulWidget implements PreferredSizeWidget {
  const LiquidGlassAppBar({
    super.key,
    this.title,
    this.actions,
    this.centerTitle,
    this.titleSpacing,
  });

  final Widget? title;
  final List<Widget>? actions;
  final bool? centerTitle;
  final double? titleSpacing;

  // Margen alrededor de la píldora.
  static const _margen = 8.0;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + _margen * 2);

  @override
  State<LiquidGlassAppBar> createState() => _LiquidGlassAppBarState();
}

class _LiquidGlassAppBarState extends State<LiquidGlassAppBar> {
  ScrollNotificationObserverState? _observador;
  bool _desplazado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El Scaffold avisa cuando su contenido se desplaza (igual que AppBar).
    _observador?.removeListener(_alDesplazar);
    _observador = ScrollNotificationObserver.maybeOf(context);
    _observador?.addListener(_alDesplazar);
  }

  @override
  void dispose() {
    _observador?.removeListener(_alDesplazar);
    super.dispose();
  }

  void _alDesplazar(ScrollNotification notificacion) {
    // Solo el desplazamiento vertical del contenido principal.
    if (notificacion is! ScrollUpdateNotification ||
        notificacion.depth != 0 ||
        notificacion.metrics.axis != Axis.vertical) {
      return;
    }
    final desplazado = notificacion.metrics.extentBefore > 0;
    if (desplazado != _desplazado) setState(() => _desplazado = desplazado);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.all(LiquidGlassAppBar._margen),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: _desplazado ? 0.25 : 0.55),
        duration: const Duration(milliseconds: 250),
        builder: (context, opacidad, child) =>
            LiquidGlassCard(borderRadius: 20, opacity: opacidad, child: child!),
        // AppBar transparente dentro de la píldora: conserva el botón atrás,
        // los estilos del tema y la accesibilidad.
        child: AppBar(
          primary: false,
          backgroundColor: Colors.transparent,
          title: widget.title,
          actions: widget.actions,
          centerTitle: widget.centerTitle,
          titleSpacing: widget.titleSpacing,
        ),
      ),
    ),
  );
}
