import 'dart:math';

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Carrusel giratorio en 3D. En reposo la tarjeta del frente ocupa toda la
/// pantalla; al girar se encoge y las vecinas aparecen girando hacia los
/// lados. Se arrastra en horizontal, es circular y tocar una tarjeta lateral
/// la trae al frente.
class CarruselGiratorio extends StatefulWidget {
  const CarruselGiratorio({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.inicial = 0,
    this.onCambio,
    this.colorDe,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index, bool alFrente)
  itemBuilder;
  final int inicial;
  final ValueChanged<int>? onCambio;
  // Color del punto activo del indicador.
  final Color Function(int index)? colorDe;

  @override
  State<CarruselGiratorio> createState() => _CarruselGiratorioState();
}

class _CarruselGiratorioState extends State<CarruselGiratorio>
    with TickerProviderStateMixin {
  // Posición continua: un entero significa esa tarjeta al frente. Moverla no
  // reconstruye las tarjetas (solo el AnimatedBuilder de posiciones); se
  // reconstruyen únicamente cuando cambia cuál está al frente.
  late final _posicion = AnimationController.unbounded(
    vsync: this,
    value: widget.inicial.toDouble(),
  )..addListener(_revisarFrente);
  // 0 = tarjeta a pantalla completa, 1 = modo carrusel (mientras gira).
  late final _giro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  late final _movimiento = Listenable.merge([_posicion, _giro]);
  double _anchoArrastre = 300;
  late int _frenteConstruido = _frente;

  int get _n => widget.itemCount;
  int get _frente => _posicion.value.round() % _n;

  void _revisarFrente() {
    if (_frente != _frenteConstruido) {
      setState(() => _frenteConstruido = _frente);
    }
  }

  @override
  void dispose() {
    _posicion.dispose();
    _giro.dispose();
    super.dispose();
  }

  // Distancia de la tarjeta [i] al frente, en el rango [-n/2, n/2).
  double _distancia(int i) => (i - _posicion.value + _n / 2) % _n - _n / 2;

  Future<void> _irA(double destino) async {
    _giro.animateTo(1, curve: Curves.easeOut);
    await _posicion.animateTo(
      destino,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    widget.onCambio?.call(_frente);
    await _giro.animateTo(0, curve: Curves.easeOutCubic);
  }

  void _soltar(DragEndDetails details) {
    final velocidad = details.primaryVelocity ?? 0;
    final actual = _posicion.value;
    var destino = actual.roundToDouble();
    // Un deslizamiento rápido avanza una tarjeta aunque no se haya cruzado
    // la mitad.
    if (velocidad.abs() > 400) {
      destino = velocidad < 0
          ? actual.floorToDouble() + 1
          : actual.ceilToDouble() - 1;
    }
    _irA(destino);
  }

  @override
  Widget build(BuildContext context) {
    // Se construyen una vez por cambio de tarjeta al frente; durante la
    // animación se reutilizan tal cual, así Flutter no rehace su contenido.
    // RepaintBoundary: moverlas no obliga a volver a pintarlas.
    final tarjetas = [
      for (var i = 0; i < _n; i++)
        RepaintBoundary(
          child: widget.itemBuilder(context, i, i == _frenteConstruido),
        ),
    ];
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final ancho = min(constraints.maxWidth * 0.76, 380.0);
              _anchoArrastre = ancho;
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (_) {
                  _posicion.stop();
                  _giro.animateTo(1, curve: Curves.easeOut);
                },
                onHorizontalDragUpdate: (details) =>
                    _posicion.value -= details.delta.dx / _anchoArrastre,
                onHorizontalDragEnd: _soltar,
                child: AnimatedBuilder(
                  animation: _movimiento,
                  builder: (context, _) {
                    final orden = List.generate(_n, (i) => i)
                      ..sort(
                        (a, b) =>
                            _distancia(b).abs().compareTo(_distancia(a).abs()),
                      );
                    return Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        for (final i in orden)
                          _tarjeta(i, tarjetas[i], ancho, constraints),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
        _Indicador(
          total: _n,
          actual: _frente,
          color: widget.colorDe?.call(_frente) ?? AppColors.signalOrange,
          onAnterior: () => _irA(_posicion.value.roundToDouble() - 1),
          onSiguiente: () => _irA(_posicion.value.roundToDouble() + 1),
        ),
      ],
    );
  }

  Widget _tarjeta(
    int i,
    Widget contenido,
    double ancho,
    BoxConstraints espacio,
  ) {
    final d = _distancia(i);
    final lejania = d.abs().clamp(0.0, 1.5);
    if (lejania >= 1.5) return const SizedBox.shrink();
    final alFrente = lejania < 0.5;
    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.001)
      ..translateByDouble(d * ancho * 0.66, 0, lejania * 520, 1)
      ..rotateY(d * 0.85)
      ..scaleByDouble(1 - 0.12 * lejania, 1 - 0.12 * lejania, 1, 1);
    final g = _giro.value;
    final tarjeta = SizedBox(
      // A pantalla completa en teléfonos; en tablets con un ancho máximo.
      width: lerpDouble(min(espacio.maxWidth - 16, 640), ancho, g),
      height: lerpDouble(
        espacio.maxHeight - 8,
        min(espacio.maxHeight - 12, ancho * 1.75),
        g,
      ),
      child: contenido,
    );
    // Las vecinas solo se ven mientras gira.
    final visible = alFrente ? 1.0 : g;
    return Opacity(
      opacity: ((1 - 0.4 * lejania) * visible).clamp(0.0, 1.0),
      child: Transform(
        alignment: Alignment.center,
        transform: transform,
        child: alFrente
            ? tarjeta
            : GestureDetector(
                onTap: () => _irA(_posicion.value + d),
                child: AbsorbPointer(child: tarjeta),
              ),
      ),
    );
  }
}

class _Indicador extends StatelessWidget {
  const _Indicador({
    required this.total,
    required this.actual,
    required this.color,
    required this.onAnterior,
    required this.onSiguiente,
  });

  final int total;
  final int actual;
  final Color color;
  final VoidCallback onAnterior;
  final VoidCallback onSiguiente;

  @override
  Widget build(BuildContext context) {
    final boton = IconButton.styleFrom(
      shape: const CircleBorder(),
      side: BorderSide(color: context.paleta.borde),
      backgroundColor: context.paleta.superficie.withValues(alpha: 0.7),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Anterior',
            style: boton,
            onPressed: onAnterior,
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 12),
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == actual ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == actual ? color : context.paleta.apagado,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Siguiente',
            style: boton,
            onPressed: onSiguiente,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
