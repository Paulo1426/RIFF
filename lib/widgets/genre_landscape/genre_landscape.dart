import 'package:flutter/material.dart';

import '../../animations/ciclo_lento.dart';
import '../../models/genero.dart';
import 'escenas/intros.dart';
import 'escenas/popular.dart';
import 'escenas/reggaeton.dart';
import 'escenas/rock_pop.dart';
import 'escenas/salsa.dart';
import 'escenas/vallenato.dart';
import 'shared/landscape_shapes.dart';

/// Escena y duración de su ciclo, por género y nivel (1 a 3).
final _escenas = <Genero, List<(Escena, int)>>{
  Genero.vallenato: [
    (vallenatoSierra, 40),
    (vallenatoGuajira, 12),
    (vallenatoPueblo, 6),
  ],
  Genero.reggaeton: [
    (reggaetonCiudad, 6),
    (reggaetonLadera, 30),
    (reggaetonCosta, 8),
  ],
  Genero.salsa: [(salsaCali, 8), (salsaNuevaYork, 10), (salsaMalecon, 8)],
  Genero.rockPop: [(rockConcierto, 10), (rockFestival, 4), (rockSynthwave, 6)],
  Genero.popular: [
    (popularCafetero, 40),
    (popularMexico, 40),
    (popularCarrilera, 5),
  ],
};

/// Género del paisaje. En Medley es el de la canción (su id empieza por
/// "salsa--"); si [semilla] no lo dice, uno estable según ella.
Genero generoParaPaisaje(Genero genero, String semilla) {
  if (!genero.esPopurri) return genero;
  return Genero.reales
          .where((g) => semilla.startsWith('${g.id}--'))
          .firstOrNull ??
      Genero.reales[semilla.hashCode.abs() % Genero.reales.length];
}

/// [child] con [fondo] detrás, anclado abajo. Va por fuera del Scaffold para
/// que el teclado no lo mueva, solo lo tape.
class ConFondo extends StatelessWidget {
  const ConFondo({
    super.key,
    required this.fondo,
    required this.child,
    this.visible = true,
  });

  final Widget fondo;
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (visible) Positioned(left: 0, right: 0, bottom: 0, child: fondo),
      child,
    ],
  );
}

/// [child] con el paisaje del nivel detrás.
class ConPaisaje extends StatelessWidget {
  const ConPaisaje({
    super.key,
    required this.genero,
    required this.level,
    required this.child,
    this.visible = true,
  });

  final Genero genero;
  final int level;
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => ConFondo(
    visible: visible,
    fondo: GenreLandscape(genero: genero, level: level),
    child: child,
  );
}

/// Fondo de la pantalla "Adivina la intro" de un género (Medley incluido), o
/// de las salas: estudio de radio (intros) o escenario de concurso (canción).
class FondoIntros extends StatelessWidget {
  const FondoIntros.genero(Genero this.genero, {super.key})
    : salaDeIntros = null;
  const FondoIntros.sala({super.key, required bool intros})
    : genero = null,
      salaDeIntros = intros;

  final Genero? genero;
  final bool? salaDeIntros;

  @override
  Widget build(BuildContext context) => FondoDecorativo(
    clave: genero ?? salaDeIntros,
    escena: genero != null
        ? escenaIntros(genero!)
        : salaDeIntros!
        ? introRadio
        : introConcurso,
    opacity: 0.18,
    alto: 0.35,
  );
}

/// Paisaje decorativo de fondo, tenue, anclado abajo: no recibe toques ni
/// lee el teclado, así que no se mueve cuando este abre. Ponerlo detrás del
/// contenido, en un Positioned(left: 0, right: 0, bottom: 0).
/// En Medley hay que pasar el género de la canción, no el del menú.
class GenreLandscape extends StatelessWidget {
  const GenreLandscape({
    super.key,
    required this.genero,
    required this.level,
    this.opacity = 0.18,
  });

  final Genero genero;
  // 1, 2 o 3; fuera de rango se repite en ciclo.
  final int level;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final indice = (level - 1) % 3;
    final (escena, segundos) =
        (_escenas[genero] ?? _escenas[Genero.vallenato]!)[indice];
    return FondoDecorativo(
      clave: (genero, indice),
      escena: escena,
      segundos: segundos,
      opacity: opacity,
    );
  }
}

/// Escena tenue: sin toques, sin semántica y con el borde de arriba fundido.
/// [segundos] 0 la deja quieta.
class FondoDecorativo extends StatelessWidget {
  const FondoDecorativo({
    super.key,
    required this.clave,
    required this.escena,
    this.segundos = 0,
    this.opacity = 0.2,
    this.alto = 0.38,
  });

  // Cambia cuando la escena cambia: dispara el fundido entre una y otra.
  final Object? clave;
  final Escena escena;
  final int segundos;
  final double opacity;
  // Fracción del alto de la pantalla.
  final double alto;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          width: double.infinity,
          // sizeOf no cambia con el teclado.
          height: MediaQuery.sizeOf(context).height * alto,
          child: Opacity(
            opacity: opacity,
            child: ShaderMask(
              // Transparente arriba: el borde superior se funde con el fondo.
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
                stops: [0, 0.45],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _Paisaje(
                  key: ValueKey(clave),
                  escena: escena,
                  periodo: Duration(seconds: segundos),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Paisaje extends StatefulWidget {
  const _Paisaje({super.key, required this.escena, required this.periodo});

  final Escena escena;
  final Duration periodo;

  @override
  State<_Paisaje> createState() => _PaisajeState();
}

class _PaisajeState extends State<_Paisaje> {
  late final _ciclo = CicloLento(
    // Un ciclo de 0 no se usa: la escena quieta nunca lo activa.
    periodo: widget.periodo == Duration.zero
        ? const Duration(seconds: 1)
        : widget.periodo,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Estático con "reducir animaciones", con la pantalla tapada o si la
    // escena no se anima.
    _ciclo.activo =
        widget.periodo != Duration.zero &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: CustomPaint(painter: _PaisajePainter(_ciclo, widget.escena)),
  );
}

class _PaisajePainter extends CustomPainter {
  _PaisajePainter(this.ciclo, this.escena) : super(repaint: ciclo);

  final CicloLento ciclo;
  final Escena escena;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    escena(canvas, size, ciclo.value);
  }

  @override
  bool shouldRepaint(_PaisajePainter old) => old.escena != escena;
}
