import 'dart:math';

import 'package:flutter/material.dart';

import '../shared/landscape_shapes.dart';

// Paleta del género: verdes, amarillo cálido, azul claro y arena.
const _nube = Color(0xFFFFFFFF);
const _sierra = Color(0xFF9CC3DF);
const _nieve = Color(0xFFF2F8FC);
const _verdeClaro = Color(0xFF8CCB7E);
const _verde = Color(0xFF4FA365);
const _verdeOscuro = Color(0xFF2A7048);
const _sol = Color(0xFFFFC857);
const _arena = Color(0xFFEBCF94);
const _arenaOscura = Color(0xFFD1A864);
const _rio = Color(0xFF5DB4E3);
const _madera = Color(0xFF7A5232);
const _techo = Color(0xFFC98B45);
const _puertas = [Color(0xFFE5533D), Color(0xFF3D8FE5), Color(0xFFF2B632)];

const _picosSierra = [0.5, 0.3, 0.52, 0.2, 0.5, 0.28, 0.55];

/// Nivel 1: Valledupar y la Sierra. Animación: nubes (40 s).
void vallenatoSierra(Canvas c, Size s, double t) {
  final w = s.width;
  final h = s.height;
  nubesDeslizantes(c, s, t, _nube);
  // Sol grande medio escondido tras la sierra.
  sol(c, Offset(w * 0.7, h * 0.5), h * 0.17, _sol);
  sierraNevada(c, s, _sierra, _nieve, _picosSierra);
  bruma(c, s, 0.3, 0.7, _verdeClaro, picos: _picosSierra);
  colinas(c, s, _verdeClaro, [0.62, 0.52, 0.64, 0.5, 0.66]);
  colinas(c, s, _verde, [0.78, 0.7, 0.8, 0.72]);
  // Río que serpentea por el centro.
  final rio = Path()
    ..moveTo(w * 0.45, h * 0.66)
    ..cubicTo(w * 0.62, h * 0.74, w * 0.38, h * 0.86, w * 0.55, h)
    ..lineTo(w * 0.78, h)
    ..cubicTo(w * 0.6, h * 0.86, w * 0.8, h * 0.76, w * 0.5, h * 0.66)
    ..close();
  c.drawPath(rio, relleno(_rio));
  colinas(c, s, _verdeOscuro, [1.0, 0.92, 1.0, 0.95, 1.0]);
  // Palo de mango frondoso.
  sombraSuelo(c, Offset(w * 0.15, h * 0.98), h * 0.7);
  arbolRedondo(c, Offset(w * 0.15, h), h * 0.66, _madera, _verdeOscuro);
}

/// Nivel 2: Desierto de La Guajira. Animación: aspas del molino (12 s).
void vallenatoGuajira(Canvas c, Size s, double t) {
  final w = s.width;
  final h = s.height;
  mar(c, s, 0.38, const Color(0xFF9ED7F0), const Color(0xFF5DB4E3));
  colinas(c, s, _arena, [0.6, 0.5, 0.62, 0.52, 0.64]);
  // Molino de viento sobre una duna.
  final cubo = Offset(w * 0.72, h * 0.42);
  c.drawPath(
    Path()
      ..moveTo(cubo.dx - 4, cubo.dy)
      ..lineTo(cubo.dx + 4, cubo.dy)
      ..lineTo(cubo.dx + 7, h * 0.7)
      ..lineTo(cubo.dx - 7, h * 0.7)
      ..close(),
    relleno(_madera),
  );
  for (var i = 0; i < 4; i++) {
    final a = t * 2 * pi + i * pi / 2;
    final d = Offset(cos(a), sin(a));
    final n = Offset(-d.dy, d.dx);
    final largo = h * 0.2;
    c.drawPath(
      Path()
        ..moveTo(cubo.dx, cubo.dy)
        ..lineTo(
          cubo.dx + d.dx * largo * 0.25 + n.dx * 2.5,
          cubo.dy + d.dy * largo * 0.25 + n.dy * 2.5,
        )
        ..lineTo(
          cubo.dx + d.dx * largo + n.dx * 4,
          cubo.dy + d.dy * largo + n.dy * 4,
        )
        ..lineTo(cubo.dx + d.dx * largo, cubo.dy + d.dy * largo)
        ..close(),
      relleno(_madera),
    );
  }
  c.drawCircle(cubo, 3.5, relleno(_madera));
  colinas(c, s, _arenaOscura, [0.82, 0.74, 0.84, 0.76]);
  // Ranchería con techo de palma.
  final r = Rect.fromLTWH(w * 0.12, h * 0.8, w * 0.14, h * 0.2);
  c.drawRect(r, relleno(_madera));
  c.drawPath(
    Path()
      ..moveTo(r.left - 8, r.top + 2)
      ..lineTo(r.center.dx, r.top - h * 0.14)
      ..lineTo(r.right + 8, r.top + 2)
      ..close(),
    relleno(_techo),
  );
  // Cardones con brazos que suben, uno a cada lado.
  cardon(c, Offset(w * 0.4, h), h * 0.5, _verdeOscuro);
  cardon(c, Offset(w * 0.9, h), h * 0.4, _verdeOscuro);
}

/// Nivel 3: Pueblo en la tarde. Animación: la hamaca se mece (6 s).
void vallenatoPueblo(Canvas c, Size s, double t) {
  final w = s.width;
  final h = s.height;
  // Nubes de atardecer, casi quietas.
  nube(c, Offset(w * 0.25, h * 0.2), h * 0.06, const Color(0xFFFFD9A8));
  nube(c, Offset(w * 0.72, h * 0.3), h * 0.07, const Color(0xFFFFC6A0));
  sol(c, Offset(w * 0.5, h * 0.52), h * 0.16, const Color(0xFFFFA94D));
  colinas(c, s, _verdeClaro, [0.6, 0.52, 0.62, 0.55]);
  // Casas bajas de bahareque con puertas de colores.
  const paredes = [Color(0xFFF6E4C2), Color(0xFFF1D3A0), Color(0xFFF9EBD2)];
  for (var i = 0; i < 4; i++) {
    final ancho = w * 0.16;
    casa(
      c,
      Rect.fromLTWH(w * (0.05 + i * 0.235), h * 0.6, ancho, h * 0.22),
      paredes[i % 3],
      _techo,
      _puertas[i % 3],
    );
  }
  colinas(c, s, _verde, [0.86, 0.82, 0.88, 0.84]);
  // Dos árboles con una hamaca entre ellos.
  final izq = Offset(w * 0.1, h);
  final der = Offset(w * 0.9, h);
  arbolRedondo(c, izq, h * 0.6, _madera, _verdeOscuro);
  arbolRedondo(c, der, h * 0.6, _madera, _verdeOscuro);
  final balanceo = sin(t * 2 * pi) * h * 0.04;
  final ancla1 = Offset(w * 0.1 + h * 0.03, h * 0.7);
  final ancla2 = Offset(w * 0.9 + h * 0.03, h * 0.7);
  c.drawPath(
    Path()
      ..moveTo(ancla1.dx, ancla1.dy)
      ..quadraticBezierTo(
        w * 0.5 + balanceo * 4,
        h * 0.9 + balanceo,
        ancla2.dx,
        ancla2.dy,
      ),
    trazo(_techo, 5),
  );
}
