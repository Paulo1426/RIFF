import 'dart:math';

import 'package:flutter/material.dart';

/// Una escena dibuja las tres capas (fondo, medio, frente) de atrás hacia
/// adelante. [t] es la fase de 0 a 1 de su única animación.
typedef Escena = void Function(Canvas canvas, Size size, double t);

Paint relleno(Color color) => Paint()..color = color;

Paint trazo(Color color, double ancho) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = ancho
  ..strokeCap = StrokeCap.round;

/// Azar fijo por casilla [i] y paso [k]: el mismo resultado en cada cuadro.
bool azar(int i, int k, {int de = 7, int menorQue = 3}) =>
    ((i * 73856093) ^ (k * 19349663)).abs() % de < menorQue;

/// Mezcla [color] con [con] en la fracción [k] (0 = color).
Color mezcla(Color color, Color con, double k) => Color.lerp(color, con, k)!;

/// Silueta de cresta suave. Cada valor de [picos] es la altura de un pico
/// como fracción del alto (0 arriba, 1 abajo), repartidos a lo ancho.
Path crestaSuave(Size s, List<double> picos) {
  final n = picos.length;
  final xs = [for (var i = 0; i < n; i++) s.width * i / (n - 1)];
  final ys = [for (final p in picos) s.height * p];
  final path = Path()
    ..moveTo(0, s.height)
    ..lineTo(0, ys[0]);
  for (var i = 0; i < n - 1; i++) {
    path.quadraticBezierTo(
      xs[i],
      ys[i],
      (xs[i] + xs[i + 1]) / 2,
      (ys[i] + ys[i + 1]) / 2,
    );
  }
  path
    ..lineTo(s.width, ys[n - 1])
    ..lineTo(s.width, s.height)
    ..close();
  return path;
}

void colinas(Canvas c, Size s, Color color, List<double> picos) =>
    c.drawPath(crestaSuave(s, picos), relleno(color));

/// Velo de bruma horizontal entre [desde] y [hasta] (fracciones del alto):
/// separa planos y da profundidad sin añadir objetos.
void bruma(
  Canvas c,
  Size s,
  double desde,
  double hasta,
  Color color, {
  List<double>? picos,
}) {
  final r = Rect.fromLTRB(0, s.height * desde, s.width, s.height * hasta);
  // Con [picos] solo vela dentro de esa silueta, no sobre el cielo.
  if (picos != null) {
    c
      ..save()
      ..clipPath(crestaSuave(s, picos));
  }
  c.drawRect(
    r,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0), color.withValues(alpha: 0.6)],
      ).createShader(r),
  );
  if (picos != null) c.restore();
}

/// Sombra plana y suave sobre el suelo, desplazada un poco hacia abajo.
void sombraSuelo(Canvas c, Offset centro, double ancho, {double alfa = 0.1}) =>
    c.drawOval(
      Rect.fromCenter(
        center: centro + Offset(ancho * 0.08, ancho * 0.03),
        width: ancho,
        height: ancho * 0.16,
      ),
      relleno(Colors.black.withValues(alpha: alfa)),
    );

/// Montañas redondeadas con nieve en las puntas (cortada recta).
void sierraNevada(
  Canvas c,
  Size s,
  Color color,
  Color nieve,
  List<double> picos,
) {
  final path = crestaSuave(s, picos);
  c.drawPath(path, relleno(color));
  final n = picos.length;
  for (var i = 1; i < n - 1; i++) {
    // Punta real de la curva suavizada.
    final y =
        s.height *
        (0.125 * picos[i - 1] + 0.75 * picos[i] + 0.125 * picos[i + 1]);
    if (picos[i] > picos[i - 1] || picos[i] > picos[i + 1]) continue;
    final x = s.width * i / (n - 1);
    c.save();
    c.clipRect(
      Rect.fromLTRB(x - s.width * 0.08, 0, x + s.width * 0.08, y + 12),
    );
    c.drawPath(path, relleno(nieve));
    c.restore();
  }
}

/// Montañas triangulares: cada pico es (x, y, medio ancho) en fracciones.
void triangulos(
  Canvas c,
  Size s,
  Color color,
  List<(double, double, double)> picos,
) {
  for (final (x, y, ancho) in picos) {
    c.drawPath(
      Path()
        ..moveTo(s.width * (x - ancho), s.height)
        ..lineTo(s.width * x, s.height * y)
        ..lineTo(s.width * (x + ancho), s.height)
        ..close(),
      relleno(color),
    );
  }
}

/// Nube de base plana: masas redondas de distinto tamaño sobre una línea.
void nube(Canvas c, Offset o, double r, Color color) {
  final p = relleno(color);
  final base = o.dy + r * 0.6;
  c.save();
  c.clipRect(Rect.fromLTRB(o.dx - r * 3, o.dy - r * 2, o.dx + r * 3, base));
  c
    ..drawCircle(o + Offset(-r * 1.15, r * 0.15), r * 0.62, p)
    ..drawCircle(o + Offset(-r * 0.45, -r * 0.2), r * 0.95, p)
    ..drawCircle(o + Offset(r * 0.5, -r * 0.45), r * 1.1, p)
    ..drawCircle(o + Offset(r * 1.3, r * 0.05), r * 0.7, p)
    ..drawRect(Rect.fromLTRB(o.dx - r * 1.8, o.dy, o.dx + r * 2.0, base), p);
  c.restore();
}

/// [n] nubes que cruzan de lado a lado y reaparecen por el otro extremo.
void nubesDeslizantes(
  Canvas c,
  Size s,
  double t,
  Color color, {
  int n = 3,
  double alto = 0.22,
}) {
  final r = s.height * 0.07;
  final margen = r * 3;
  for (var i = 0; i < n; i++) {
    final x = ((i / n + t) % 1.0) * (s.width + 2 * margen) - margen;
    nube(
      c,
      Offset(x, s.height * (alto + 0.1 * (i % 2))),
      r * (1 + 0.2 * i),
      color,
    );
  }
}

/// Círculo limpio con un halo muy tenue.
void sol(Canvas c, Offset o, double r, Color color) {
  c
    ..drawCircle(o, r * 1.45, relleno(color.withValues(alpha: 0.16)))
    ..drawCircle(o, r * 1.18, relleno(color.withValues(alpha: 0.2)))
    ..drawCircle(o, r, relleno(color));
}

Offset _bez(Offset a, Offset b, Offset c, double t) =>
    a * ((1 - t) * (1 - t)) + b * (2 * (1 - t) * t) + c * (t * t);

/// Tronco relleno que se estrecha de [anchoBase] a [anchoTope] siguiendo una
/// curva suave; [curva] desplaza el punto de control a un lado.
void tronco(
  Canvas c,
  Offset base,
  Offset tope,
  double curva,
  double anchoBase,
  double anchoTope,
  Color color,
) {
  final ctrl = Offset.lerp(base, tope, 0.5)! + Offset(curva, 0);
  const n = 14;
  final izq = <Offset>[];
  final der = <Offset>[];
  for (var i = 0; i <= n; i++) {
    final t = i / n;
    final p = _bez(base, ctrl, tope, t);
    final tan = (ctrl - base) * (2 * (1 - t)) + (tope - ctrl) * (2 * t);
    final nrm = Offset(-tan.dy, tan.dx) / tan.distance;
    final ancho = (anchoBase + (anchoTope - anchoBase) * t) / 2;
    izq.add(p + nrm * ancho);
    der.add(p - nrm * ancho);
  }
  final path = Path()..moveTo(izq.first.dx, izq.first.dy);
  for (final p in izq.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  for (final p in der.reversed) {
    path.lineTo(p.dx, p.dy);
  }
  c.drawPath(path..close(), relleno(color));
}

/// Fronda que sube y cae por su peso, con foliolos a ambos lados.
void _fronda(
  Canvas c,
  Offset o,
  double grados,
  double largo,
  double caida,
  Color espina,
  Color hojuela,
  double grosor, {
  int foliolos = 9,
}) {
  final a = grados * pi / 180;
  final dir = Offset(cos(a), sin(a));
  final fin = o + dir * largo * 0.9 + Offset(0, largo * caida);
  final ctrl = o + dir * largo * 0.55 + Offset(0, -largo * 0.22);
  c.drawPath(
    Path()
      ..moveTo(o.dx, o.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, fin.dx, fin.dy),
    trazo(espina, grosor * 1.4)..style = PaintingStyle.stroke,
  );
  final fol = trazo(hojuela, grosor);
  for (var k = 1; k <= foliolos; k++) {
    final t = 0.2 + 0.78 * k / foliolos;
    final p = _bez(o, ctrl, fin, t);
    final tan = (ctrl - o) * (2 * (1 - t)) + (fin - ctrl) * (2 * t);
    final u = tan / tan.distance;
    final largoFol = largo * 0.2 * (1 - 0.55 * t);
    for (final lado in [-1.0, 1.0]) {
      final d =
          u * 0.45 + Offset(-u.dy, u.dx) * (0.7 * lado) + const Offset(0, 0.55);
      c.drawLine(p, p + d / d.distance * largoFol, fol);
    }
  }
}

/// Palmera de tronco curvo y fronda en arco de unos 200 grados que cae.
void palmera(Canvas c, Offset base, double alto, Color color) {
  final copa = base + Offset(alto * 0.14, -alto);
  tronco(c, base, copa, -alto * 0.12, alto * 0.07, alto * 0.035, color);
  final clara = mezcla(color, Colors.white, 0.22);
  final g = alto * 0.03;
  const fronda = [
    (-195.0, 0.5, 0.55),
    (-165.0, 0.58, 0.42),
    (-132.0, 0.5, 0.2),
    (-100.0, 0.34, 0.05),
    (-68.0, 0.48, 0.2),
    (-36.0, 0.56, 0.4),
    (-5.0, 0.5, 0.55),
    (22.0, 0.34, 0.6),
  ];
  for (final (a, l, caida) in fronda) {
    _fronda(c, copa, a, alto * l, caida, color, clara, g);
  }
  // Racimo de cocos bajo la copa.
  c
    ..drawCircle(copa + Offset(-g * 0.8, g * 1.4), g * 1.3, relleno(color))
    ..drawCircle(copa + Offset(g * 0.9, g * 1.7), g * 1.2, relleno(color));
}

/// Palma de cera: tronco muy alto y fino; penacho corto arriba y hojas largas
/// que cuelgan casi verticales a los lados.
void palmaCera(Canvas c, Offset base, double alto, Color color, Color hoja) {
  final copa = base + Offset(alto * 0.03, -alto);
  tronco(c, base, copa, alto * 0.04, alto * 0.05, alto * 0.03, color);
  // Anillos claros del tronco.
  final anillo = trazo(mezcla(color, Colors.white, 0.35), alto * 0.008);
  for (var k = 1; k < 9; k++) {
    final y = base.dy - alto * k / 10;
    final x = base.dx + alto * 0.03 * k / 10;
    c.drawLine(Offset(x - alto * 0.02, y), Offset(x + alto * 0.02, y), anillo);
  }
  final clara = mezcla(hoja, Colors.white, 0.3);
  final g = alto * 0.014;
  const fronda = [
    (-90.0, 0.26, 0.0, 6),
    (-115.0, 0.33, 0.2, 7),
    (-65.0, 0.33, 0.2, 7),
    (-142.0, 0.38, 0.7, 8),
    (-38.0, 0.38, 0.7, 8),
    (-170.0, 0.38, 1.15, 8),
    (-10.0, 0.38, 1.15, 8),
  ];
  for (final (a, l, caida, n) in fronda) {
    _fronda(c, copa, a, alto * l, caida, hoja, clara, g, foliolos: n);
  }
}

/// Cardón: tronco con costillas y brazos que salen de lado, hacen un codo y
/// suben.
void cardon(Canvas c, Offset base, double alto, Color color) {
  final ancho = alto * 0.17;
  final claro = mezcla(color, Colors.white, 0.2);
  final oscuro = mezcla(color, Colors.black, 0.14);
  final brazo = trazo(color, ancho * 0.75)..strokeJoin = StrokeJoin.round;
  void unBrazo(double lado, double y, double sale, double sube) {
    final o = base + Offset(0, -alto * y);
    final x = o.dx + lado * alto * (sale + 0.06);
    c.drawPath(
      Path()
        ..moveTo(o.dx, o.dy)
        ..lineTo(o.dx + lado * alto * sale, o.dy)
        ..quadraticBezierTo(x, o.dy, x, o.dy - alto * 0.08)
        ..lineTo(x, o.dy - alto * sube),
      brazo,
    );
  }

  unBrazo(-1, 0.42, 0.2, 0.32);
  unBrazo(1, 0.6, 0.16, 0.24);
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(base.dx - ancho / 2, base.dy - alto, ancho, alto),
      Radius.circular(ancho / 2),
    ),
    relleno(color),
  );
  // Costillas: dos líneas verticales tenues.
  for (final dx in [-0.22, 0.22]) {
    c.drawLine(
      Offset(base.dx + ancho * dx, base.dy - alto * 0.95),
      Offset(base.dx + ancho * dx, base.dy),
      trazo(dx < 0 ? claro : oscuro, ancho * 0.08),
    );
  }
}

/// Maguey: roseta de hojas carnosas y puntiagudas desde una base común.
void maguey(Canvas c, Offset base, double alto, Color color) {
  final claro = mezcla(color, Colors.white, 0.2);
  final o = base + Offset(0, -alto * 0.1);
  const hojas = [
    (-82.0, 1.0),
    (-62.0, 0.92),
    (-102.0, 0.92),
    (-40.0, 0.8),
    (-124.0, 0.8),
    (-16.0, 0.62),
    (-148.0, 0.62),
    (4.0, 0.44),
    (-168.0, 0.44),
  ];
  // Las de los lados atrás, las centrales delante.
  for (final (grados, k) in hojas.reversed) {
    final a = grados * pi / 180;
    final dir = Offset(cos(a), sin(a));
    final punta = o + dir * alto * k;
    final n = Offset(-dir.dy, dir.dx) * alto * 0.085 * (0.6 + 0.4 * k);
    final medio = o + dir * alto * k * 0.5 + Offset(0, -alto * 0.05 * (1 - k));
    c.drawPath(
      Path()
        ..moveTo(o.dx - n.dx * 0.5, o.dy - n.dy * 0.5)
        ..quadraticBezierTo(
          medio.dx - n.dx,
          medio.dy - n.dy,
          punta.dx,
          punta.dy,
        )
        ..quadraticBezierTo(
          medio.dx + n.dx,
          medio.dy + n.dy,
          o.dx + n.dx * 0.5,
          o.dy + n.dy * 0.5,
        )
        ..close(),
      relleno(k > 0.85 ? claro : color),
    );
  }
}

/// Árbol de copa hecha de varias masas redondas superpuestas: la más grande
/// y oscura al fondo, las claras arriba a la izquierda (donde da la luz).
/// [ancho] estira la copa (ceiba: 1.6 o más); el tronco se abre en la base.
void arbolRedondo(
  Canvas c,
  Offset base,
  double alto,
  Color tronco,
  Color copa, {
  double ancho = 1,
}) {
  final cima = base + Offset(alto * 0.03, -alto * 0.52);
  troncoRaiz(c, base, cima, alto, tronco);
  final centro = base + Offset(0, -alto * 0.7);
  final claro = mezcla(copa, Colors.white, 0.14);
  final masClaro = mezcla(copa, Colors.white, 0.26);
  void masa(double dx, double dy, double r, Color color) => c.drawOval(
    Rect.fromCenter(
      center: centro + Offset(dx * alto * ancho, dy * alto),
      width: r * alto * 2 * (0.8 + 0.2 * ancho),
      height: r * alto * 2,
    ),
    relleno(color),
  );
  // Fondo oscuro.
  masa(0, 0, 0.3, copa);
  masa(-0.27, 0.07, 0.22, copa);
  masa(0.28, 0.06, 0.23, copa);
  masa(0.05, 0.16, 0.2, copa);
  // Masas intermedias y de luz.
  masa(-0.06, -0.06, 0.24, claro);
  masa(0.2, -0.02, 0.17, claro);
  masa(-0.22, -0.02, 0.15, claro);
  masa(-0.1, -0.12, 0.14, masClaro);
  masa(0.12, -0.1, 0.1, masClaro);
}

void troncoRaiz(Canvas c, Offset base, Offset cima, double alto, Color color) {
  tronco(c, base, cima, alto * 0.03, alto * 0.13, alto * 0.06, color);
  // Raíces sugeridas: dos arranques cortos en la base.
  for (final lado in [-1.0, 1.0]) {
    c.drawPath(
      Path()
        ..moveTo(base.dx + lado * alto * 0.03, base.dy - alto * 0.18)
        ..quadraticBezierTo(
          base.dx + lado * alto * 0.05,
          base.dy - alto * 0.04,
          base.dx + lado * alto * 0.13,
          base.dy,
        )
        ..lineTo(base.dx + lado * alto * 0.02, base.dy)
        ..close(),
      relleno(color),
    );
  }
}

void arbolPino(Canvas c, Offset base, double alto, Color tronco, Color copa) {
  c.drawRect(
    Rect.fromLTWH(
      base.dx - alto * 0.03,
      base.dy - alto * 0.2,
      alto * 0.06,
      alto * 0.2,
    ),
    relleno(tronco),
  );
  for (var i = 0; i < 3; i++) {
    final y = base.dy - alto * (0.15 + 0.22 * i);
    final a = alto * (0.28 - 0.06 * i);
    c.drawPath(
      Path()
        ..moveTo(base.dx - a, y)
        ..lineTo(base.dx, y - alto * 0.38)
        ..lineTo(base.dx + a, y)
        ..close(),
      relleno(copa),
    );
  }
}

/// Casa de pared lisa con techo a dos aguas, sombra bajo el alero y puerta.
void casa(
  Canvas c,
  Rect r,
  Color pared,
  Color techo,
  Color puerta, {
  double alero = 0.1,
}) {
  c.drawRect(r, relleno(pared));
  // Costado en sombra y zócalo.
  c
    ..drawRect(
      Rect.fromLTRB(r.right - r.width * 0.16, r.top, r.right, r.bottom),
      relleno(Colors.black.withValues(alpha: 0.06)),
    )
    ..drawRect(
      Rect.fromLTRB(r.left, r.bottom - r.height * 0.1, r.right, r.bottom),
      relleno(Colors.black.withValues(alpha: 0.07)),
    );
  // Sombra del alero sobre la pared.
  c.drawRect(
    Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.1),
    relleno(Colors.black.withValues(alpha: 0.1)),
  );
  c.drawPath(
    Path()
      ..moveTo(r.left - r.width * alero, r.top)
      ..lineTo(r.center.dx, r.top - r.height * 0.45)
      ..lineTo(r.right + r.width * alero, r.top)
      ..close(),
    relleno(techo),
  );
  // Vertiente en sombra.
  c.drawPath(
    Path()
      ..moveTo(r.center.dx, r.top - r.height * 0.45)
      ..lineTo(r.right + r.width * alero, r.top)
      ..lineTo(r.center.dx, r.top)
      ..close(),
    relleno(Colors.black.withValues(alpha: 0.08)),
  );
  c.drawRRect(
    RRect.fromRectAndCorners(
      Rect.fromLTWH(
        r.center.dx - r.width * 0.12,
        r.bottom - r.height * 0.55,
        r.width * 0.24,
        r.height * 0.55,
      ),
      topLeft: Radius.circular(r.width * 0.12),
      topRight: Radius.circular(r.width * 0.12),
    ),
    relleno(puerta),
  );
}

/// Edificio con ventanas en cuadrícula; [encendida] decide cuáles tienen luz
/// (sin ella, todas llevan [luz] fija).
void edificio(
  Canvas c,
  Rect r,
  Color color, {
  Color? luz,
  bool Function(int)? encendida,
  double celda = 9,
}) {
  c.drawRect(r, relleno(color));
  if (luz == null) return;
  final columnas = max(1, ((r.width - 4) / celda).floor());
  final filas = max(1, ((r.height - 6) / (celda * 1.4)).floor());
  final ancho = (r.width - 4) / columnas;
  final alto = (r.height - 6) / filas;
  for (var f = 0; f < filas; f++) {
    for (var col = 0; col < columnas; col++) {
      final i = f * columnas + col;
      if (!(encendida?.call(i) ?? true)) continue;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            r.left + 2 + col * ancho + ancho * 0.25,
            r.top + 4 + f * alto + alto * 0.25,
            ancho * 0.5,
            alto * 0.5,
          ),
          const Radius.circular(1),
        ),
        relleno(luz),
      );
    }
  }
}

/// Hilera de edificios de alturas distintas pegados a lo ancho.
void skyline(
  Canvas c,
  Size s,
  Color color, {
  required double base,
  required List<double> alturas,
  Color? luz,
  bool Function(int)? encendida,
}) {
  final ancho = s.width / alturas.length;
  for (var i = 0; i < alturas.length; i++) {
    edificio(
      c,
      Rect.fromLTWH(
        i * ancho,
        s.height * base - s.height * alturas[i],
        ancho + 1,
        s.height * alturas[i] + s.height * (1 - base),
      ),
      color,
      luz: luz,
      encendida: encendida == null ? null : (j) => encendida(i * 100 + j),
    );
  }
}

/// Franja de agua con un degradado de arriba a abajo.
void mar(Canvas c, Size s, double desde, Color arriba, Color abajo) {
  final r = Rect.fromLTWH(0, s.height * desde, s.width, s.height * (1 - desde));
  c.drawRect(
    r,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [arriba, abajo],
      ).createShader(r),
  );
}

/// Línea ondulada (olas, banderines).
Path onda(
  double x0,
  double x1,
  double y,
  double amplitud,
  double fase, {
  double ondas = 4,
}) {
  final path = Path()..moveTo(x0, y + amplitud * sin(fase));
  for (var x = x0; x <= x1; x += 4) {
    path.lineTo(
      x,
      y + amplitud * sin(fase + (x - x0) / (x1 - x0) * ondas * 2 * pi),
    );
  }
  return path;
}
