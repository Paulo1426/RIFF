import 'dart:math';

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

  // Controles redondos (pill), superficies casi rectas (4px), sin sombras.
  const pill = StadiumBorder();
  const card = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(4)),
  );
  const buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 12);
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: const BorderSide(color: AppColors.hairline),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.warmCanvas,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.warmCanvas,
      foregroundColor: AppColors.charcoal,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.purePaper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
        side: BorderSide(color: AppColors.hairline),
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
        backgroundColor: AppColors.purePaper,
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
      fillColor: AppColors.purePaper,
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

/// Motivo de sol: medio círculo lima sobre un panel. Marca lo que suena.
class ArteSol extends StatelessWidget {
  const ArteSol({super.key, this.size = 48, this.fondo = AppColors.khakiPaper});

  final double size;
  final Color fondo;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: ColoredBox(
      color: fondo,
      child: CustomPaint(size: Size.square(size), painter: _SolPainter()),
    ),
  );
}

class _SolPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => canvas.drawArc(
    Offset.zero & size,
    pi,
    pi,
    true,
    Paint()..color = AppColors.limeSignal,
  );

  @override
  bool shouldRepaint(_SolPainter oldDelegate) => false;
}
