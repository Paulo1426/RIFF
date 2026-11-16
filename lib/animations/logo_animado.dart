import 'dart:math';

import 'package:flutter/material.dart';

// Capas generadas por tool/generar_capas_logo.py (coordenadas en píxeles del
// logo de 655 x 532).
const _ancho = 655.0;
const _alto = 532.0;
const _barras = [
  Rect.fromLTWH(222, 66, 37, 102),
  Rect.fromLTWH(259, 47, 41, 121),
  Rect.fromLTWH(300, 40, 37, 128),
  Rect.fromLTWH(337, 0, 57, 168),
  Rect.fromLTWH(394, 47, 36, 121),
  Rect.fromLTWH(430, 55, 38, 113),
  Rect.fromLTWH(468, 86, 31, 82),
];
const _nota = Rect.fromLTWH(129, 204, 152, 144);
const _ruta = 'lib/assets/images/logo/animado/';

/// Logo de RIFF con vida: las barras laten como un ecualizador, la nota de la
/// R se mece y los colores del triángulo giran a su alrededor. Con [t] en 0 y
/// en 1 queda exactamente igual al logo quieto.
class LogoAnimado extends StatelessWidget {
  const LogoAnimado({super.key, required this.t, this.ancho = _ancho});

  /// Avance de la animación, de 0 a 1.
  final double t;

  /// Ancho en píxeles lógicos.
  final double ancho;

  // Entra y sale suave para que el logo empiece y termine quieto.
  static double _envolvente(double t) {
    final entra = Curves.easeOut.transform((t / 0.12).clamp(0.0, 1.0));
    final sale = Curves.easeIn.transform(((1 - t) / 0.25).clamp(0.0, 1.0));
    return min(entra, sale);
  }

  @override
  Widget build(BuildContext context) {
    final e = _envolvente(t);
    final vuelta = 2 * pi * t;
    return Semantics(
      label: 'RIFF',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: ancho,
          height: ancho * _alto / _ancho,
          child: FittedBox(
            child: SizedBox(
              width: _ancho,
              height: _alto,
              child: Stack(
                children: [
                  Image.asset('${_ruta}base.png'),
                  // Los colores del triángulo: un barrido que gira.
                  Opacity(
                    opacity: e,
                    child: ShaderMask(
                      blendMode: BlendMode.srcATop,
                      shaderCallback: (rect) => SweepGradient(
                        transform: GradientRotation(vuelta * 2),
                        colors: const [
                          Color(0xA6FFD000),
                          Color(0xA6FF3D00),
                          Color(0xA600B0FF),
                          Color(0xA6FFD000),
                        ],
                      ).createShader(rect),
                      child: Image.asset('${_ruta}triangulo.png'),
                    ),
                  ),
                  for (final (i, r) in _barras.indexed)
                    Positioned.fromRect(
                      rect: r,
                      child: Transform.scale(
                        scaleY: 1 + e * 0.3 * sin(vuelta * 3 + i * 0.9),
                        alignment: Alignment.bottomCenter,
                        child: Image.asset(
                          '${_ruta}barra_${i + 1}.png',
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                  Positioned.fromRect(
                    rect: _nota,
                    child: Transform.rotate(
                      angle: e * 0.14 * sin(vuelta * 2),
                      child: Transform.scale(
                        scale: 1 + e * 0.1 * (0.5 + 0.5 * sin(vuelta * 3)),
                        child: Image.asset('${_ruta}nota.png'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pantalla de apertura: el mismo splash nativo (fondo crema, logo grande en
/// la misma posición) pero con el logo animado. Al terminar se funde y deja
/// ver [child], que se va armando debajo mientras tanto.
class IntroLogo extends StatefulWidget {
  const IntroLogo({super.key, required this.child});

  final Widget child;

  @override
  State<IntroLogo> createState() => _IntroLogoState();
}

class _IntroLogoState extends State<IntroLogo> with TickerProviderStateMixin {
  // Mismo crema que el splash nativo (android launch_background).
  static const _crema = Color(0xFFF5F5F5);
  static const _anchoSplash = 123.0;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final AnimationController _fundido = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  var _arrancada = false;
  // La pantalla de inicio se arma solo cuando el logo ya terminó: armarla
  // antes congelaba los primeros fotogramas y la animación se la comía.
  var _montada = false;
  var _quitada = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s != AnimationStatus.completed) return;
      setState(() => _montada = true);
      // El fundido empieza después del fotograma pesado de armar el inicio.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fundido.forward();
      });
    });
    _fundido.addStatusListener((s) {
      if (s == AnimationStatus.completed) setState(() => _quitada = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_arrancada) return;
    _arrancada = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _quitada = true;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _fundido.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_quitada) return widget.child;
    final media = MediaQuery.of(context);
    // Android 12+ pinta el icono del splash con el logo de ~123 dp de ancho
    // en el centro: se parte de ese tamaño y crece hasta el grande.
    final grande = min(710 / media.devicePixelRatio, media.size.width * 0.9);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_montada) widget.child,
        AbsorbPointer(
          child: FadeTransition(
            opacity: ReverseAnimation(_fundido),
            child: ColoredBox(
              color: _crema,
              child: Center(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final crece = Curves.easeOutCubic.transform(
                      (_c.value / 0.3).clamp(0.0, 1.0),
                    );
                    return LogoAnimado(
                      t: _c.value,
                      ancho: _anchoSplash + (grande - _anchoSplash) * crece,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
