import 'dart:math';

import 'package:flutter/material.dart';

import '../shared/landscape_shapes.dart';

// Paleta del género: naranja cálido con toques de turquesa.
const _sol = Color(0xFFF39A5E);
const _naranja = Color(0xFFF6B98A);
const _naranjaOscuro = Color(0xFFD0693C);
const _turquesa = Color(0xFF63B8AD);
const _pastel = [
  Color(0xFFFFD1A1),
  Color(0xFFBFEAE3),
  Color(0xFFFFB8A0),
  Color(0xFFFFE6A8),
];
const _ladrillo = Color(0xFFB5543C);
const _ladrilloClaro = Color(0xFFD27A58);
const _sombra = Color(0xFF7A3520);

/// Nivel 1: atardecer caleño. Animación: el sol respira (8 s).
void salsaCali(Canvas c, Size s, double t) {
  final w = s.width;
  final h = s.height;
  final respira = 1 + 0.05 * sin(t * 2 * pi);
  sol(c, Offset(w * 0.5, h * 0.5), h * 0.2 * respira, _sol);
  colinas(c, s, mezcla(_naranja, Colors.white, 0.3), [
    0.46,
    0.36,
    0.5,
    0.34,
    0.48,
  ]);
  colinas(c, s, _naranja, [0.55, 0.42, 0.58, 0.4, 0.56]);
  bruma(
    c,
    s,
    0.42,
    0.62,
    mezcla(_naranjaOscuro, Colors.white, 0.25),
    picos: [0.55, 0.42, 0.58, 0.4, 0.56],
  );
  colinas(c, s, mezcla(_naranjaOscuro, Colors.white, 0.1), [
    0.68,
    0.6,
    0.7,
    0.62,
  ]);
  // Casas coloridas con balcones.
  for (var i = 0; i < 5; i++) {
    final r = Rect.fromLTWH(w * (0.03 + i * 0.19), h * 0.6, w * 0.17, h * 0.3);
    c.drawRect(r, relleno(_pastel[i % 4]));
    // Alero sencillo y balcón con baranda.
    c.drawRect(
      Rect.fromLTWH(r.left - 3, r.top - 4, r.width + 6, 5),
      relleno(mezcla(_pastel[i % 4], _sombra, 0.35)),
    );
    c.drawRect(
      Rect.fromLTWH(r.left - 2, r.top + r.height * 0.5, r.width + 4, 3),
      relleno(_sombra),
    );
    c.drawRect(
      Rect.fromLTWH(r.left, r.top + r.height * 0.5 - 9, r.width, 1.6),
      relleno(_sombra.withValues(alpha: 0.8)),
    );
    c.drawRect(
      Rect.fromLTWH(
        r.left + r.width * 0.2,
        r.top + r.height * 0.12,
        r.width * 0.2,
        r.height * 0.28,
      ),
      relleno(_turquesa),
    );
    c.drawRect(
      Rect.fromLTWH(
        r.left + r.width * 0.6,
        r.top + r.height * 0.12,
        r.width * 0.2,
        r.height * 0.28,
      ),
      relleno(_turquesa),
    );
  }
  c.drawRect(Rect.fromLTWH(0, h * 0.9, w, h * 0.1), relleno(_sombra));
  palmera(c, Offset(w * 0.08, h), h * 0.65, _sombra);
  palmera(c, Offset(w * 0.93, h), h * 0.55, _sombra);
  // Farolas antiguas, apagadas: luz crema muy tenue.
  for (final x in [0.22, 0.78]) {
    c
      ..drawLine(Offset(w * x, h), Offset(w * x, h * 0.66), trazo(_sombra, 3))
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(w * x, h * 0.63),
            width: 8,
            height: 11,
          ),
          const Radius.circular(3),
        ),
        relleno(_pastel[3].withValues(alpha: 0.7)),
      );
  }
}

/// Nivel 2: Nueva York de los 70. Animación: vapor de un techo (10 s).
void salsaNuevaYork(Canvas c, Size s, double t) {
  final w = s.width;
  final h = s.height;
  // Edificios altos con tanque de agua de madera.
  skyline(c, s, _naranja, base: 1, alturas: [0.7, 0.9, 0.62, 0.82, 0.7]);
  for (final x in [0.12, 0.5, 0.82]) {
    final cx = w * x;
    final techo = h * 0.2;
    c
      ..drawRect(Rect.fromLTWH(cx - 8, techo, 16, 14), relleno(_sombra))
      ..drawPath(
        Path()
          ..moveTo(cx - 10, techo)
          ..lineTo(cx, techo - 8)
          ..lineTo(cx + 10, techo)
          ..close(),
        relleno(_sombra),
      );
  }
  // Edificios de ladrillo con escaleras de incendio en zigzag.
  for (var i = 0; i < 3; i++) {
    final r = Rect.fromLTWH(
      w * (0.04 + i * 0.33),
      h * 0.42,
      w * 0.28,
      h * 0.58,
    );
    edificio(
      c,
      r,
      _ladrillo,
      luz: _pastel[3],
      encendida: (j) => azar(j, i),
      celda: 11,
    );
    final escalera = trazo(_sombra, 1.8);
    for (var k = 0; k < 4; k++) {
      final y = r.top + r.height * (0.15 + k * 0.2);
      c
        ..drawLine(
          Offset(r.right - r.width * 0.35, y),
          Offset(r.right - 2, y + r.height * 0.1),
          escalera,
        )
        ..drawLine(
          Offset(r.right - 2, y + r.height * 0.1),
          Offset(r.right - r.width * 0.35, y + r.height * 0.2),
          escalera,
        );
    }
  }
  // Vapor que sube desde un techo y se desvanece.
  final chimenea = Offset(w * 0.38, h * 0.42);
  for (var i = 0; i < 4; i++) {
    final f = (t + i / 4) % 1.0;
    c.drawCircle(
      chimenea + Offset(sin(f * 6 + i) * 6, -f * h * 0.3),
      4 + f * 9,
      relleno(Colors.white.withValues(alpha: 0.8 * (1 - f))),
    );
  }
  c.drawRect(Rect.fromLTWH(0, h * 0.92, w, h * 0.08), relleno(_sombra));
  // Hidrante y farola.
  c
    ..drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.2, h * 0.8, 12, h * 0.14),
        const Radius.circular(4),
      ),
      relleno(_naranjaOscuro),
    )
    ..drawLine(
      Offset(w * 0.78, h * 0.94),
      Offset(w * 0.78, h * 0.5),
      trazo(_sombra, 3.5),
    )
    ..drawLine(
      Offset(w * 0.78, h * 0.5),
      Offset(w * 0.72, h * 0.5),
      trazo(_sombra, 3.5),
    )
    ..drawCircle(Offset(w * 0.72, h * 0.52), 6, relleno(_pastel[3]));
}

/// Nivel 3: malecón caribeño. Animación: olas contra el muro (8 s).
void salsaMalecon(Canvas c, Size s, double t) {
  final w = s.width;
  final h = s.height;
  sol(c, Offset(w * 0.72, h * 0.34), h * 0.13, _sol);
  mar(c, s, 0.36, _turquesa, const Color(0xFF1B8F95));
  for (var i = 0; i < 3; i++) {
    c.drawPath(
      onda(0, w, h * (0.46 + i * 0.07), 3, t * 2 * pi + i, ondas: 5),
      trazo(Colors.white.withValues(alpha: 0.7), 2),
    );
  }
  // Fachadas coloniales desgastadas en tonos pastel.
  for (var i = 0; i < 5; i++) {
    final alto = h * (0.4 + 0.1 * (i % 3));
    final r = Rect.fromLTWH(
      w * (0.02 + i * 0.2),
      h * 0.78 - alto,
      w * 0.19,
      alto,
    );
    c.drawRect(r, relleno(_pastel[i % 4]));
    for (var k = 0; k < 2; k++) {
      c.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(
            r.left + r.width * (0.2 + k * 0.4),
            r.top + r.height * 0.18,
            r.width * 0.22,
            r.height * 0.34,
          ),
          topLeft: const Radius.circular(8),
          topRight: const Radius.circular(8),
        ),
        relleno(_sombra.withValues(alpha: 0.6)),
      );
    }
  }
  // Muro del malecón.
  c.drawRect(Rect.fromLTWH(0, h * 0.78, w, h * 0.22), relleno(_ladrilloClaro));
  c.drawRect(Rect.fromLTWH(0, h * 0.76, w, h * 0.04), relleno(_sombra));
  // Auto clásico de los años 50.
  final x = w * 0.58;
  final y = h * 0.95;
  c
    ..drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y - h * 0.12, w * 0.3, h * 0.08),
        const Radius.circular(10),
      ),
      relleno(_naranjaOscuro),
    )
    ..drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(x + w * 0.07, y - h * 0.2, w * 0.15, h * 0.09),
        topLeft: const Radius.circular(14),
        topRight: const Radius.circular(14),
      ),
      relleno(_naranjaOscuro),
    )
    ..drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(x + w * 0.085, y - h * 0.185, w * 0.12, h * 0.06),
        topLeft: const Radius.circular(10),
        topRight: const Radius.circular(10),
      ),
      relleno(_pastel[1]),
    )
    ..drawCircle(Offset(x + w * 0.06, y - h * 0.04), h * 0.05, relleno(_sombra))
    ..drawCircle(
      Offset(x + w * 0.24, y - h * 0.04),
      h * 0.05,
      relleno(_sombra),
    );
}
