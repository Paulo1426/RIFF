import 'dart:math';

import 'package:flutter/material.dart';

import '../shared/landscape_shapes.dart';

// Paleta del género: verdes de montaña, rojo teja, blanco, madera y ocre.
const _nube = Color(0xFFFFFFFF);
const _montana1 = Color(0xFF8DBF9A);
const _montana2 = Color(0xFF5E9E73);
const _montana3 = Color(0xFF3E7D55);
const _verdeOscuro = Color(0xFF2B5E3E);
const _teja = Color(0xFFC4553B);
const _blanco = Color(0xFFF4EBDD);
const _madera = Color(0xFF8B5E3C);
const _ocre = Color(0xFFD9A441);
const _ocreOscuro = Color(0xFFB07F2C);
const _puertas = [Color(0xFF3D8FE5), Color(0xFFE5533D), Color(0xFF3DB57A)];

void _sombrero(Canvas c, Offset o, double ancho, Color color) {
  c
    ..drawOval(
      Rect.fromCenter(center: o, width: ancho, height: ancho * 0.28),
      relleno(color),
    )
    ..drawPath(
      Path()
        ..moveTo(o.dx - ancho * 0.2, o.dy)
        ..quadraticBezierTo(o.dx, o.dy - ancho * 0.6, o.dx + ancho * 0.2, o.dy)
        ..close(),
      relleno(color),
    );
}

/// Poste de cerca con alambre a un lado: [x] en píxeles, [y] de la base.
void _cerca(
  Canvas c,
  double x0,
  double x1,
  double y,
  double alto,
  Color color,
) {
  const n = 5;
  for (var i = 0; i < n; i++) {
    final x = x0 + (x1 - x0) * i / (n - 1);
    c.drawLine(Offset(x, y), Offset(x, y - alto), trazo(color, alto * 0.09));
  }
  for (final f in [0.3, 0.7]) {
    c.drawLine(
      Offset(x0, y - alto * f),
      Offset(x1, y - alto * f),
      trazo(color, alto * 0.05),
    );
  }
}

/// Mata de café: masa de hojas ovaladas agrupadas, con unos granos rojos.
void _cafeto(Canvas c, Offset o, double r) {
  for (final (dx, dy, k, claro) in [
    (-0.9, 0.0, 0.8, false),
    (0.9, 0.05, 0.8, false),
    (0.0, -0.2, 1.0, false),
    (-0.4, -0.5, 0.7, true),
    (0.45, -0.45, 0.65, true),
  ]) {
    c.drawOval(
      Rect.fromCenter(
        center: o + Offset(dx * r, dy * r),
        width: r * 1.5 * k,
        height: r * 1.0 * k,
      ),
      relleno(mezcla(_montana3, Colors.white, claro ? 0.18 : 0)),
    );
  }
  for (final dx in [-0.5, 0.1, 0.6]) {
    c.drawCircle(o + Offset(dx * r, -r * 0.15), r * 0.1, relleno(_teja));
  }
}

/// Nivel 1: Eje Cafetero. Animación: nubes (40 s).
void popularCafetero(Canvas c, Size s, double t) {
  final w = s.width;
  final h = s.height;
  nubesDeslizantes(c, s, t, _nube);
  // Tres capas de montaña, cada una más clara hacia el horizonte.
  colinas(c, s, _montana1, [0.42, 0.3, 0.46, 0.34, 0.44]);
  bruma(c, s, 0.34, 0.62, _montana2, picos: [0.42, 0.3, 0.46, 0.34, 0.44]);
  colinas(c, s, _montana2, [0.58, 0.48, 0.6, 0.5]);
  bruma(c, s, 0.5, 0.78, _montana3, picos: [0.58, 0.48, 0.6, 0.5]);
  // Palmas de cera altas, de hojas largas que cuelgan.
  for (final (x, alto) in [(0.07, 0.56), (0.17, 0.44), (0.9, 0.5)]) {
    palmaCera(c, Offset(w * x, h * 0.8), h * alto, _madera, _montana3);
  }
  colinas(c, s, _montana3, [0.78, 0.7, 0.8, 0.72]);
  // Casa campesina a un costado, con teja y puertas de colores.
  final r = Rect.fromLTWH(w * 0.6, h * 0.56, w * 0.22, h * 0.22);
  sombraSuelo(c, Offset(r.center.dx, r.bottom), r.width * 1.3);
  casa(c, r, _blanco, _teja, _puertas[0], alero: 0.14);
  c.drawRect(
    Rect.fromLTWH(
      r.left + r.width * 0.62,
      r.top + r.height * 0.28,
      r.width * 0.2,
      r.height * 0.24,
    ),
    relleno(_puertas[1]),
  );
  colinas(c, s, _verdeOscuro, [0.92, 0.88, 0.94, 0.9]);
  // Cerca en perspectiva solo en los lados, con un sombrero sobre un poste.
  _cerca(c, 0, w * 0.34, h * 0.9, h * 0.2, _madera);
  _cerca(c, w * 0.8, w, h * 0.92, h * 0.17, _madera);
  _sombrero(c, Offset(w * 0.275, h * 0.72), w * 0.1, _ocre);
  _cafeto(c, Offset(w * 0.09, h * 0.97), h * 0.1);
  _cafeto(c, Offset(w * 0.92, h * 0.98), h * 0.09);
}

/// Nivel 2: pueblo mexicano. Animación: nubes (40 s).
void popularMexico(Canvas c, Size s, double t) {
  final w = s.width;
  final h = s.height;
  nubesDeslizantes(c, s, t, _nube, n: 2);
  colinas(c, s, const Color(0xFFE6C98A), [0.5, 0.36, 0.55, 0.4, 0.52]);
  colinas(c, s, _ocre, [0.66, 0.58, 0.68, 0.6]);
  // Kiosco de plaza con techo redondeado.
  final kx = w * 0.3;
  final base = h * 0.8;
  for (var i = 0; i < 4; i++) {
    c.drawRect(
      Rect.fromLTWH(kx + i * w * 0.045, base - h * 0.2, 4, h * 0.2),
      relleno(_blanco),
    );
  }
  c
    ..drawArc(
      Rect.fromLTWH(kx - 8, base - h * 0.42, w * 0.18, h * 0.46),
      pi,
      pi,
      true,
      relleno(_teja),
    )
    ..drawRect(Rect.fromLTWH(kx - 8, base - 3, w * 0.18, 5), relleno(_blanco));
  // Iglesia pequeña con torre.
  final ix = w * 0.62;
  c
    ..drawRect(
      Rect.fromLTWH(ix, base - h * 0.2, w * 0.18, h * 0.2),
      relleno(_blanco),
    )
    ..drawRect(
      Rect.fromLTWH(ix + w * 0.12, base - h * 0.4, w * 0.05, h * 0.2),
      relleno(_blanco),
    )
    ..drawPath(
      Path()
        ..moveTo(ix + w * 0.115, base - h * 0.4)
        ..lineTo(ix + w * 0.145, base - h * 0.52)
        ..lineTo(ix + w * 0.175, base - h * 0.4)
        ..close(),
      relleno(_teja),
    )
    ..drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(ix + w * 0.04, base - h * 0.12, w * 0.05, h * 0.12),
        topLeft: const Radius.circular(10),
        topRight: const Radius.circular(10),
      ),
      relleno(_ocreOscuro),
    );
  colinas(c, s, _ocreOscuro, [0.9, 0.86, 0.92, 0.88]);
  // Magueyes en roseta, en grupos a los lados.
  for (final (x, y, tam) in [
    (0.08, 0.98, 0.42),
    (0.2, 0.99, 0.28),
    (0.92, 0.98, 0.38),
    (0.82, 0.99, 0.24),
  ]) {
    maguey(c, Offset(w * x, h * y), h * tam, _montana3);
  }
  // Banca con sombrero de charro.
  c.drawRect(Rect.fromLTWH(w * 0.62, h * 0.9, w * 0.2, 5), relleno(_madera));
  c.drawRect(Rect.fromLTWH(w * 0.64, h * 0.9, 4, h * 0.1), relleno(_madera));
  c.drawRect(Rect.fromLTWH(w * 0.78, h * 0.9, 4, h * 0.1), relleno(_madera));
  _sombrero(c, Offset(w * 0.72, h * 0.88), w * 0.12, _teja);
}

/// Nivel 3: estación de carrilera. Animación: la lámpara parpadea (5 s).
void popularCarrilera(Canvas c, Size s, double t) {
  final w = s.width;
  final h = s.height;
  colinas(c, s, _montana1, [0.46, 0.34, 0.5, 0.38, 0.48]);
  colinas(c, s, _montana2, [0.6, 0.52, 0.62, 0.54]);
  colinas(c, s, _montana3, [0.72, 0.66, 0.74, 0.68]);
  // Estación de madera con alero.
  final r = Rect.fromLTWH(w * 0.14, h * 0.5, w * 0.34, h * 0.26);
  c
    ..drawRect(r, relleno(_madera))
    ..drawPath(
      Path()
        ..moveTo(r.left - 14, r.top)
        ..lineTo(r.right + 14, r.top)
        ..lineTo(r.right + 4, r.top - h * 0.12)
        ..lineTo(r.left + 4 - 4, r.top - h * 0.12)
        ..close(),
      relleno(_teja),
    )
    ..drawRect(
      Rect.fromLTWH(
        r.left + r.width * 0.12,
        r.top + r.height * 0.3,
        r.width * 0.2,
        r.height * 0.7,
      ),
      relleno(_blanco),
    )
    ..drawRect(
      Rect.fromLTWH(
        r.left + r.width * 0.55,
        r.top + r.height * 0.25,
        r.width * 0.3,
        r.height * 0.3,
      ),
      relleno(_blanco),
    );
  colinas(c, s, _verdeOscuro, [0.8, 0.76, 0.82, 0.78]);
  // Rieles en perspectiva.
  final vanish = Offset(w * 0.68, h * 0.78);
  final riel = trazo(_ocreOscuro, 3);
  c
    ..drawLine(vanish, Offset(w * 0.3, h), riel)
    ..drawLine(vanish, Offset(w * 0.98, h), riel);
  for (var i = 1; i <= 5; i++) {
    final f = i / 5;
    final y = vanish.dy + (h - vanish.dy) * f * f;
    final ancho = (w * 0.34) * f * f;
    c.drawLine(
      Offset(vanish.dx - ancho * 0.5 - 6 * f, y),
      Offset(vanish.dx + ancho * 0.5 + 6 * f, y),
      trazo(_madera, 2 + f * 2),
    );
  }
  // Lámpara de estación con luz que parpadea.
  final base = Offset(w * 0.08, h);
  c
    ..drawLine(base, base - Offset(0, h * 0.5), trazo(_madera, 4))
    ..drawCircle(
      base - Offset(0, h * 0.54),
      18,
      relleno(
        const Color(
          0xFFFFE08A,
        ).withValues(alpha: 0.35 + 0.3 * (0.5 + 0.5 * sin(t * 2 * pi))),
      ),
    )
    ..drawCircle(
      base - Offset(0, h * 0.54),
      6,
      relleno(const Color(0xFFFFE08A)),
    );
}
