import 'dart:async';

import 'package:flutter/widgets.dart';

/// Fase de 0 a 1 que da una vuelta cada [periodo]. Todas las instancias
/// avanzan juntas con un solo reloj de 30 cuadros por segundo, en vez de los
/// 60-120 de un AnimationController: el fondo que flota, la gota de la barra
/// y los emojis del menú se ven igual, pero la app dibuja la mitad de cuadros
/// (o menos) con todos sus desenfoques, que es lo que gasta batería. Al ir
/// sincronizadas, varias a la vez no suman cuadros. Se usa como [Listenable]
/// en un AnimatedBuilder o CustomPainter.
class CicloLento extends ChangeNotifier {
  CicloLento({required this.periodo}) {
    _vivas++;
    _ciclo ??= AppLifecycleListener(onStateChange: (_) => _revisarReloj());
  }

  final Duration periodo;
  bool _activo = false;
  // Fase en la que quedó al pausarse, para seguir desde ahí sin saltos.
  double _fase = 0;
  Duration? _desde;

  static const _cuadro = Duration(microseconds: 1000000 ~/ 30);
  static final _activas = <CicloLento>{};
  static final _reloj = Stopwatch()..start();
  static Timer? _timer;
  static AppLifecycleListener? _ciclo;
  static int _vivas = 0;

  double get value {
    final desde = _desde;
    if (desde == null) return _fase;
    final pasado = _reloj.elapsed - desde;
    return (_fase + pasado.inMicroseconds / periodo.inMicroseconds) % 1.0;
  }

  /// Anda solo si [activo] y la app está en primer plano. El widget lo pone
  /// en false con "reducir movimiento" o cuando su pantalla queda tapada
  /// (TickerMode).
  set activo(bool valor) {
    if (valor == _activo) return;
    _activo = valor;
    if (valor) {
      _desde = _reloj.elapsed;
      _activas.add(this);
    } else {
      _fase = value;
      _desde = null;
      _activas.remove(this);
    }
    _revisarReloj();
  }

  static void _revisarReloj() {
    final estado = WidgetsBinding.instance.lifecycleState;
    final anda =
        _activas.isNotEmpty &&
        estado != AppLifecycleState.paused &&
        estado != AppLifecycleState.hidden;
    if (anda && _timer == null) {
      _timer = Timer.periodic(_cuadro, (_) {
        for (final ciclo in [..._activas]) {
          ciclo.notifyListeners();
        }
      });
    } else if (!anda && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    activo = false;
    if (--_vivas == 0) {
      _ciclo?.dispose();
      _ciclo = null;
    }
    super.dispose();
  }
}
