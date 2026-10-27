import 'dart:async';

import 'package:flutter/widgets.dart';

/// Vuelve a construir solo su [builder] cada [cada] mientras [activo]: para
/// la barra de avance del audio, sin reconstruir la pantalla entera.
class Refresco extends StatefulWidget {
  const Refresco({
    super.key,
    required this.activo,
    required this.builder,
    this.cada = const Duration(milliseconds: 250),
  });

  final bool activo;
  final Duration cada;
  final WidgetBuilder builder;

  @override
  State<Refresco> createState() => _RefrescoState();
}

class _RefrescoState extends State<Refresco> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _revisar();
  }

  @override
  void didUpdateWidget(Refresco oldWidget) {
    super.didUpdateWidget(oldWidget);
    _revisar();
  }

  void _revisar() {
    if (widget.activo && _timer == null) {
      _timer = Timer.periodic(widget.cada, (_) => setState(() {}));
    } else if (!widget.activo) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
