import 'dart:math';

import 'package:flutter/material.dart';

import '../animations/ciclo_lento.dart';
import '../theme.dart';
import 'liquid_glass/liquid_glass_card.dart';

/// Colores del login: los de la app, verde de la marca y naranja de acción.
const verdeLogin = AppColors.verde;
const naranjaLogin = AppColors.signalOrange;

/// Fondo del login: los instrumentos de la app (batería, acordeón, guitarra
/// y bajo) repartidos por la pantalla, flotando despacio, cada uno con un
/// brillo de los colores de la app.
class FondoLogin extends StatefulWidget {
  const FondoLogin({super.key});

  @override
  State<FondoLogin> createState() => _FondoLoginState();
}

class _FondoLoginState extends State<FondoLogin> {
  // (emoji, posición, color del brillo, tamaño, desfase de la animación)
  // En los bordes y esquinas: asoman alrededor de la tarjeta del login.
  static const _instrumentos = [
    ('🥁', Alignment(-0.95, -0.97), AppColors.signalOrange, 50.0, 0.0),
    ('🪗', Alignment(0.95, -0.95), AppColors.verde, 54.0, 0.25),
    ('🎸', Alignment(-1.08, -0.25), AppColors.medio, 48.0, 0.5),
    ('🎵', Alignment(1.08, 0.1), AppColors.avanzado, 42.0, 0.75),
    ('🪗', Alignment(-1.05, 0.55), AppColors.verde, 48.0, 0.4),
    ('🎸', Alignment(0.95, 0.98), AppColors.medio, 50.0, 0.9),
    ('🥁', Alignment(-0.55, 1.0), AppColors.signalOrange, 44.0, 0.6),
  ];

  // Flotan despacio: basta el reloj compartido de 30 cuadros.
  final _ciclo = CicloLento(periodo: const Duration(seconds: 6));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Quieto con "reducir movimiento" o con la pantalla tapada por otra.
    _ciclo.activo =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  // Capa propia: mover los instrumentos no repinta el formulario de encima.
  Widget build(BuildContext context) => RepaintBoundary(
    child: ExcludeSemantics(
      child: ColoredBox(
        color: context.paleta.oscuro
            ? const Color(0xFF0B0F17)
            : context.paleta.fondo,
        child: AnimatedBuilder(
          animation: _ciclo,
          builder: (context, _) => Stack(
            children: [
              for (final (emoji, donde, color, tamano, desfase)
                  in _instrumentos)
                _instrumento(emoji, donde, color, tamano, desfase),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _instrumento(
    String emoji,
    Alignment donde,
    Color color,
    double tamano,
    double desfase,
  ) {
    final t = (_ciclo.value + desfase) * 2 * pi;
    return Align(
      alignment: donde,
      child: Transform.translate(
        // Sube y baja, y se mece un poco, cada uno a su ritmo.
        offset: Offset(0, 10 * sin(t)),
        child: Transform.rotate(
          angle: 0.18 * sin(t + 1),
          child: Container(
            width: tamano * 1.9,
            height: tamano * 1.9,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.35),
                  color.withValues(alpha: 0),
                ],
              ),
            ),
            child: Text(emoji, style: TextStyle(fontSize: tamano)),
          ),
        ),
      ),
    );
  }
}

/// Logo dentro de un círculo con degradado y brillo.
class LogoCircular extends StatelessWidget {
  const LogoCircular({super.key, this.tamano = 88});

  final double tamano;

  @override
  Widget build(BuildContext context) => Container(
    width: tamano,
    height: tamano,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(colors: [verdeLogin, naranjaLogin]),
      boxShadow: [
        BoxShadow(color: verdeLogin.withValues(alpha: 0.5), blurRadius: 24),
      ],
    ),
    child: ClipOval(
      child: ColoredBox(
        color: context.paleta.superficie,
        child: Image.asset(
          'lib/assets/images/logo/riff_logo.png',
          fit: BoxFit.contain,
          semanticLabel: 'Riff',
        ),
      ),
    ),
  );
}

/// Botón principal del login: píldora con degradado cian a morado y brillo.
class BotonDegradado extends StatelessWidget {
  const BotonDegradado({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onPressed == null ? 0.5 : 1,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [verdeLogin, naranjaLogin]),
        boxShadow: [
          BoxShadow(color: verdeLogin.withValues(alpha: 0.35), blurRadius: 18),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.paperWhite,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Bordes de los campos del login: contorno cian con la etiqueta arriba.
InputDecorationTheme camposLogin(BuildContext context) {
  OutlineInputBorder borde(Color color, double ancho) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color, width: ancho),
  );
  final error = Theme.of(context).colorScheme.error;
  return InputDecorationTheme(
    filled: true,
    fillColor: context.paleta.superficie.withValues(alpha: 0.25),
    border: borde(verdeLogin.withValues(alpha: 0.5), 1.2),
    enabledBorder: borde(verdeLogin.withValues(alpha: 0.5), 1.2),
    focusedBorder: borde(verdeLogin, 2),
    errorBorder: borde(error, 1.2),
    focusedErrorBorder: borde(error, 2),
    floatingLabelStyle: TextStyle(
      color: context.paleta.oscuro
          ? verdeLogin
          : context.paleta.tonoTexto(verdeLogin),
      fontWeight: FontWeight.w700,
    ),
  );
}

/// Pantalla breve tras iniciar sesión: check que se dibuja, "¡Sesión
/// iniciada!" y tres puntos; luego avisa con [onFin].
class BienvenidaLogin extends StatefulWidget {
  const BienvenidaLogin({super.key, required this.nombre, required this.onFin});

  final String? nombre;
  final VoidCallback onFin;

  @override
  State<BienvenidaLogin> createState() => _BienvenidaLoginState();
}

class _BienvenidaLoginState extends State<BienvenidaLogin>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward().whenComplete(() => widget.onFin());

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const FondoLogin(),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: LiquidGlassCard(
                  opacity: 0.4,
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) {
                      final t = _anim.value;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox.square(
                            dimension: 96,
                            child: CustomPaint(
                              painter: _Check(
                                avance: Curves.easeOut.transform(
                                  (t / 0.6).clamp(0.0, 1.0),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Opacity(
                            opacity: ((t - 0.35) / 0.25).clamp(0.0, 1.0),
                            child: Column(
                              children: [
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    '¡Sesión iniciada!',
                                    textAlign: TextAlign.center,
                                    style: text.headlineSmall?.copyWith(
                                      color: AppColors.verde,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  widget.nombre == null
                                      ? 'Bienvenido a RIFF'
                                      : 'Bienvenido, ${widget.nombre}',
                                  textAlign: TextAlign.center,
                                  style: text.bodyMedium?.copyWith(
                                    color: context.paleta.tintaSuave,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Tres puntos que se encienden por turnos.
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < 3; i++)
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.verde.withValues(
                                      alpha:
                                          0.3 +
                                          0.7 *
                                              max(
                                                0,
                                                sin((t * 3 - i * 0.33) * pi),
                                              ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Círculo verde que se dibuja y, después, el check dentro.
class _Check extends CustomPainter {
  _Check({required this.avance});

  final double avance;

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = AppColors.verde
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final centro = size.center(Offset.zero);
    final radio = size.width / 2 - 4;
    canvas.drawCircle(
      centro,
      radio,
      Paint()
        ..color = AppColors.verde.withValues(alpha: 0.25 * avance)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawArc(
      Rect.fromCircle(center: centro, radius: radio),
      -pi / 2,
      2 * pi * (avance / 0.6).clamp(0.0, 1.0),
      false,
      pincel,
    );
    final check = ((avance - 0.6) / 0.4).clamp(0.0, 1.0);
    if (check == 0) return;
    final a = Offset(size.width * 0.3, size.height * 0.52);
    final b = Offset(size.width * 0.45, size.height * 0.66);
    final c = Offset(size.width * 0.72, size.height * 0.38);
    final camino = Path()..moveTo(a.dx, a.dy);
    if (check < 0.4) {
      camino.lineTo(
        a.dx + (b.dx - a.dx) * check / 0.4,
        a.dy + (b.dy - a.dy) * check / 0.4,
      );
    } else {
      final k = (check - 0.4) / 0.6;
      camino
        ..lineTo(b.dx, b.dy)
        ..lineTo(b.dx + (c.dx - b.dx) * k, b.dy + (c.dy - b.dy) * k);
    }
    canvas.drawPath(camino, pincel);
  }

  @override
  bool shouldRepaint(_Check old) => old.avance != avance;
}
