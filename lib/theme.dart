import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta "estudio soleado sobre papel cálido".
class AppColors {
  static const amberPulse = Color(0xFFF9A916);
  // Solo para lo que suena: reproductor y arte de pistas.
  static const limeSignal = Color(0xFFA0F32F);
  static const lavenderWash = Color(0xFFC4BAE3);
  static const mustardField = Color(0xFFE1CA46);
  static const sageMist = Color(0xFF9FC2C7);
  static const khakiPaper = Color(0xFFE5DFC8);
  static const warmCanvas = Color(0xFFF4F1EC);
  static const purePaper = Color(0xFFFFFFFF);
  static const paleMist = Color(0xFFE2E2E7);
  static const hairline = Color(0xFFD2D1DB);
  static const inkStone = Color(0xFF27262B);
  static const charcoal = Color(0xFF000000);
  static const ash = Color(0xFF737170);
  // Colores del logo de Riff (póster del festival).
  static const riffTurquoise = Color(0xFF22A9A4);
  static const riffYellow = Color(0xFFF5C84A);
  static const riffRed = Color(0xFFD8432E);
  static const riffNavy = Color(0xFF1D3B6F);
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.inkStone,
    onPrimary: AppColors.purePaper,
    primaryContainer: AppColors.khakiPaper,
    onPrimaryContainer: AppColors.charcoal,
    secondary: AppColors.amberPulse,
    onSecondary: AppColors.charcoal,
    secondaryContainer: AppColors.khakiPaper,
    onSecondaryContainer: AppColors.charcoal,
    tertiary: AppColors.limeSignal,
    onTertiary: AppColors.charcoal,
    surface: AppColors.warmCanvas,
    onSurface: AppColors.charcoal,
    onSurfaceVariant: AppColors.ash,
    surfaceContainerLowest: AppColors.purePaper,
    surfaceContainerLow: AppColors.purePaper,
    surfaceContainer: AppColors.purePaper,
    surfaceContainerHigh: AppColors.purePaper,
    surfaceContainerHighest: AppColors.paleMist,
    outline: AppColors.ash,
    outlineVariant: AppColors.hairline,
    error: Color(0xFFB3261E),
    onError: AppColors.purePaper,
  );

  // Inter en solo dos pesos: 700 para títulos y botones, 400 para lectura.
  final base = GoogleFonts.interTextTheme(
    ThemeData(brightness: Brightness.light).textTheme,
  );
  TextStyle? bold(TextStyle? s, double tracking) =>
      s?.copyWith(fontWeight: FontWeight.w700, letterSpacing: tracking);
  TextStyle? regular(TextStyle? s) =>
      s?.copyWith(fontWeight: FontWeight.w400, letterSpacing: -0.1);
  final textTheme = base
      .copyWith(
        displayLarge: bold(base.displayLarge, -1.2),
        displayMedium: bold(base.displayMedium, -1),
        displaySmall: bold(base.displaySmall, -0.84),
        headlineLarge: bold(base.headlineLarge, -0.84),
        headlineMedium: bold(base.headlineMedium, -0.6),
        headlineSmall: bold(base.headlineSmall, -0.51),
        titleLarge: bold(base.titleLarge, -0.3),
        titleMedium: bold(base.titleMedium, -0.2),
        titleSmall: bold(base.titleSmall, -0.1),
        labelLarge: bold(base.labelLarge, -0.1),
        bodyLarge: regular(base.bodyLarge),
        bodyMedium: regular(base.bodyMedium),
        bodySmall: regular(base.bodySmall),
        labelMedium: regular(base.labelMedium),
        labelSmall: regular(base.labelSmall),
      )
      .apply(bodyColor: AppColors.charcoal, displayColor: AppColors.charcoal);

  // Controles pill y superficies de vidrio translúcido (sin sombras).
  const pill = StadiumBorder();
  const card = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(24)),
  );
  const buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 12);
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: AppColors.hairline),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.warmCanvas,
    textTheme: textTheme,
    // Transición suave (deslizar + desvanecer) entre pantallas.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.warmCanvas,
      foregroundColor: AppColors.charcoal,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: AppColors.purePaper.withValues(alpha: 0.55),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radioVidrio),
        side: BorderSide(color: AppColors.purePaper.withValues(alpha: 0.85)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      // Ámbar es el único color de acción.
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.amberPulse,
        foregroundColor: AppColors.charcoal,
        disabledBackgroundColor: AppColors.paleMist,
        disabledForegroundColor: AppColors.ash,
        shape: pill,
        padding: buttonPadding,
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.purePaper.withValues(alpha: 0.6),
        foregroundColor: AppColors.charcoal,
        side: const BorderSide(color: AppColors.charcoal),
        shape: pill,
        padding: buttonPadding,
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.charcoal,
        shape: pill,
        textStyle: textTheme.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.purePaper.withValues(alpha: 0.7),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.inkStone, width: 1.5),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.warmCanvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: card,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.hairline),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.inkStone,
      linearTrackColor: AppColors.hairline,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.inkStone,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: AppColors.purePaper,
      ),
      shape: pill,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

const radioVidrio = 20.0;

/// Vidrio líquido suave: desenfoca lo de atrás bajo un blanco translúcido.
class Vidrio extends StatelessWidget {
  const Vidrio({super.key, required this.child, this.radio = radioVidrio});

  final Widget child;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final borde = BorderRadius.circular(radio);
    return ClipRRect(
      borderRadius: borde,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borde,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.purePaper.withValues(alpha: 0.72),
                AppColors.purePaper.withValues(alpha: 0.42),
              ],
            ),
            border: Border.all(
              color: AppColors.purePaper.withValues(alpha: 0.85),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Fondo crema con manchas suaves de los colores del logo, para que el
/// vidrio tenga algo que desenfocar.
class FondoRiff extends StatelessWidget {
  const FondoRiff({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _FondoPainter(), child: child);
}

class _FondoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    for (final (x, y, r, color, alpha) in [
      (0.05, 0.08, 0.75, AppColors.riffTurquoise, 0.30),
      (1.0, 0.45, 0.7, AppColors.riffYellow, 0.35),
      (0.1, 0.95, 0.65, AppColors.riffRed, 0.16),
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
  bool shouldRepaint(_FondoPainter oldDelegate) => false;
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
    canvas.drawCircle(center, r, Paint()..color = AppColors.inkStone);
    final surco = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.03
      ..color = AppColors.purePaper.withValues(alpha: 0.12);
    for (final f in [0.85, 0.7, 0.55]) {
      canvas.drawCircle(center, r * f, surco);
    }
    // Brillo asimétrico: sin él no se notaría que el disco gira.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r * 0.95),
      -pi / 3,
      pi / 5,
      true,
      Paint()..color = AppColors.purePaper.withValues(alpha: 0.18),
    );
    canvas.drawCircle(center, r * 0.36, Paint()..color = AppColors.limeSignal);
    canvas.drawCircle(
      center + Offset(r * 0.2, 0),
      r * 0.06,
      Paint()..color = AppColors.inkStone,
    );
    canvas.drawCircle(center, r * 0.07, Paint()..color = AppColors.warmCanvas);
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
          ).textTheme.bodyMedium?.copyWith(color: AppColors.ash),
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
                  color: AppColors.warmCanvas.withValues(alpha: 0.9),
                  child: Cargando(texto: texto),
                )
              : const SizedBox.shrink(),
        ),
      ),
    ],
  );
}
