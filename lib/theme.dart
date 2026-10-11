import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models/nivel.dart';

/// Paleta "arcade 8-bit sobre papel de nubes".
class AppColors {
  // Único color de acción: botones principales, énfasis, estados activos.
  static const signalOrange = Color(0xFFFF5E24);
  static const emberCrust = Color(0xFF6C3200);
  static const cloudMist = Color(0xFFE3F1FE);
  static const graphiteInk = Color(0xFF232629);
  static const paperWhite = Color(0xFFFFFFFF);
  static const slatePencil = Color(0xFF5C6066);
  static const ashMist = Color(0xFF989EA4);
  static const blushShadow = Color(0xFFDBCED0);
  static const midnightInk = Color(0xFF101828);
  static const appWindow = Color(0xFFF5F5F7);
  // Borde marcado de tarjetas sobre el cielo.
  static const cloudEdge = Color(0xFFC6DDF3);
  // Acento de cada dificultad.
  static const facil = Color(0xFF2FB463);
  static const medio = Color(0xFFFF9A1F);
  static const avanzado = Color(0xFFE53935);
}

Color colorDificultad(Dificultad dificultad) => switch (dificultad) {
  Dificultad.facil => AppColors.facil,
  Dificultad.medio => AppColors.medio,
  Dificultad.avanzado => AppColors.avanzado,
};

/// Sombra suave en capas, tintada de azul noche.
const sombraTarjeta = [
  BoxShadow(color: Color(0x050F2234), offset: Offset(0, 27), blurRadius: 11),
  BoxShadow(color: Color(0x0A0F2234), offset: Offset(0, 15), blurRadius: 9),
  BoxShadow(color: Color(0x140F2234), offset: Offset(0, 7), blurRadius: 7),
  BoxShadow(color: Color(0x140F2234), offset: Offset(0, 2), blurRadius: 4),
];

const radioVidrio = 16.0;

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.graphiteInk,
    onPrimary: AppColors.paperWhite,
    primaryContainer: AppColors.cloudMist,
    onPrimaryContainer: AppColors.graphiteInk,
    secondary: AppColors.signalOrange,
    onSecondary: AppColors.paperWhite,
    secondaryContainer: AppColors.cloudMist,
    onSecondaryContainer: AppColors.graphiteInk,
    tertiary: AppColors.emberCrust,
    onTertiary: AppColors.paperWhite,
    surface: AppColors.cloudMist,
    onSurface: AppColors.graphiteInk,
    onSurfaceVariant: AppColors.slatePencil,
    surfaceContainerLowest: AppColors.paperWhite,
    surfaceContainerLow: AppColors.paperWhite,
    surfaceContainer: AppColors.paperWhite,
    surfaceContainerHigh: AppColors.paperWhite,
    surfaceContainerHighest: AppColors.appWindow,
    outline: AppColors.ashMist,
    outlineVariant: AppColors.cloudEdge,
    error: Color(0xFFD92D20),
    onError: AppColors.paperWhite,
  );

  // Manrope para todo lo que se lee; Jersey 10 (pixel) solo para títulos
  // grandes, nunca en textos chicos.
  final base = GoogleFonts.manropeTextTheme(
    ThemeData(brightness: Brightness.light).textTheme,
  );
  TextStyle pixel(TextStyle? s, double size) => GoogleFonts.jersey10(
    textStyle: s,
    fontSize: size,
    height: 1,
    letterSpacing: -size * 0.025,
  );
  TextStyle? peso(TextStyle? s, FontWeight w) => s?.copyWith(fontWeight: w);
  final textTheme = base
      .copyWith(
        displayLarge: pixel(base.displayLarge, 96),
        displayMedium: pixel(base.displayMedium, 72),
        displaySmall: pixel(base.displaySmall, 60),
        headlineLarge: pixel(base.headlineLarge, 48),
        headlineMedium: pixel(base.headlineMedium, 42),
        headlineSmall: pixel(base.headlineSmall, 36),
        titleLarge: peso(base.titleLarge, FontWeight.w700),
        titleMedium: peso(base.titleMedium, FontWeight.w700),
        titleSmall: peso(base.titleSmall, FontWeight.w600),
        labelLarge: peso(base.labelLarge, FontWeight.w600),
        bodyLarge: peso(base.bodyLarge, FontWeight.w400),
        bodyMedium: peso(base.bodyMedium, FontWeight.w400),
      )
      .apply(
        bodyColor: AppColors.graphiteInk,
        displayColor: AppColors.graphiteInk,
      );

  // Controles con esquinas de 6px; tarjetas de 16px.
  final control = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(6),
  );
  const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.cloudEdge),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.cloudMist,
    textTheme: textTheme,
    // Transición suave (deslizar + desvanecer) entre pantallas.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.cloudMist,
      foregroundColor: AppColors.graphiteInk,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: pixel(base.titleLarge, 36),
    ),
    cardTheme: CardThemeData(
      color: AppColors.paperWhite.withValues(alpha: 0.82),
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: const Color(0x330F2234),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radioVidrio),
        side: const BorderSide(color: AppColors.cloudEdge, width: 1.2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      // Naranja es el único color de acción.
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.signalOrange,
        foregroundColor: AppColors.paperWhite,
        disabledBackgroundColor: AppColors.cloudEdge,
        disabledForegroundColor: AppColors.slatePencil,
        shape: control,
        padding: buttonPadding,
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.paperWhite.withValues(alpha: 0.75),
        foregroundColor: AppColors.graphiteInk,
        side: const BorderSide(color: AppColors.cloudEdge, width: 1.2),
        shape: control,
        padding: buttonPadding,
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.graphiteInk,
        shape: control,
        textStyle: textTheme.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(shape: control),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.paperWhite.withValues(alpha: 0.85),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.signalOrange, width: 1.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.cloudMist,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.paperWhite,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shadowColor: const Color(0x330F2234),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radioVidrio),
        side: const BorderSide(color: AppColors.cloudEdge),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.cloudEdge),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.signalOrange,
      linearTrackColor: AppColors.cloudEdge,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.graphiteInk,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: AppColors.paperWhite,
      ),
      shape: control,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Fondo de recuadro blanco translúcido con un acento de color que nace en
/// la esquina superior izquierda, igual que el del fondo de la app.
Gradient fondoConAcento(Color acento, {double opacidad = 0.8}) {
  final base = AppColors.paperWhite.withValues(alpha: opacidad);
  return RadialGradient(
    center: Alignment.topLeft,
    radius: 1.4,
    colors: [Color.alphaBlend(acento.withValues(alpha: 0.24), base), base],
  );
}

/// Vidrio líquido: desenfoca lo de atrás bajo un blanco translúcido, con un
/// brillo arriba (reflejo), borde de luz y sombra suave.
class Vidrio extends StatelessWidget {
  const Vidrio({
    super.key,
    required this.child,
    this.radio = radioVidrio,
    this.tinte,
    this.borde,
    this.padding,
  });

  final Widget child;
  final double radio;
  final Color? tinte;
  final Color? borde;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(radio);
    final base = tinte ?? AppColors.paperWhite;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: forma, boxShadow: sombraTarjeta),
      child: ClipRRect(
        borderRadius: forma,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: forma,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    base.withValues(alpha: 0.22),
                    AppColors.paperWhite.withValues(alpha: 0.68),
                  ),
                  Color.alphaBlend(
                    base.withValues(alpha: 0.16),
                    AppColors.paperWhite.withValues(alpha: 0.32),
                  ),
                ],
              ),
              border: Border.all(
                color: borde ?? AppColors.paperWhite.withValues(alpha: 0.95),
                width: borde == null ? 1.4 : 2,
              ),
            ),
            child: Stack(
              children: [
                // Reflejo: franja clara que se desvanece hacia abajo.
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: forma,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0, 0.35],
                          colors: [
                            AppColors.paperWhite.withValues(alpha: 0.55),
                            AppColors.paperWhite.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(padding: padding ?? EdgeInsets.zero, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cielo de nubes con manchas de color para que el vidrio tenga algo que
/// desenfocar. [acento] tiñe el fondo (p. ej. con el color de la dificultad)
/// y cambia con una transición suave.
class FondoRiff extends StatelessWidget {
  const FondoRiff({super.key, required this.child, this.acento});

  final Widget child;
  final Color? acento;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<Color?>(
    tween: ColorTween(end: acento ?? AppColors.signalOrange),
    duration: const Duration(milliseconds: 500),
    curve: Curves.easeInOut,
    builder: (context, color, child) =>
        CustomPaint(painter: _FondoPainter(color!), child: child),
    child: child,
  );
}

class _FondoPainter extends CustomPainter {
  const _FondoPainter(this.acento);

  final Color acento;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (x, y, r, color, alpha) in [
      (0.0, 0.05, 0.8, acento, 0.22),
      (1.0, 0.5, 0.75, AppColors.paperWhite, 0.9),
      (0.15, 1.0, 0.8, acento, 0.16),
    ]) {
      final center = Offset(size.width * x, size.height * y);
      final radius = size.width * r;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_FondoPainter oldDelegate) => oldDelegate.acento != acento;
}

/// Disco de vinilo estilo rockola; gira mientras [girando] es true.
class DiscoGirando extends StatefulWidget {
  const DiscoGirando({super.key, this.size = 40, this.girando = true});

  final double size;
  final bool girando;

  @override
  State<DiscoGirando> createState() => _DiscoGirandoState();
}

class _DiscoGirandoState extends State<DiscoGirando>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  @override
  void initState() {
    super.initState();
    if (widget.girando) _controller.repeat();
  }

  @override
  void didUpdateWidget(DiscoGirando oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.girando && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.girando) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _controller,
    child: CustomPaint(
      size: Size.square(widget.size),
      painter: _DiscoPainter(),
    ),
  );
}

class _DiscoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(center, r, Paint()..color = AppColors.graphiteInk);
    final surco = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.03
      ..color = AppColors.paperWhite.withValues(alpha: 0.12);
    for (final f in [0.85, 0.7, 0.55]) {
      canvas.drawCircle(center, r * f, surco);
    }
    // Brillo asimétrico: sin él no se notaría que el disco gira.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r * 0.95),
      -pi / 3,
      pi / 5,
      true,
      Paint()..color = AppColors.paperWhite.withValues(alpha: 0.18),
    );
    canvas.drawCircle(
      center,
      r * 0.36,
      Paint()..color = AppColors.signalOrange,
    );
    canvas.drawCircle(
      center + Offset(r * 0.2, 0),
      r * 0.06,
      Paint()..color = AppColors.graphiteInk,
    );
    canvas.drawCircle(center, r * 0.07, Paint()..color = AppColors.cloudMist);
  }

  @override
  bool shouldRepaint(_DiscoPainter oldDelegate) => false;
}

/// Pantalla de carga con el disco girando.
class Cargando extends StatelessWidget {
  const Cargando({super.key, this.texto = 'Cargando...'});

  final String texto;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DiscoGirando(size: 72),
        const SizedBox(height: 16),
        Text(
          texto,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.slatePencil),
        ),
      ],
    ),
  );
}

/// Cubre la pantalla con el disco girando mientras [cargando] es true.
class ConCarga extends StatelessWidget {
  const ConCarga({
    super.key,
    required this.cargando,
    required this.texto,
    required this.child,
  });

  final bool cargando;
  final String texto;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      Positioned.fill(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          // ColoredBox bloquea los toques mientras carga.
          child: cargando
              ? ColoredBox(
                  color: AppColors.cloudMist.withValues(alpha: 0.9),
                  child: Cargando(texto: texto),
                )
              : const SizedBox.shrink(),
        ),
      ),
    ],
  );
}

/// Barras de ecualizador que se mueven mientras [activo] es true.
class BarrasSonido extends StatefulWidget {
  const BarrasSonido({
    super.key,
    this.activo = true,
    this.color = AppColors.graphiteInk,
    this.width = 64,
    this.height = 26,
  });

  final bool activo;
  final Color color;
  final double width;
  final double height;

  @override
  State<BarrasSonido> createState() => _BarrasSonidoState();
}

class _BarrasSonidoState extends State<BarrasSonido>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.activo) _controller.repeat();
  }

  @override
  void didUpdateWidget(BarrasSonido oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activo && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.activo) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.activo ? 'Sonando' : 'En pausa',
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size(widget.width, widget.height),
        painter: _BarrasPainter(_controller.value, widget.color),
      ),
    ),
  );
}

class _BarrasPainter extends CustomPainter {
  const _BarrasPainter(this.t, this.color);

  final double t;
  final Color color;

  static const _barras = 9;

  @override
  void paint(Canvas canvas, Size size) {
    final grosor = size.width / (_barras * 2);
    final base = size.height - grosor / 2;
    final pincel = Paint()
      ..color = color
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, base), Offset(size.width, base), pincel);
    for (var i = 0; i < _barras; i++) {
      // Cada barra oscila con su propia velocidad y fase; las velocidades
      // son enteras para que el ciclo empalme sin saltos.
      final onda = sin(2 * pi * (t * (1 + i % 3) + i * 0.37));
      final alto = (0.35 + 0.65 * (onda + 1) / 2) * (base - grosor * 1.5);
      final x = grosor * (1 + 2 * i);
      canvas.drawLine(
        Offset(x, base - grosor),
        Offset(x, base - grosor - alto),
        pincel,
      );
    }
  }

  @override
  bool shouldRepaint(_BarrasPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.color != color;
}

/// Banda animada: los instrumentos se mecen al ritmo y sueltan notas que
/// suben y se desvanecen. Llena el espacio libre bajo la lista de niveles.
class BandaMusical extends StatefulWidget {
  const BandaMusical({super.key, this.color = AppColors.signalOrange});

  final Color color;

  @override
  State<BandaMusical> createState() => _BandaMusicalState();
}

class _BandaMusicalState extends State<BandaMusical>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  static const _instrumentos = ['🪗', '🥁', '🎸', '🎵'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: LayoutBuilder(
      builder: (context, espacio) {
        final tamano = min(44.0, espacio.maxHeight * 0.38);
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            return Stack(
              children: [
                for (var i = 0; i < _instrumentos.length; i++) ...[
                  // Nota que sube desde cada instrumento, desfasada.
                  for (final desfase in [0.0, 0.5])
                    _nota(i, (t * 2 + i * 0.27 + desfase) % 1, espacio, tamano),
                  Align(
                    alignment: Alignment(-0.75 + i * 0.5, 0.85),
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        -sin(2 * pi * (t * 2 + i * 0.25)).abs() * tamano * 0.25,
                      ),
                      child: Transform.rotate(
                        angle: sin(2 * pi * (t + i * 0.25)) * 0.12,
                        child: Text(
                          _instrumentos[i],
                          style: TextStyle(fontSize: tamano),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    ),
  );

  Widget _nota(int i, double avance, BoxConstraints espacio, double tamano) {
    final x = -0.75 + i * 0.5 + sin(avance * 2 * pi) * 0.08;
    final y = 0.6 - avance * 1.6;
    return Align(
      alignment: Alignment(x, y),
      child: Opacity(
        opacity: (1 - avance).clamp(0.0, 1.0) * 0.8,
        child: Icon(
          i.isEven ? Icons.music_note_rounded : Icons.audiotrack_rounded,
          size: tamano * 0.5,
          color: widget.color,
        ),
      ),
    );
  }
}
