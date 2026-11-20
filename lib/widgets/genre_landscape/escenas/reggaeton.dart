import 'dart:math';

import 'package:flutter/material.dart';

import '../shared/landscape_shapes.dart';

// Paleta del género: azul petróleo, índigo y lavanda; acentos rosa empolvado
// y coral tenue. Nada de neones.
const _lejos = Color(0xFF8E8ACB);
const _medio = Color(0xFF4F5FA3);
const _cerca = Color(0xFF26406C);
const _luz = Color(0xFFFFDDBC);
const _rosa = Color(0xFFE6A3B6);
const _coral = Color(0xFFEE9A86);
const _cable = Color(0xFFBBC6F2);
const _luna = Color(0xFFFFEFD2);
const _agua = Color(0xFF304C86);

/// Luna creciente: un disco al que se le resta otro.
void _lunaCreciente(Canvas c, Offset o, double r) {
  c
    ..saveLayer(Rect.fromCircle(center: o, radius: r * 2), Paint())
    ..drawCircle(o, r, relleno(_luna))
    ..drawCircle(
      o + Offset(r * 0.5, -r * 0.2),
      r * 0.85,
      Paint()..blendMode = BlendMode.clear,
    )
    ..restore();
}

void _estrellas(Canvas c, Size s, {double hasta = 0.5}) {
  for (var i = 0; i < 14; i++) {
    final x = s.width * ((i * 0.381) % 1.0);
    final y = s.height * hasta * ((i * 0.618) % 1.0);
    c.drawCircle(Offset(x, y), 1.2 + (i % 3) * 0.4, relleno(_luna));
  }
}

/// Letrero abstracto: una forma plana y pequeña, sin brillo de neón.
void _letrero(Canvas c, Rect r, Color color, {bool anillo = false}) {
  final rr = RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * 0.3));
  if (anillo) {
    c.drawRRect(rr, trazo(color.withValues(alpha: 0.85), 2.5));
  } else {
    c.drawRRect(rr, relleno(color.withValues(alpha: 0.8)));
  }
}

/// Nivel 1: ciudad de noche. Animación: ventanas que parpadean (6 s).
void reggaetonCiudad(Canvas c, Size s, double t) {
  final w = s.width;
  final h = s.height;
  _estrellas(c, s);
  _lunaCreciente(c, Offset(w * 0.78, h * 0.28), h * 0.12);
  // Cada ventana cambia de estado unas pocas veces por ciclo.
  final paso = (t * 6).floor();
  bool enciende(int i) =>
      azar(i, paso ~/ 2 + (i % 3 == 0 ? paso : 0), menorQue: 4);
  skyline(
    c,
    s,
    _lejos,
    base: 1,
    alturas: [0.5, 0.7, 0.45, 0.8, 0.6, 0.5, 0.75, 0.55],
  );
  skyline(
    c,
    s,
    _medio,
    base: 1,
    alturas: [0.4, 0.55, 0.62, 0.38, 0.5, 0.58, 0.42],
    luz: _luz.withValues(alpha: 0.7),
    encendida: enciende,
  );
  c.drawRect(Rect.fromLTWH(0, h * 0.93, w, h * 0.07), relleno(_cerca));
  palmera(c, Offset(w * 0.1, h), h * 0.6, _cerca);
  palmera(c, Offset(w * 0.9, h), h * 0.5, _cerca);
  // Dos letreros pequeños, en los laterales y fuera de la franja central.
  _letrero(c, Rect.fromLTWH(w * 0.2, h * 0.52, w * 0.07, h * 0.06), _rosa);
  _letrero(
    c,
    Rect.fromLTWH(w * 0.74, h * 0.6, w * 0.06, h * 0.06),
    _coral,
    anillo: true,
  );
}

/// Nivel 2: barrio en la ladera. Animación: cabinas del metrocable (30 s).
void reggaetonLadera(Canvas c, Size s, double t) {
  final w = s.width;
  final h = s.height;
  _estrellas(c, s, hasta: 0.3);
  colinas(c, s, mezcla(_lejos, Colors.white, 0.2), [
    0.4,
    0.22,
    0.34,
    0.26,
    0.42,
  ]);
  // Montaña cubierta de casitas iluminadas.
  c.drawPath(
    Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.55)
      ..quadraticBezierTo(w * 0.55, h * 0.1, w, h * 0.3)
      ..lineTo(w, h)
      ..close(),
    relleno(_lejos),
  );
  for (var fila = 0; fila < 6; fila++) {
    for (var col = 0; col < 16; col++) {
      if (!azar(fila * 16 + col, 3, menorQue: 5)) continue;
      final x = w * (col / 16) + (fila % 2) * 6;
      final tope = h * (0.55 - 0.45 * sin(pi * col / 16).clamp(0.0, 1.0) * 0.8);
      final y = tope + fila * h * 0.075 + col * 0.6;
      if (y > h * 0.9) continue;
      c.drawRect(
        Rect.fromLTWH(x, y, 9, 7),
        relleno(azar(col, fila) ? _luz.withValues(alpha: 0.75) : _medio),
      );
    }
  }
  // Cable diagonal con dos cabinas.
  final a = Offset(0, h * 0.1);
  final b = Offset(w, h * 0.62);
  c.drawLine(a, b, trazo(_cable, 1.4));
  for (final desfase in [0.0, 0.5]) {
    final p = a + (b - a) * ((t + desfase) % 1.0);
    c
      ..drawLine(p, p + const Offset(0, 8), trazo(_cable, 1.2))
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: p + const Offset(0, 15),
            width: 16,
            height: 12,
          ),
          const Radius.circular(3),
        ),
        relleno(_coral),
      );
  }
  // Techos planos con tanques de agua y una antena.
  c.drawRect(
    Rect.fromLTWH(w * 0.04, h * 0.84, w * 0.4, h * 0.16),
    relleno(_cerca),
  );
  c.drawRect(
    Rect.fromLTWH(w * 0.52, h * 0.88, w * 0.44, h * 0.12),
    relleno(_cerca),
  );
  for (final x in [0.1, 0.22]) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * x, h * 0.72, w * 0.07, h * 0.12),
        const Radius.circular(5),
      ),
      relleno(_cerca),
    );
  }
  c
    ..drawLine(
      Offset(w * 0.75, h * 0.88),
      Offset(w * 0.75, h * 0.62),
      trazo(_cerca, 2),
    )
    ..drawLine(
      Offset(w * 0.72, h * 0.7),
      Offset(w * 0.78, h * 0.7),
      trazo(_cerca, 2),
    )
    ..drawLine(
      Offset(w * 0.73, h * 0.65),
      Offset(w * 0.77, h * 0.65),
      trazo(_cerca, 2),
    );
}

/// Nivel 3: costa caribeña nocturna. Animación: reflejo de la luna (8 s).
void reggaetonCosta(Canvas c, Size s, double t) {
  final w = s.width;
  final h = s.height;
  _estrellas(c, s, hasta: 0.4);
  _lunaCreciente(c, Offset(w * 0.5, h * 0.2), h * 0.11);
  mar(c, s, 0.45, _lejos, _agua);
  // Reflejo: tiras que ondulan bajo la luna.
  for (var i = 0; i < 6; i++) {
    final ancho = w * (0.22 - i * 0.025);
    final dx = sin(t * 2 * pi + i) * 6;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.5 + dx, h * (0.52 + i * 0.055)),
          width: ancho,
          height: 3.5,
        ),
        const Radius.circular(2),
      ),
      relleno(_luna.withValues(alpha: 0.8)),
    );
  }
  // Fortaleza colonial sobre el agua.
  final base = h * 0.46;
  c.drawRect(
    Rect.fromLTWH(w * 0.08, base - h * 0.1, w * 0.3, h * 0.1),
    relleno(_medio),
  );
  for (var i = 0; i < 6; i++) {
    c.drawRect(
      Rect.fromLTWH(
        w * 0.08 + i * w * 0.05,
        base - h * 0.135,
        w * 0.03,
        h * 0.035,
      ),
      relleno(_medio),
    );
  }
  c.drawRect(
    Rect.fromLTWH(w * 0.36, base - h * 0.2, w * 0.07, h * 0.2),
    relleno(_medio),
  );
  c.drawRect(
    Rect.fromLTWH(w * 0.355, base - h * 0.23, w * 0.08, h * 0.04),
    relleno(_medio),
  );
  // Muro de malecón y palmeras.
  c.drawRect(Rect.fromLTWH(0, h * 0.86, w, h * 0.14), relleno(_cerca));
  c.drawRect(Rect.fromLTWH(0, h * 0.83, w, h * 0.04), relleno(_medio));
  palmera(c, Offset(w * 0.12, h * 0.86), h * 0.55, _cerca);
  palmera(c, Offset(w * 0.88, h * 0.86), h * 0.62, _cerca);
}
