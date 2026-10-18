import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models/nivel.dart';

/// Paleta "arcade 8-bit sobre papel de nubes".
class AppColors {
  // Único color de acción: botones principales, énfasis, estados activos.
  static const signalOrange = Color(0xFFFF6B35);
  static const emberCrust = Color(0xFF6C3200);
  // Fondo gris claro de la app.
  static const cloudMist = Color(0xFFF5F5F5);
  static const graphiteInk = Color(0xFF232629);
  static const paperWhite = Color(0xFFFFFFFF);
  static const slatePencil = Color(0xFF5C6066);
  static const ashMist = Color(0xFF989EA4);
  static const blushShadow = Color(0xFFDBCED0);
  static const midnightInk = Color(0xFF101828);
  static const appWindow = Color(0xFFF5F5F7);
  // Borde marcado de tarjetas sobre el cielo.
  static const cloudEdge = Color(0xFFDCE5E0);
  // Acento de cada dificultad.
  // Verde de la marca; también es el acento de Fácil.
  static const verde = Color(0xFF2ECC71);
  static const facil = verde;
  static const medio = Color(0xFFFFD100);
  static const avanzado = Color(0xFFCE1126);
}

Color colorDificultad(Dificultad dificultad) => switch (dificultad) {
  Dificultad.facil => AppColors.facil,
  Dificultad.medio => AppColors.medio,
  Dificultad.avanzado => AppColors.avanzado,
};

/// Neutros que cambian entre modo claro y oscuro. Los acentos de marca
/// (naranja, verde y colores de dificultad) siguen en [AppColors] y son
/// iguales en los dos modos.
class Paleta extends ThemeExtension<Paleta> {
  const Paleta({
    required this.oscuro,
    required this.fondo,
    required this.superficie,
    required this.tinta,
    required this.tintaSuave,
    required this.borde,
    required this.apagado,
    required this.ventana,
    required this.vidrio,
    required this.brillo,
  });

  static const claro = Paleta(
    oscuro: false,
    fondo: AppColors.cloudMist,
    superficie: AppColors.paperWhite,
    tinta: AppColors.graphiteInk,
    tintaSuave: AppColors.slatePencil,
    borde: AppColors.cloudEdge,
    apagado: AppColors.ashMist,
    ventana: AppColors.appWindow,
    vidrio: Colors.white,
    brillo: Colors.white,
  );

  static const noche = Paleta(
    oscuro: true,
    fondo: Color(0xFF121417),
    superficie: Color(0xFF1E2126),
    tinta: Color(0xFFECEEF0),
    tintaSuave: Color(0xFFA4AAB0),
    borde: Color(0xFF353A42),
    apagado: Color(0xFF6B7178),
    ventana: Color(0xFF1A1D21),
    // Vidrio ahumado: mismas opacidades que el claro, sobre gris oscuro.
    vidrio: Color(0xFF262A31),
    brillo: Color(0xFF7A828C),
  );

  final bool oscuro;
  final Color fondo;
  final Color superficie;
  final Color tinta;
  final Color tintaSuave;
  final Color borde;
  final Color apagado;
  final Color ventana;
  // Relleno del vidrio y luz de sus bordes.
  final Color vidrio;
  final Color brillo;

  /// Color de acento ajustado para usarlo en textos: en claro se oscurece
  /// porque el amarillo de Medio no se lee sobre fondo claro; en oscuro casi
  /// no cambia porque los acentos ya contrastan.
  Color tonoTexto(Color acento) =>
      Color.lerp(acento, tinta, oscuro ? 0.1 : 0.4)!;

  @override
  Paleta copyWith() => this;

  @override
  Paleta lerp(Paleta? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

extension PaletaDeContexto on BuildContext {
  Paleta get paleta => Theme.of(this).extension<Paleta>() ?? Paleta.claro;
}

const radioVidrio = 16.0;

ThemeData buildAppTheme({bool oscuro = false}) {
  final p = oscuro ? Paleta.noche : Paleta.claro;
  final scheme = ColorScheme(
    brightness: oscuro ? Brightness.dark : Brightness.light,
    primary: p.tinta,
    onPrimary: p.superficie,
    primaryContainer: p.fondo,
    onPrimaryContainer: p.tinta,
    secondary: AppColors.signalOrange,
    onSecondary: AppColors.paperWhite,
    secondaryContainer: p.fondo,
    onSecondaryContainer: p.tinta,
    tertiary: AppColors.emberCrust,
    onTertiary: AppColors.paperWhite,
    surface: p.fondo,
    onSurface: p.tinta,
    onSurfaceVariant: p.tintaSuave,
    surfaceContainerLowest: p.superficie,
    surfaceContainerLow: p.superficie,
    surfaceContainer: p.superficie,
    surfaceContainerHigh: p.superficie,
    surfaceContainerHighest: p.ventana,
    outline: p.apagado,
    outlineVariant: p.borde,
    error: const Color(0xFFD92D20),
    onError: AppColors.paperWhite,
  );

  // Manrope para todo lo que se lee; Jersey 10 (pixel) solo para títulos
  // grandes, nunca en textos chicos.
  final base = GoogleFonts.manropeTextTheme(
    ThemeData(brightness: scheme.brightness).textTheme,
  );
  TextStyle pixel(TextStyle? s, double size) => GoogleFonts.jersey10(
    textStyle: s,
    fontSize: size,
    height: 1,
    // Letras pixel separadas: más legibles que juntas.
    letterSpacing: size * 0.04,
  );
  // Manrope con un poco más de aire entre letras para leer mejor.
  TextStyle? aire(TextStyle? s) =>
      s?.copyWith(letterSpacing: (s.letterSpacing ?? 0) + 0.4);
  TextStyle? peso(TextStyle? s, FontWeight w) =>
      aire(s)?.copyWith(fontWeight: w);
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
        bodySmall: aire(base.bodySmall),
        labelMedium: aire(base.labelMedium),
        labelSmall: aire(base.labelSmall),
      )
      .apply(bodyColor: p.tinta, displayColor: p.tinta);

  // Controles con esquinas de 6px; tarjetas de 16px.
  final control = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(6),
  );
  const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: p.borde),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    extensions: [p],
    scaffoldBackgroundColor: p.fondo,
    textTheme: textTheme,
    // Transición suave (deslizar + desvanecer) entre pantallas.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.fondo,
      foregroundColor: p.tinta,
      // Iconos de la barra de estado legibles sobre el fondo de cada modo.
      systemOverlayStyle: oscuro
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: pixel(base.titleLarge, 36),
    ),
    cardTheme: CardThemeData(
      color: p.superficie.withValues(alpha: 0.82),
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: const Color(0x330F2234),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radioVidrio),
        side: BorderSide(color: p.borde, width: 1.2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      // Naranja es el único color de acción.
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.signalOrange,
        foregroundColor: AppColors.paperWhite,
        disabledBackgroundColor: p.borde,
        disabledForegroundColor: p.tintaSuave,
        shape: control,
        padding: buttonPadding,
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: p.superficie.withValues(alpha: 0.75),
        foregroundColor: p.tinta,
        side: BorderSide(color: p.borde, width: 1.2),
        shape: control,
        padding: buttonPadding,
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.tinta,
        shape: control,
        textStyle: textTheme.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(shape: control),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.superficie.withValues(alpha: 0.85),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.signalOrange, width: 1.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.fondo,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.superficie,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shadowColor: const Color(0x330F2234),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radioVidrio),
        side: BorderSide(color: p.borde),
      ),
    ),
    dividerTheme: DividerThemeData(color: p.borde),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.signalOrange,
      linearTrackColor: p.borde,
    ),
    snackBarTheme: SnackBarThemeData(
      // Invertido respecto al fondo para que destaque en los dos modos.
      backgroundColor: p.tinta,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: p.superficie),
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
          ).textTheme.bodyMedium?.copyWith(color: context.paleta.tintaSuave),
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
                  color: context.paleta.fondo.withValues(alpha: 0.9),
                  child: Cargando(texto: texto),
                )
              : const SizedBox.shrink(),
        ),
      ),
    ],
  );
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
