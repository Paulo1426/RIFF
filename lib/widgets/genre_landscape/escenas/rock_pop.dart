import 'dart:math';

import 'package:flutter/material.dart';

import '../shared/landscape_shapes.dart';

// Paleta del género: azul noche, ciruela y violeta; acentos rosa pastel y
// ámbar, sin amarillos ni rosas saturados.
const _azul = Color(0xFF2B3068);
const _morado = Color(0xFF5B3F8F);
const _moradoClaro = Color(0xFF8E74C4);
const _amarillo = Color(0xFFF2C984);
const _rosa = Color(0xFFE9A5C0);
const _naranja = Color(0xFFF0A878);

/// Silueta de público: cabeza, hombros y, a veces, un brazo en alto.
void _publico(Canvas c, Size s, Color color, double base, {int n = 9}) {
  final p = relleno(color);
  for (var i = 0; i < n; i++) {
    final x = s.width * (i + 0.5) / n;
    final y = s.height * (base + 0.04 * (i % 3));
    c
      ..drawCircle(Offset(x, y), s.height * 0.045, p)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, y + s.height * 0.1),
            width: s.height * 0.17,
            height: s.height * 0.16,
          ),
          const Radius.circular(10),
        ),
        p,
      );
    if (i % 2 == 0) {
      c.drawLine(
        Offset(x + 6, y + s.height * 0.05),
        Offset(x + 12, y - s.height * 0.1),
        trazo(color, 3),
      );
    }
  }
}

/// Nivel 1: gran concierto. Animación: los haces oscilan (10 s).
void rockConcierto(Canvas c, Size s, double t) {
  final w = s.width;
  final h = s.height;
  final giro = sin(t * 2 * pi) * 0.06;
  for (var i = 0; i < 3; i++) {
    final origen = Offset(w * (0.2 + i * 0.3), 0);
    final a = (i.isEven ? 1 : -1) * 0.3 + giro * (i.isEven ? 1 : -1);
    final largo = h * 1.1;
    final fin = origen + Offset(sin(a), cos(a)) * largo;
    c.drawPath(
      Path()
        ..moveTo(origen.dx - 3, 0)
        ..lineTo(fin.dx - 38, fin.dy)
        ..lineTo(fin.dx + 38, fin.dy)
        ..lineTo(origen.dx + 3, 0)
        ..close(),
      relleno((i % 2 == 0 ? _amarillo : _rosa).withValues(alpha: 0.4)),
    );
  }
  // Escenario con torres de parlantes.
  c.drawRect(
    Rect.fromLTWH(w * 0.14, h * 0.58, w * 0.72, h * 0.2),
    relleno(_morado),
  );
  for (final x in [0.08, 0.84]) {
    c.drawRect(
      Rect.fromLTWH(w * x, h * 0.4, w * 0.08, h * 0.4),
      relleno(_azul),
    );
    for (var k = 0; k < 3; k++) {
      c.drawCircle(
        Offset(w * (x + 0.04), h * (0.48 + k * 0.1)),
        w * 0.022,
        relleno(_moradoClaro),
      );
    }
  }
  _publico(c, s, _azul, 0.86);
}

/// Nivel 2: festival al aire libre. Animación: banderines (4 s).
void rockFestival(Canvas c, Size s, double t) {
  final w = s.width;
  final h = s.height;
  const verdeLejos = Color(0xFF6C5CC0);
  colinas(c, s, verdeLejos, [0.5, 0.36, 0.52, 0.4, 0.5]);
  colinas(c, s, _morado, [0.62, 0.55, 0.66, 0.58]);
  // Escenario lejano con techo curvo.
  c.drawRect(
    Rect.fromLTWH(w * 0.35, h * 0.5, w * 0.3, h * 0.14),
    relleno(_azul),
  );
  c.drawArc(
    Rect.fromLTWH(w * 0.33, h * 0.32, w * 0.34, h * 0.4),
    pi,
    pi,
    true,
    relleno(_rosa),
  );
  // Banderines ondeando entre dos postes.
  final fase = t * 2 * pi;
  c
    ..drawLine(
      Offset(w * 0.02, h * 0.2),
      Offset(w * 0.02, h * 0.6),
      trazo(_azul, 3),
    )
    ..drawLine(
      Offset(w * 0.98, h * 0.2),
      Offset(w * 0.98, h * 0.6),
      trazo(_azul, 3),
    )
    ..drawPath(
      onda(w * 0.02, w * 0.98, h * 0.26, 3, 0, ondas: 0.5),
      trazo(_azul, 1.5),
    );
  for (var i = 0; i < 14; i++) {
    final x = w * (0.05 + i * 0.065);
    final y = h * 0.26 + 3 * sin((x - w * 0.02) / (w * 0.96) * pi);
    final bandera = sin(fase + i * 0.7) * 3;
    c.drawPath(
      Path()
        ..moveTo(x, y)
        ..lineTo(x + 11, y + 2 + bandera)
        ..lineTo(x + 5, y + 18 + bandera)
        ..close(),
      relleno([_amarillo, _rosa, _naranja][i % 3]),
    );
  }
  colinas(c, s, _azul, [0.9, 0.84, 0.92, 0.86]);
  arbolRedondo(
    c,
    Offset(w * 0.08, h),
    h * 0.66,
    _azul,
    mezcla(_azul, _morado, 0.3),
  );
  arbolRedondo(
    c,
    Offset(w * 0.92, h),
    h * 0.6,
    _azul,
    mezcla(_azul, _morado, 0.3),
  );
  // Tres carpas pequeñas a los lados.
  for (final (x, k) in [(0.24, 1.0), (0.34, 0.8), (0.74, 0.9)]) {
    final ancho = w * 0.05 * k;
    c.drawPath(
      Path()
        ..moveTo(w * x - ancho, h)
        ..lineTo(w * x, h * (1 - 0.14 * k))
        ..lineTo(w * x + ancho, h)
        ..close(),
      relleno(_moradoClaro),
    );
  }
}

/// Nivel 3: atardecer synthwave. Animación: la cuadrícula avanza (6 s).
void rockSynthwave(Canvas c, Size s, double t) {
  final w = s.width;
  final h = s.height;
  final horizonte = h * 0.55;
  // Sol con franjas horizontales, de rosa a naranja.
  final centro = Offset(w * 0.5, h * 0.36);
  final r = h * 0.3;
  c.save();
  c.clipRect(Rect.fromLTWH(0, 0, w, horizonte));
  c.drawCircle(
    centro,
    r,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_naranja, _rosa],
      ).createShader(Rect.fromCircle(center: centro, radius: r)),
  );
  for (var i = 0; i < 5; i++) {
    final y = centro.dy + r * (0.1 + i * 0.18);
    c.drawRect(
      Rect.fromLTWH(centro.dx - r, y, r * 2, 2 + i * 1.6),
      Paint()..blendMode = BlendMode.clear,
    );
  }
  c.restore();
  triangulos(c, s, _morado, [
    (0.12, 0.3, 0.16),
    (0.3, 0.4, 0.14),
    (0.72, 0.36, 0.17),
    (0.9, 0.42, 0.14),
  ]);
  c.drawRect(
    Rect.fromLTWH(0, horizonte, w, h - horizonte),
    relleno(mezcla(_azul, _morado, 0.25)),
  );
  // Cuadrícula en perspectiva que se pierde en el horizonte.
  final linea = trazo(_rosa.withValues(alpha: 0.5), 1.0);
  for (var i = -8; i <= 8; i++) {
    c.drawLine(
      Offset(w * 0.5, horizonte),
      Offset(w * 0.5 + i * w * 0.14, h),
      linea,
    );
  }
  for (var i = 0; i < 6; i++) {
    final f = (i + t) / 6;
    c.drawLine(
      Offset(0, horizonte + (h - horizonte) * f * f),
      Offset(w, horizonte + (h - horizonte) * f * f),
      linea,
    );
  }
}
