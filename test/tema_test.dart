import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riff/theme.dart';
import 'package:riff/theme/liquid_glass_theme.dart';

void main() {
  test('el tema oscuro usa la paleta de noche y conserva los acentos', () {
    final claro = buildLiquidGlassTheme();
    final oscuro = buildLiquidGlassTheme(oscuro: true);

    expect(claro.brightness, Brightness.light);
    expect(claro.extension<Paleta>(), Paleta.claro);
    expect(oscuro.brightness, Brightness.dark);
    expect(oscuro.extension<Paleta>(), Paleta.noche);
    expect(oscuro.scaffoldBackgroundColor, Paleta.noche.fondo);
    expect(oscuro.colorScheme.secondary, AppColors.signalOrange);
  });
}
