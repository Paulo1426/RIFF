import 'package:flutter/material.dart';

import '../animations/liquid_morph_transition.dart';
import '../theme.dart';

/// Valores del estilo "Liquid Glass": vidrio translúcido sutil sobre la
/// paleta de la app. Todos los widgets de `widgets/liquid_glass/` leen de
/// aquí para que el efecto sea igual en toda la app.
abstract final class LiquidGlass {
  // Desenfoque (sigma del BackdropFilter) y opacidad del relleno blanco.
  static const glassBlur = 20.0;
  static const glassOpacity = 0.45;

  // Borde de luz.
  static const glassBorderOpacity = 0.7;
  static const glassBorderWidth = 1.5;

  static const glassRadius = 24.0;

  // Sombra suave bajo el vidrio.
  static const glassShadowBlur = 30.0;
  static const glassShadowOpacity = 0.16;

  /// Relleno: blanco más denso arriba que abajo, como luz que entra.
  static final glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withValues(alpha: 0.45),
      Colors.white.withValues(alpha: 0.1),
    ],
  );

  /// Borde: más brillante en la esquina superior izquierda.
  static final glassBorderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withValues(alpha: 0.95),
      Colors.white.withValues(alpha: 0.45),
    ],
  );

  // Colores derivados de la paleta.
  static final verdeGlassBase = AppColors.verde.withValues(alpha: 0.08);
  static final verdeGlassBorder = AppColors.verde.withValues(alpha: 0.3);
  static final naranjaGlass = AppColors.signalOrange.withValues(alpha: 0.9);

  /// Sombra estándar del vidrio.
  static final sombra = [
    BoxShadow(
      color: Colors.black.withValues(alpha: glassShadowOpacity),
      blurRadius: glassShadowBlur,
      offset: const Offset(0, 10),
    ),
  ];
}

/// Tema de la app con la capa de vidrio: parte del tema base y cambia solo
/// superficies, bordes y botones, sin tocar tipografía ni estructura.
ThemeData buildLiquidGlassTheme() {
  final base = buildAppTheme();
  final redondeo = BorderRadius.circular(LiquidGlass.glassRadius);
  final bordeVidrio = BorderSide(
    color: Colors.white.withValues(alpha: LiquidGlass.glassBorderOpacity),
    width: LiquidGlass.glassBorderWidth,
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: bordeVidrio,
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.cloudMist,
    // Transición líquida: fundido + escala + desenfoque que se aclara.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: LiquidMorphPageTransitionsBuilder(),
        TargetPlatform.iOS: LiquidMorphPageTransitionsBuilder(),
      },
    ),
    appBarTheme: base.appBarTheme.copyWith(
      // Transparente: el fondo líquido se ve detrás de la barra.
      backgroundColor: Colors.transparent,
    ),
    cardTheme: base.cardTheme.copyWith(
      color: Colors.white.withValues(alpha: LiquidGlass.glassOpacity + 0.5),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: redondeo, side: bordeVidrio),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.disabled)
              ? AppColors.cloudEdge
              : LiquidGlass.naranjaGlass,
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style?.copyWith(
        backgroundColor: WidgetStatePropertyAll(
          Colors.white.withValues(alpha: 0.45),
        ),
        side: WidgetStatePropertyAll(bordeVidrio),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: Colors.white.withValues(alpha: 0.55),
      border: inputBorder,
      enabledBorder: inputBorder,
      // Borde verde luminoso al enfocar.
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.verde, width: 2),
      ),
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: Colors.white.withValues(alpha: 0.88),
      shape: RoundedRectangleBorder(borderRadius: redondeo, side: bordeVidrio),
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      color: Colors.white.withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: bordeVidrio,
      ),
    ),
  );
}
