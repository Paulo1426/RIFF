import 'dart:math';

import 'package:flutter/material.dart';

import '../../../models/genero.dart';
import '../shared/landscape_shapes.dart';

// Escenas de "Adivina la intro": amanecer, tonos pastel, sin luces fuertes.
// Estáticas: la opacidad baja ya las hace discretas.

const _lila = Color(0xFFE9DDF7);
const _durazno = Color(0xFFFBD9BC);
const _solPastel = Color(0xFFFFE3B8);

/// Cielo de amanecer: de lila arriba a durazno en el horizonte.
void _cielo(Canvas c, Size s) {
  final r = Offset.zero & s;
  c.drawRect(
    r,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_lila, _durazno],
      ).createShader(r),
  );
}

void _vaca(Canvas c, Offset o, double t, Color color) {
  final p = relleno(color);
  c
    ..drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: o, width: t, height: t * 0.5),
        Radius.circular(t * 0.2),
      ),
      p,
    )
    ..drawCircle(o + Offset(t * 0.55, -t * 0.08), t * 0.17, p)
    ..drawLine(
      o + Offset(-t * 0.3, t * 0.2),
      o + Offset(-t * 0.3, t * 0.55),
      trazo(color, t * 0.07),
    )
    ..drawLine(
      o + Offset(t * 0.3, t * 0.2),
      o + Offset(t * 0.3, t * 0.55),
      trazo(color, t * 0.07),
    );
}

/// Ceiba: tronco grueso y bajo, copa muy ancha de masas redondas.
void _ceiba(Canvas c, Offset base, double alto, Color tronco, Color copa) {
  sombraSuelo(c, base - Offset(0, alto * 0.02), alto * 1.3, alfa: 0.08);
  arbolRedondo(c, base, alto, tronco, copa, ancho: 1.8);
}

void _casitaEscalon(Canvas c, Rect r, Color pared, Color techo) {
  c.drawRect(r, relleno(pared));
  c.drawPath(
    Path()
      ..moveTo(r.left - 2, r.top)
      ..lineTo(r.center.dx, r.top - r.height * 0.5)
      ..lineTo(r.right + 2, r.top)
      ..close(),
    relleno(techo),
  );
}

void _lancha(Canvas c, Offset o, double t, Color casco, Color vela) {
  c
    ..drawPath(
      Path()
        ..moveTo(o.dx - t, o.dy)
        ..lineTo(o.dx + t, o.dy)
        ..lineTo(o.dx + t * 0.7, o.dy + t * 0.35)
        ..lineTo(o.dx - t * 0.7, o.dy + t * 0.35)
        ..close(),
      relleno(casco),
    )
    ..drawPath(
      Path()
        ..moveTo(o.dx - t * 0.1, o.dy)
        ..lineTo(o.dx - t * 0.1, o.dy - t * 1.1)
        ..lineTo(o.dx + t * 0.6, o.dy)
        ..close(),
      relleno(vela),
    );
}

/// Eucalipto: tronco fino y copa estrecha y vertical, de hojas colgantes.
void _eucalipto(Canvas c, Offset base, double alto, Color madera, Color hoja) {
  final cima = base + Offset(alto * 0.02, -alto * 0.8);
  tronco(c, base, cima, alto * 0.025, alto * 0.035, alto * 0.02, madera);
  final claro = mezcla(hoja, Colors.white, 0.2);
  for (var i = 0; i < 5; i++) {
    final k = i / 4;
    final lado = i.isEven ? -1.0 : 1.0;
    c.drawOval(
      Rect.fromCenter(
        center:
            base +
            Offset(lado * alto * 0.035 + alto * 0.02, -alto * (0.4 + 0.1 * i)),
        width: alto * (0.15 - 0.03 * k),
        height: alto * 0.26,
      ),
      relleno(i < 3 ? hoja : claro),
    );
  }
}

/// Vallenato: sabana del Cesar con la Serranía del Perijá.
void introVallenato(Canvas c, Size s, double t) {
  final w = s.width;
  final h = s.height;
  _cielo(c, s);
  sol(c, Offset(w * 0.55, h * 0.5), h * 0.14, _solPastel);
  colinas(c, s, const Color(0xFFC9C4E0), [
    0.58,
    0.46,
    0.55,
    0.44,
    0.54,
    0.47,
    0.57,
  ]);
  colinas(c, s, const Color(0xFFA9B9D6), [0.66, 0.58, 0.68, 0.6, 0.67]);
  colinas(c, s, const Color(0xFFB9D3A6), [0.74, 0.72, 0.76, 0.73]);
  _vaca(c, Offset(w * 0.45, h * 0.8), h * 0.1, const Color(0xFF6E8A62));
  _vaca(c, Offset(w * 0.62, h * 0.84), h * 0.09, const Color(0xFF6E8A62));
  _vaca(c, Offset(w * 0.78, h * 0.79), h * 0.075, const Color(0xFF6E8A62));
  colinas(c, s, const Color(0xFF8FB387), [0.92, 0.9, 0.93, 0.91]);
  _ceiba(
    c,
    Offset(w * 0.16, h),
    h * 0.7,
    const Color(0xFF7A6A58),
    const Color(0xFF6F9A6C),
  );
  // Cerca de alambre con postes de madera.
  for (var i = 0; i < 6; i++) {
    c.drawLine(
      Offset(w * (0.38 + i * 0.11), h * 0.9),
      Offset(w * (0.38 + i * 0.11), h),
      trazo(const Color(0xFF7A6A58), 4),
    );
  }
  for (final y in [0.93, 0.97]) {
    c.drawLine(
      Offset(w * 0.38, h * y),
      Offset(w, h * y),
      trazo(const Color(0xFF9A8F86), 1.4),
    );
  }
}

/// Reggaetón: playa urbana.
void introReggaeton(Canvas c, Size s, double t) {
  final w = s.width;
  final h = s.height;
  _cielo(c, s);
  const edif = Color(0xFFB9B2D9);
  const ventana = Color(0xFFFFEBD3);
  for (final (x, ancho, alto) in [
    (0.04, 0.07, 0.62),
    (0.12, 0.06, 0.78),
    (0.2, 0.08, 0.55),
    (0.74, 0.07, 0.7),
    (0.82, 0.06, 0.85),
    (0.9, 0.07, 0.58),
  ]) {
    final r = Rect.fromLTWH(
      w * x,
      h * (0.62 - alto * 0.6),
      w * ancho,
      h * alto * 0.6,
    );
    edificio(
      c,
      r,
      edif,
      luz: ventana,
      encendida: (i) => azar(i, (x * 10).round(), menorQue: 2),
      celda: 9,
    );
  }
  mar(c, s, 0.62, const Color(0xFFD9D0F0), const Color(0xFFB9C6E8));
  sol(c, Offset(w * 0.5, h * 0.62), h * 0.12, _solPastel);
  for (var i = 0; i < 5; i++) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * (0.66 + i * 0.045)),
          width: w * (0.2 - i * 0.025),
          height: 3,
        ),
        const Radius.circular(2),
      ),
      relleno(_solPastel),
    );
  }
  colinas(c, s, const Color(0xFFF2DDBF), [0.88, 0.85, 0.9, 0.86]);
  palmera(c, Offset(w * 0.12, h), h * 0.75, const Color(0xFF7A9A78));
  palmera(c, Offset(w * 0.9, h), h * 0.65, const Color(0xFF7A9A78));
  // Silla de salvavidas.
  final b = Offset(w * 0.6, h * 0.97);
  c
    ..drawLine(
      b + Offset(-12, 0),
      b + Offset(-8, -h * 0.2),
      trazo(const Color(0xFF9A7A5C), 3),
    )
    ..drawLine(
      b + Offset(12, 0),
      b + Offset(8, -h * 0.2),
      trazo(const Color(0xFF9A7A5C), 3),
    )
    ..drawRect(
      Rect.fromCenter(
        center: b + Offset(0, -h * 0.26),
        width: 26,
        height: h * 0.1,
      ),
      relleno(const Color(0xFFE9A8A0)),
    )
    ..drawPath(
      Path()
        ..moveTo(b.dx - 18, b.dy - h * 0.31)
        ..lineTo(b.dx + 18, b.dy - h * 0.31)
        ..lineTo(b.dx, b.dy - h * 0.38)
        ..close(),
      relleno(const Color(0xFFD98C84)),
    );
}

/// Salsa: puerto con colina de casitas, bahía y faro.
void introSalsa(Canvas c, Size s, double t) {
  final w = s.width;
  final h = s.height;
  _cielo(c, s);
  sol(c, Offset(w * 0.62, h * 0.42), h * 0.12, _solPastel);
  colinas(c, s, const Color(0xFFE3B7A0), [0.3, 0.4, 0.6, 0.7]);
  const colores = [
    Color(0xFFF3C6A5),
    Color(0xFFBFE3DC),
    Color(0xFFF5B7A8),
    Color(0xFFFBE2A8),
  ];
  for (var fila = 0; fila < 4; fila++) {
    for (var i = 0; i < 4 - fila; i++) {
      _casitaEscalon(
        c,
        Rect.fromLTWH(
          w * (0.02 + fila * 0.04 + i * 0.075),
          h * (0.46 + fila * 0.1),
          w * 0.06,
          h * 0.08,
        ),
        colores[(i + fila) % 4],
        const Color(0xFFC98A72),
      );
    }
  }
  mar(c, s, 0.64, const Color(0xFFBFE3E0), const Color(0xFF9CCFD0));
  _lancha(
    c,
    Offset(w * 0.4, h * 0.74),
    w * 0.04,
    const Color(0xFFD98C84),
    const Color(0xFFFFF2E6),
  );
  _lancha(
    c,
    Offset(w * 0.6, h * 0.8),
    w * 0.035,
    const Color(0xFF8FA9D6),
    const Color(0xFFFFF2E6),
  );
  // Faro.
  c
    ..drawPath(
      Path()
        ..moveTo(w * 0.8, h * 0.66)
        ..lineTo(w * 0.83, h * 0.3)
        ..lineTo(w * 0.87, h * 0.3)
        ..lineTo(w * 0.9, h * 0.66)
        ..close(),
      relleno(const Color(0xFFF2E6DA)),
    )
    ..drawRect(
      Rect.fromLTWH(w * 0.822, h * 0.24, w * 0.056, h * 0.06),
      relleno(const Color(0xFFD98C84)),
    )
    ..drawRect(
      Rect.fromLTWH(w * 0.8, h * 0.43, w * 0.1, h * 0.05),
      relleno(const Color(0xFFD98C84)),
    );
  // Muelle de madera con postes y una cuerda entre ellos.
  const madera = Color(0xFF9A7A5C);
  c.drawRect(Rect.fromLTWH(0, h * 0.9, w, h * 0.1), relleno(madera));
  for (var i = 0; i < 12; i++) {
    c.drawLine(
      Offset(w * i / 12, h * 0.9),
      Offset(w * i / 12, h),
      trazo(const Color(0xFF7C5F45), 1.2),
    );
  }
  for (final x in [0.2, 0.5, 0.8]) {
    c.drawRect(
      Rect.fromLTWH(w * x - 4, h * 0.74, 8, h * 0.17),
      relleno(const Color(0xFF7C5F45)),
    );
  }
  for (final (a, b) in [(0.2, 0.5), (0.5, 0.8)]) {
    c.drawPath(
      Path()
        ..moveTo(w * a, h * 0.77)
        ..quadraticBezierTo(w * (a + b) / 2, h * 0.86, w * b, h * 0.77),
      trazo(const Color(0xFFD9C7AE), 2.2),
    );
  }
}

/// Rock y pop: carretera de gira.
void introRock(Canvas c, Size s, double t) {
  final w = s.width;
  final h = s.height;
  _cielo(c, s);
  final horizonte = h * 0.58;
  sol(c, Offset(w * 0.5, horizonte - h * 0.08), h * 0.16, _solPastel);
  triangulos(c, s, const Color(0xFFC3B3E0), [
    (0.25, 0.3, 0.3),
    (0.78, 0.34, 0.3),
  ]);
  triangulos(c, s, const Color(0xFFA796CC), [
    (0.08, 0.42, 0.2),
    (0.5, 0.48, 0.18),
    (0.92, 0.4, 0.2),
  ]);
  c.drawRect(
    Rect.fromLTWH(0, horizonte, w, h - horizonte),
    relleno(const Color(0xFFCFC4E6)),
  );
  // Carretera en perspectiva con línea central discontinua.
  c.drawPath(
    Path()
      ..moveTo(w * 0.47, horizonte)
      ..lineTo(w * 0.53, horizonte)
      ..lineTo(w * 0.9, h)
      ..lineTo(w * 0.1, h)
      ..close(),
    relleno(const Color(0xFF8E85A8)),
  );
  for (var i = 0; i < 5; i++) {
    final f0 = i / 5;
    final f1 = f0 + 0.1;
    final y0 = horizonte + (h - horizonte) * f0 * f0;
    final y1 = horizonte + (h - horizonte) * f1 * f1;
    c.drawPath(
      Path()
        ..moveTo(w * 0.5 - 1 - 5 * f0 * f0, y0)
        ..lineTo(w * 0.5 + 1 + 5 * f0 * f0, y0)
        ..lineTo(w * 0.5 + 1 + 5 * f1 * f1, y1)
        ..lineTo(w * 0.5 - 1 - 5 * f1 * f1, y1)
        ..close(),
      relleno(const Color(0xFFF2E6DA)),
    );
  }
  // Furgoneta de gira a un lado.
  final x = w * 0.7;
  final y = h * 0.93;
  c
    ..drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y - h * 0.2, w * 0.2, h * 0.16),
        const Radius.circular(8),
      ),
      relleno(const Color(0xFFF2E6DA)),
    )
    ..drawRect(
      Rect.fromLTWH(x + w * 0.02, y - h * 0.16, w * 0.12, h * 0.06),
      relleno(const Color(0xFF9AA6D6)),
    )
    ..drawCircle(
      Offset(x + w * 0.04, y - h * 0.04),
      h * 0.04,
      relleno(const Color(0xFF5E5878)),
    )
    ..drawCircle(
      Offset(x + w * 0.16, y - h * 0.04),
      h * 0.04,
      relleno(const Color(0xFF5E5878)),
    );
  // Postes de luz y un letrero sin texto.
  const poste = Color(0xFF6E678A);
  for (final px in [0.05, 0.22]) {
    c
      ..drawLine(Offset(w * px, h), Offset(w * px, h * 0.5), trazo(poste, 3))
      ..drawLine(
        Offset(w * px, h * 0.5),
        Offset(w * px + 14, h * 0.5),
        trazo(poste, 3),
      )
      ..drawCircle(
        Offset(w * px + 14, h * 0.52),
        4,
        relleno(const Color(0xFFFFE3B8)),
      );
  }
  c
    ..drawLine(Offset(w * 0.34, h), Offset(w * 0.34, h * 0.72), trazo(poste, 3))
    ..drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.29, h * 0.6, w * 0.1, h * 0.12),
        const Radius.circular(4),
      ),
      relleno(const Color(0xFF8FA9D6)),
    );
}

/// Popular: campos de Boyacá con niebla y laguna.
void introPopular(Canvas c, Size s, double t) {
  final w = s.width;
  final h = s.height;
  _cielo(c, s);
  colinas(c, s, const Color(0xFFBFC2E0), [0.4, 0.28, 0.42, 0.3, 0.4]);
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(0, h * 0.4, w, h * 0.07),
      const Radius.circular(20),
    ),
    relleno(Colors.white.withValues(alpha: 0.55)),
  );
  colinas(c, s, const Color(0xFF9FB5A0), [0.52, 0.44, 0.54, 0.46]);
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.1, h * 0.5, w * 0.8, h * 0.05),
      const Radius.circular(20),
    ),
    relleno(Colors.white.withValues(alpha: 0.45)),
  );
  // Campos en mosaico de verdes y ocres.
  const parches = [
    Color(0xFFA9C98A),
    Color(0xFFC9D08A),
    Color(0xFFD9B97C),
    Color(0xFF8DB07A),
    Color(0xFFB9C27A),
  ];
  for (var fila = 0; fila < 3; fila++) {
    for (var i = 0; i < 6; i++) {
      final y0 = h * (0.58 + fila * 0.14);
      c.drawPath(
        Path()
          ..moveTo(w * (i / 6) + fila * 6, y0)
          ..lineTo(w * ((i + 1) / 6) + fila * 6, y0)
          ..lineTo(w * ((i + 1) / 6) + fila * 12, y0 + h * 0.14)
          ..lineTo(w * (i / 6) + fila * 12, y0 + h * 0.14)
          ..close(),
        relleno(parches[(i * 2 + fila) % 5]),
      );
    }
  }
  c.drawOval(
    Rect.fromCenter(
      center: Offset(w * 0.3, h * 0.66),
      width: w * 0.2,
      height: h * 0.07,
    ),
    relleno(const Color(0xFFB9D6E8)),
  );
  // Casa campesina de teja, caminito y eucaliptos.
  c.drawPath(
    Path()
      ..moveTo(w * 0.6, h * 0.98)
      ..quadraticBezierTo(w * 0.7, h * 0.88, w * 0.64, h * 0.8)
      ..lineTo(w * 0.7, h * 0.8)
      ..quadraticBezierTo(w * 0.8, h * 0.9, w * 0.74, h * 0.98)
      ..close(),
    relleno(const Color(0xFFE3C9A0)),
  );
  casa(
    c,
    Rect.fromLTWH(w * 0.6, h * 0.66, w * 0.16, h * 0.14),
    const Color(0xFFF6EDE0),
    const Color(0xFFD27A62),
    const Color(0xFF8FA9D6),
  );
  _eucalipto(
    c,
    Offset(w * 0.1, h),
    h * 0.9,
    const Color(0xFF8C7A6A),
    const Color(0xFF7FA088),
  );
  _eucalipto(
    c,
    Offset(w * 0.2, h),
    h * 0.72,
    const Color(0xFF8C7A6A),
    const Color(0xFF7FA088),
  );
  _eucalipto(
    c,
    Offset(w * 0.9, h),
    h * 0.8,
    const Color(0xFF8C7A6A),
    const Color(0xFF7FA088),
  );
}

/// Medley: un horizonte continuo con un elemento de cada género y, al frente,
/// un pentagrama ondulado con notas.
void introMedley(Canvas c, Size s, double t) {
  final w = s.width;
  final h = s.height;
  _cielo(c, s);
  sol(c, Offset(w * 0.5, h * 0.4), h * 0.12, _solPastel);
  colinas(c, s, const Color(0xFFBFC2E0), [
    0.5,
    0.4,
    0.52,
    0.42,
    0.5,
    0.44,
    0.52,
  ]);
  final suelo = h * 0.78;
  c.drawRect(
    Rect.fromLTWH(0, suelo, w, h - suelo),
    relleno(const Color(0xFFB9D3A6)),
  );
  // 1. Sierra con palo de mango.
  // Sierra redondeada que baja hacia la ciudad.
  c.save();
  c.clipRect(Rect.fromLTWH(0, 0, w, suelo));
  colinas(c, s, const Color(0xFFA9B9D6), [
    0.4,
    0.3,
    0.44,
    0.52,
    0.66,
    0.78,
    0.78,
    0.78,
  ]);
  c.restore();
  arbolRedondo(
    c,
    Offset(w * 0.1, suelo),
    h * 0.42,
    const Color(0xFF7A6A58),
    const Color(0xFF6F9A6C),
  );
  // 2. Edificios urbanos bajos.
  for (var i = 0; i < 4; i++) {
    edificio(
      c,
      Rect.fromLTWH(
        w * (0.2 + i * 0.045),
        suelo - h * (0.2 + 0.07 * (i % 3)),
        w * 0.042,
        h * (0.2 + 0.07 * (i % 3)),
      ),
      const Color(0xFFB9B2D9),
      luz: const Color(0xFFFFEBD3),
      encendida: (j) => azar(j, i, menorQue: 3),
      celda: 8,
    );
  }
  // 3. Casas coloridas con balcón.
  const colores = [
    Color(0xFFF3C6A5),
    Color(0xFFBFE3DC),
    Color(0xFFF5B7A8),
    Color(0xFFFBE2A8),
  ];
  for (var i = 0; i < 4; i++) {
    final r = Rect.fromLTWH(
      w * (0.4 + i * 0.045),
      suelo - h * 0.22,
      w * 0.043,
      h * 0.22,
    );
    c.drawRect(r, relleno(colores[i]));
    c.drawRect(
      Rect.fromLTWH(r.left - 1, r.top + r.height * 0.5, r.width + 2, 2.5),
      relleno(const Color(0xFF9A7A5C)),
    );
  }
  // 4. Torre de parlantes de escenario.
  c.drawRect(
    Rect.fromLTWH(w * 0.62, suelo - h * 0.34, w * 0.07, h * 0.34),
    relleno(const Color(0xFF8E85A8)),
  );
  for (var k = 0; k < 3; k++) {
    c.drawCircle(
      Offset(w * 0.655, suelo - h * (0.08 + k * 0.1)),
      w * 0.02,
      relleno(const Color(0xFFC3B3E0)),
    );
  }
  c.drawRect(
    Rect.fromLTWH(w * 0.7, suelo - h * 0.1, w * 0.07, h * 0.1),
    relleno(const Color(0xFF8E85A8)),
  );
  // 5. Palmas de cera y casa con techo de teja.
  for (final (x, alto) in [(0.8, 0.5), (0.86, 0.4)]) {
    palmaCera(
      c,
      Offset(w * x, suelo),
      h * alto,
      const Color(0xFF9A7A5C),
      const Color(0xFF7FA088),
    );
  }
  casa(
    c,
    Rect.fromLTWH(w * 0.9, suelo - h * 0.14, w * 0.08, h * 0.14),
    const Color(0xFFF6EDE0),
    const Color(0xFFD27A62),
    const Color(0xFF8FA9D6),
  );
  // Pentagrama ondulado con notas, al frente.
  final linea = trazo(const Color(0xFF8E85A8), 1.6);
  for (var i = 0; i < 5; i++) {
    c.drawPath(onda(0, w, h * (0.84 + i * 0.03), 6, 0, ondas: 2), linea);
  }
  for (var i = 0; i < 7; i++) {
    final x = w * (0.08 + i * 0.14);
    final y = h * (0.84 + 0.03 * (i * 2 % 5)) + 6 * sin(x / w * 4 * pi);
    c
      ..drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 13, height: 9),
        relleno(const Color(0xFF6E678A)),
      )
      ..drawLine(
        Offset(x + 6, y),
        Offset(x + 6, y - 24),
        trazo(const Color(0xFF6E678A), 2),
      );
  }
}

/// Salas de intros: estudio de radio visto de frente.
void introRadio(Canvas c, Size s, double t) {
  final w = s.width;
  final h = s.height;
  c.drawRect(Offset.zero & s, relleno(const Color(0xFFD9CCEE)));
  // Espuma acústica en rombos.
  for (var fila = 0; fila < 4; fila++) {
    for (var i = 0; i < 10; i++) {
      final cx = w * (i + (fila.isOdd ? 0.5 : 0)) / 9;
      final cy = h * (0.04 + fila * 0.1);
      c.drawPath(
        Path()
          ..moveTo(cx, cy - h * 0.06)
          ..lineTo(cx + w * 0.05, cy)
          ..lineTo(cx, cy + h * 0.06)
          ..lineTo(cx - w * 0.05, cy)
          ..close(),
        relleno(
          (i + fila).isEven ? const Color(0xFFBBA6DD) : const Color(0xFFA891D0),
        ),
      );
    }
  }
  // Letrero "AL AIRE" como forma: rectángulo con brillo suave.
  final letrero = Rect.fromCenter(
    center: Offset(w * 0.5, h * 0.2),
    width: w * 0.3,
    height: h * 0.12,
  );
  c
    ..drawRRect(
      RRect.fromRectAndRadius(letrero.inflate(8), const Radius.circular(14)),
      relleno(const Color(0x40FFC59A)),
    )
    ..drawRRect(
      RRect.fromRectAndRadius(letrero, const Radius.circular(8)),
      relleno(const Color(0xFFF2B27A)),
    )
    ..drawRRect(
      RRect.fromRectAndRadius(letrero.deflate(5), const Radius.circular(5)),
      trazo(const Color(0xFFFFE3C9), 2),
    );
  // Estante con discos de vinilo y casetes.
  const madera = Color(0xFFA97C50);
  c.drawRect(Rect.fromLTWH(w * 0.05, h * 0.5, w * 0.9, 6), relleno(madera));
  for (var i = 0; i < 6; i++) {
    final x = w * (0.1 + i * 0.07);
    c.drawRect(
      Rect.fromLTWH(x, h * 0.34, w * 0.02, h * 0.16),
      relleno(i.isEven ? const Color(0xFF5E4A82) : const Color(0xFFE29A63)),
    );
  }
  for (var i = 0; i < 3; i++) {
    final centro = Offset(w * (0.6 + i * 0.1), h * 0.42);
    c
      ..drawCircle(centro, h * 0.07, relleno(const Color(0xFF3F3358)))
      ..drawCircle(centro, h * 0.025, relleno(const Color(0xFFE29A63)));
  }
  for (var i = 0; i < 2; i++) {
    final r = Rect.fromLTWH(
      w * (0.55 + i * 0.1),
      h * 0.465,
      w * 0.07,
      h * 0.035,
    );
    c.drawRect(r, relleno(const Color(0xFFD9CCEE)));
  }
  // Escritorio con consola de mezcla.
  c.drawRect(Rect.fromLTWH(0, h * 0.78, w, h * 0.22), relleno(madera));
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.2, h * 0.64, w * 0.6, h * 0.16),
      const Radius.circular(8),
    ),
    relleno(const Color(0xFF5E4A82)),
  );
  for (var i = 0; i < 8; i++) {
    final x = w * (0.24 + i * 0.07);
    c
      ..drawRect(
        Rect.fromLTWH(x, h * 0.68, 3, h * 0.1),
        relleno(const Color(0xFF3F3358)),
      )
      ..drawRect(
        Rect.fromLTWH(x - 3, h * (0.7 + 0.03 * (i % 3)), 9, 5),
        relleno(const Color(0xFFE29A63)),
      );
    c.drawCircle(Offset(x + 1, h * 0.665), 3, relleno(const Color(0xFFD9CCEE)));
  }
  // Micrófono con brazo articulado.
  const metal = Color(0xFF6E678A);
  final base = Offset(w * 0.88, h * 0.82);
  final codo = Offset(w * 0.8, h * 0.52);
  final punta = Offset(w * 0.68, h * 0.58);
  c
    ..drawLine(base, codo, trazo(metal, 3))
    ..drawLine(codo, punta, trazo(metal, 3))
    ..drawCircle(codo, 4, relleno(metal))
    ..drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: punta + const Offset(0, 8),
          width: 12,
          height: 22,
        ),
        const Radius.circular(6),
      ),
      relleno(const Color(0xFF3F3358)),
    );
  // Audífonos sobre el escritorio.
  final aud = Offset(w * 0.12, h * 0.86);
  c
    ..drawArc(
      Rect.fromCenter(center: aud, width: w * 0.12, height: h * 0.2),
      pi,
      pi,
      false,
      trazo(const Color(0xFF3F3358), 4),
    )
    ..drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: aud + Offset(-w * 0.06, 0),
          width: 10,
          height: 20,
        ),
        const Radius.circular(5),
      ),
      relleno(const Color(0xFF3F3358)),
    )
    ..drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: aud + Offset(w * 0.06, 0),
          width: 10,
          height: 20,
        ),
        const Radius.circular(5),
      ),
      relleno(const Color(0xFF3F3358)),
    );
}

/// Salas de adivina la canción: escenario de concurso.
void introConcurso(Canvas c, Size s, double t) {
  final w = s.width;
  final h = s.height;
  // Telón con pliegues verticales.
  for (var i = 0; i < 16; i++) {
    c.drawRect(
      Rect.fromLTWH(w * i / 16, 0, w / 16 + 1, h * 0.8),
      relleno(i.isEven ? const Color(0xFFC7A9E0) : const Color(0xFFB591D4)),
    );
  }
  // Fila de focos redondos arriba, en tonos pastel.
  for (var i = 0; i < 9; i++) {
    final o = Offset(w * (i + 0.5) / 9, h * 0.07);
    c
      ..drawCircle(o, h * 0.07, relleno(const Color(0x40FFE3B8)))
      ..drawCircle(o, h * 0.035, relleno(const Color(0xFFFFE9C9)));
  }
  // Tres podios con botón redondo.
  for (final x in [0.2, 0.5, 0.8]) {
    final cx = w * x;
    c
      ..drawPath(
        Path()
          ..moveTo(cx - w * 0.1, h * 0.8)
          ..lineTo(cx - w * 0.07, h * 0.46)
          ..lineTo(cx + w * 0.07, h * 0.46)
          ..lineTo(cx + w * 0.1, h * 0.8)
          ..close(),
        relleno(const Color(0xFF7A5CB8)),
      )
      ..drawRect(
        Rect.fromLTWH(cx - w * 0.075, h * 0.44, w * 0.15, 6),
        relleno(const Color(0xFF9A7ED0)),
      )
      ..drawCircle(
        Offset(cx, h * 0.41),
        h * 0.04,
        relleno(const Color(0xFFF2B27A)),
      )
      ..drawCircle(
        Offset(cx, h * 0.41),
        h * 0.022,
        relleno(const Color(0xFFFFD9B0)),
      );
  }
  // Borde del escenario con luces pequeñas tipo marquesina.
  c.drawRect(
    Rect.fromLTWH(0, h * 0.8, w, h * 0.2),
    relleno(const Color(0xFFA97C50)),
  );
  for (var i = 0; i < 14; i++) {
    c.drawCircle(
      Offset(w * (i + 0.5) / 14, h * 0.88),
      4.5,
      relleno(const Color(0xFFFFE9C9)),
    );
  }
}

/// Escena de la pantalla de intros para [genero] (Medley incluido).
Escena escenaIntros(Genero genero) => switch (genero) {
  Genero.vallenato => introVallenato,
  Genero.reggaeton => introReggaeton,
  Genero.salsa => introSalsa,
  Genero.rockPop => introRock,
  Genero.popular => introPopular,
  Genero.aleatorio => introMedley,
};
