import 'package:riff/iconos_phosphor.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'animations/ciclo_lento.dart';
import 'data/curiosidades.dart';
import 'models/genero.dart';
import 'models/logros.dart';
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
  // Borde y letras de la insignia Vallenatólogo.
  static const oro = Color(0xFFD4AF37);
}

/// Insignias: verde las fáciles, amarillo las medias y rojo las difíciles.
Color colorInsignia(NivelInsignia nivel) => switch (nivel) {
  NivelInsignia.facil => AppColors.facil,
  NivelInsignia.media => AppColors.medio,
  NivelInsignia.dificil => AppColors.avanzado,
};

Color colorDificultad(Dificultad dificultad) => switch (dificultad) {
  Dificultad.facil => AppColors.facil,
  Dificultad.medio => AppColors.medio,
  Dificultad.avanzado => AppColors.avanzado,
};

/// Color de cada género en el selector y en su menú.
Color colorGenero(Genero genero) => switch (genero) {
  Genero.vallenato => const Color(0xFFFF8C42),
  Genero.reggaeton => const Color(0xFF00827C),
  Genero.rockPop => const Color(0xFFA6D600),
  Genero.salsa => const Color(0xFF9B30FF),
  Genero.popular => const Color(0xFFD81B8F),
  Genero.aleatorio => colorAleatorio,
};

/// Colores del menú de cada género: tarjetas de Progreso e Intro, las dos
/// manchas del fondo que no siguen al acento y la gota de la barra de abajo
/// (en el menú y en las demás pestañas). Ningún color de tarjeta se parece al
/// verde, amarillo o rojo de las dificultades. Vallenato usa colores vivos y
/// juguetones (mandarina, turquesa, azul cielo, amarillo sol y morado);
/// reggaetón, abisal y bioluminiscente (verde azulado, alga profunda, aguamarina
/// y lavanda);
/// rock / pop, verde lima eléctrico (con amarillo sol y tinta carbón), que no
/// se parece al azul del login ni al de otro género; salsa, casete de neón (violeta eléctrico sobre negro tinta y
/// arena); popular, fucsia (rosa mexicano) con azul medianoche y gris
/// niebla; Medley, turquesa con violeta, rosa y amarillo. Cada uno tiene la
/// suya.
({
  Color progreso,
  Color intro,
  Color mancha1,
  Color mancha2,
  Color barraMenu,
  Color barraSecciones,
})
paletaGenero(Genero genero) => switch (genero) {
  Genero.vallenato => (
    progreso: const Color(0xFF4ECDC4),
    intro: const Color(0xFF4D96FF),
    mancha1: const Color(0xFFFFD93D),
    mancha2: const Color(0xFF845EF7),
    barraMenu: const Color(0xFFFF8C42),
    barraSecciones: const Color(0xFF845EF7),
  ),
  Genero.reggaeton => (
    progreso: const Color(0xFF003734),
    intro: const Color(0xFF4FB3AC),
    mancha1: const Color(0xFFCBFFFC),
    mancha2: const Color(0xFFFAD1FF),
    barraMenu: const Color(0xFF00827C),
    barraSecciones: const Color(0xFF003734),
  ),
  Genero.rockPop => (
    progreso: const Color(0xFF333333),
    intro: const Color(0xFF8DB600),
    mancha1: const Color(0xFFFFE600),
    mancha2: const Color(0xFFA6D600),
    barraMenu: const Color(0xFFA6D600),
    barraSecciones: const Color(0xFF7FA300),
  ),
  Genero.salsa => (
    progreso: const Color(0xFFD9D7CE),
    intro: const Color(0xFF19181A),
    mancha1: const Color(0xFF9B30FF),
    mancha2: const Color(0xFF19181A),
    barraMenu: const Color(0xFF9B30FF),
    barraSecciones: const Color(0xFF19181A),
  ),
  Genero.popular => (
    progreso: const Color(0xFF162136),
    intro: const Color(0xFF0073D3),
    mancha1: const Color(0xFFFF5CC0),
    mancha2: const Color(0xFFBFC7D9),
    barraMenu: const Color(0xFFD81B8F),
    barraSecciones: const Color(0xFF162136),
  ),
  Genero.aleatorio => (
    progreso: const Color(0xFF7C4DFF),
    intro: const Color(0xFFFF4081),
    mancha1: const Color(0xFFFFD740),
    mancha2: const Color(0xFF7C4DFF),
    barraMenu: colorAleatorio,
    barraSecciones: const Color(0xFF7C4DFF),
  ),
};

/// Títulos (barra, tarjetas, encabezados) con el color de [genero]; en modo
/// claro, su tono legible. El texto corrido no cambia. Lo usan el menú del
/// género y los reproductores.
ThemeData temaGenero(BuildContext context, Genero genero) {
  final tema = Theme.of(context);
  final color = context.paleta.tonoTexto(colorGenero(genero));
  final t = tema.textTheme;
  TextStyle? tenir(TextStyle? estilo) => estilo?.copyWith(color: color);
  return tema.copyWith(
    textTheme: t.copyWith(
      displayLarge: tenir(t.displayLarge),
      displayMedium: tenir(t.displayMedium),
      displaySmall: tenir(t.displaySmall),
      headlineLarge: tenir(t.headlineLarge),
      headlineMedium: tenir(t.headlineMedium),
      headlineSmall: tenir(t.headlineSmall),
      titleLarge: tenir(t.titleLarge),
      titleMedium: tenir(t.titleMedium),
    ),
    appBarTheme: tema.appBarTheme.copyWith(
      titleTextStyle: tenir(tema.appBarTheme.titleTextStyle),
    ),
  );
}

/// Tarjeta "Aleatorio" del selector de géneros.
const colorAleatorio = Color(0xFF00BFA5);

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
      oscuro ? legible(acento) : Color.lerp(acento, tinta, 0.4)!;

  /// En oscuro aclara los colores muy apagados (negro tinta, verde azulado
  /// profundo, azul medianoche) hasta que se vean sobre el fondo; en claro
  /// los deja igual.
  Color legible(Color c) {
    if (!oscuro) return c;
    var r = c;
    for (var i = 0; i < 10 && r.computeLuminance() < 0.22; i++) {
      r = Color.lerp(r, tinta, 0.12)!;
    }
    return r;
  }

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
  // Azul de la app (el del logo y el login): marino en claro, celeste en
  // oscuro para que se lea sobre el fondo.
  final titulos = oscuro ? const Color(0xFF9CC8F7) : const Color(0xFF123A7A);
  final conTitulos = base
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
      .apply(bodyColor: p.tinta, displayColor: titulos);
  // Los títulos medianos también van en azul; cada género los tiñe con el suyo.
  final textTheme = conTitulos.copyWith(
    titleLarge: conTitulos.titleLarge?.copyWith(color: titulos),
    titleMedium: conTitulos.titleMedium?.copyWith(color: titulos),
  );

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
      titleTextStyle: pixel(base.titleLarge, 36).copyWith(color: titulos),
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

/// Casete naranja de la intro; los carretes giran mientras [girando] es true.
class CaseteGirando extends StatefulWidget {
  const CaseteGirando({super.key, this.ancho = 200, this.girando = true});

  final double ancho;
  final bool girando;

  @override
  State<CaseteGirando> createState() => _CaseteGirandoState();
}

class _CaseteGirandoState extends State<CaseteGirando>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void initState() {
    super.initState();
    if (widget.girando) _controller.repeat();
  }

  @override
  void didUpdateWidget(CaseteGirando oldWidget) {
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
  Widget build(BuildContext context) => CustomPaint(
    size: Size(widget.ancho, widget.ancho / 1.6),
    painter: _CasetePainter(_controller),
  );
}

class _CasetePainter extends CustomPainter {
  _CasetePainter(this.fase) : super(repaint: fase);

  final Animation<double> fase;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    Paint p(Color c) => Paint()..color = c;
    // Carcasa de plástico ahumado.
    final cuerpo = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(w * 0.04),
    );
    canvas
      ..drawRRect(cuerpo, p(const Color(0xFFCFC7C2)))
      ..drawRRect(
        cuerpo,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.012
          ..color = const Color(0xFF8D8581),
      );
    // Tornillos.
    for (final o in [
      Offset(w * 0.05, h * 0.07),
      Offset(w * 0.95, h * 0.07),
      Offset(w * 0.05, h * 0.93),
      Offset(w * 0.95, h * 0.93),
    ]) {
      canvas.drawCircle(o, w * 0.016, p(const Color(0xFF4A4542)));
    }
    // Etiqueta blanca con franja naranja.
    final etiqueta = Rect.fromLTWH(w * 0.09, h * 0.1, w * 0.82, h * 0.58);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(etiqueta, Radius.circular(w * 0.015)),
        p(const Color(0xFFF6F2EC)),
      )
      ..drawRect(
        Rect.fromLTWH(etiqueta.left, h * 0.3, etiqueta.width, h * 0.38),
        p(AppColors.signalOrange),
      );
    for (final y in [0.16, 0.22]) {
      canvas.drawLine(
        Offset(etiqueta.left + w * 0.04, h * y),
        Offset(etiqueta.right - w * 0.04, h * y),
        Paint()
          ..color = const Color(0xFFB9B2AB)
          ..strokeWidth = h * 0.012,
      );
    }
    // Ventana con la cinta y los dos carretes.
    final ventana = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.2, h * 0.34, w * 0.6, h * 0.3),
      Radius.circular(h * 0.15),
    );
    canvas.drawRRect(ventana, p(const Color(0xFF3A3532)));
    final giro = fase.value * 2 * pi;
    for (final x in [0.34, 0.66]) {
      final c = Offset(w * x, h * 0.49);
      final r = h * 0.1;
      canvas
        ..drawCircle(c, r * 1.25, p(const Color(0xFF6B4A33)))
        ..drawCircle(c, r, p(const Color(0xFFF1EEE9)));
      final diente = Paint()
        ..color = const Color(0xFF3A3532)
        ..strokeWidth = r * 0.22
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 6; i++) {
        final a = giro + i * pi / 3;
        canvas.drawLine(
          c + Offset(cos(a), sin(a)) * r * 0.45,
          c + Offset(cos(a), sin(a)) * r * 0.85,
          diente,
        );
      }
    }
    // Parte baja trapezoidal con dos agujeros.
    canvas
      ..drawPath(
        Path()
          ..moveTo(w * 0.2, h)
          ..lineTo(w * 0.28, h * 0.74)
          ..lineTo(w * 0.72, h * 0.74)
          ..lineTo(w * 0.8, h)
          ..close(),
        p(const Color(0xFFB3ABA6)),
      )
      ..drawCircle(
        Offset(w * 0.36, h * 0.88),
        w * 0.014,
        p(const Color(0xFF4A4542)),
      )
      ..drawCircle(
        Offset(w * 0.64, h * 0.88),
        w * 0.014,
        p(const Color(0xFF4A4542)),
      );
  }

  @override
  bool shouldRepaint(_CasetePainter old) => false;
}

/// Pantalla de carga: los instrumentos del género que se juega saltan en ola
/// sobre un ecualizador de su color, con una curiosidad del género debajo
/// (una por carga).
/// Tiempo mínimo que se deja a la vista una pantalla de carga larga (primera
/// carga o acierto): da tiempo a leer la curiosidad y a que carguen la
/// canción y su portada.
const esperaMinimaCarga = Duration(seconds: 5);

class Cargando extends StatefulWidget {
  const Cargando({
    super.key,
    this.texto = 'Cargando...',
    this.curiosidad = true,
  });

  final String texto;
  // Con curiosidad del género debajo; sin ella en salas y al comprobar.
  final bool curiosidad;

  @override
  State<Cargando> createState() => _CargandoState();
}

class _CargandoState extends State<Cargando> {
  final _nota = curiosidadAlAzar(generoActivo);

  @override
  // Con letra grande o pantalla baja se desplaza en vez de desbordarse.
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BandaCargando(),
          const SizedBox(height: 16),
          Text(
            widget.texto,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.paleta.tintaSuave),
          ),
          if (widget.curiosidad)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
              child: _TarjetaCuriosidad(_nota),
            ),
        ],
      ),
    ),
  );
}

/// Curiosidad en un cuadro con el color del género y la tipografía de la app.
/// El tamaño de letra baja con el largo del texto para que quepa entera.
class _TarjetaCuriosidad extends StatelessWidget {
  const _TarjetaCuriosidad(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = tema.colorScheme.primary;
    final tamano = texto.length <= 70
        ? 30.0
        : texto.length <= 110
        ? 26.0
        : texto.length <= 150
        ? 23.0
        : 21.0;
    final estilo = tema.textTheme.headlineSmall;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 480),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: 0.12),
          context.paleta.superficie,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💡 ¿Sabías que...?',
            style: estilo?.copyWith(color: color, fontSize: 24),
          ),
          const SizedBox(height: 6),
          Text(
            texto,
            style: estilo?.copyWith(
              fontSize: tamano,
              height: 1.1,
              color: context.paleta.tinta,
            ),
          ),
        ],
      ),
    );
  }
}

class _BandaCargando extends StatefulWidget {
  const _BandaCargando();

  @override
  State<_BandaCargando> createState() => _BandaCargandoState();
}

class _BandaCargandoState extends State<_BandaCargando> {
  // Reloj compartido de 30 cuadros: se ve igual y dibuja la mitad o menos.
  final _ciclo = CicloLento(periodo: const Duration(milliseconds: 1200));
  // Tres instrumentos al azar de todos los géneros, distintos en cada carga.
  final _instrumentos =
      (Genero.reales
              .expand((genero) => genero.instrumentos.characters)
              .toSet()
              .toList()
            ..shuffle())
          .take(3)
          .toList();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Quieta con "reducir animaciones" o con la pantalla tapada por otra.
    _ciclo.activo =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final instrumentos = _instrumentos;
    final color = colorGenero(generoActivo);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _ciclo,
        builder: (context, _) {
          final t = _ciclo.value;
          // Salto de cada uno en su turno: 0 en reposo, 1 arriba.
          double salto(int i) => max(0.0, sin(2 * pi * (t - i * 0.18)));
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, emoji) in instrumentos.indexed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Transform.translate(
                        offset: Offset(0, -22 * salto(i)),
                        child: Transform.scale(
                          scale: 1 + 0.15 * salto(i),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 64),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 9; i++)
                      Container(
                        width: 8,
                        height: 8 + 32 * sin(2 * pi * t + i * 0.9).abs(),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Cubre la pantalla con la carga mientras [cargando] es true.
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
                  child: Cargando(texto: texto, curiosidad: false),
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

class _BandaMusicalState extends State<BandaMusical> {
  // Reloj compartido de 30 cuadros: se ve igual y dibuja la mitad o menos.
  final _controller = CicloLento(periodo: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Quieta con "reducir animaciones" o con la pantalla tapada por otra.
    _controller.activo =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
  }

  // Los instrumentos del género que se está jugando y una nota.
  List<String> get _instrumentos => [
    ...generoActivo.instrumentos.characters,
    '🎵',
  ];

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
          i.isEven ? PhosphorIconsFill.musicNotes : PhosphorIconsFill.musicNote,
          size: tamano * 0.5,
          color: widget.color,
        ),
      ),
    );
  }
}
