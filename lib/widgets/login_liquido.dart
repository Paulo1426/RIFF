import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'liquid_glass/liquid_glass_card.dart';

/// Colores del login: los azules del logo (rey y celeste).
const azulLogin = Color(0xFF1E5BC6);
const celesteLogin = Color(0xFF6FB1F5);

/// Fondo del login: liso, sin adornos que distraigan del formulario.
class FondoLogin extends StatelessWidget {
  const FondoLogin({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.paleta.oscuro
        ? const Color(0xFF0B0F17)
        : context.paleta.fondo,
  );
}

/// Colores del icono de la app: naranja, amarillo y rojo.
const bordeIconoApp = SweepGradient(
  // El naranja se repite al final para que la vuelta cierre sin corte.
  colors: [
    Color(0xFFFF8C42),
    Color(0xFFFFD100),
    Color(0xFFCE1126),
    Color(0xFFFF8C42),
  ],
);

/// Logo suelto, sin círculo detrás.
class LogoCircular extends StatelessWidget {
  const LogoCircular({super.key, this.tamano = 88});

  final double tamano;

  @override
  Widget build(BuildContext context) => Image.asset(
    'lib/assets/images/logo/riff_logo.png',
    height: tamano,
    fit: BoxFit.contain,
    cacheWidth: 384,
    semanticLabel: 'Riff',
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
        gradient: const LinearGradient(colors: [azulLogin, celesteLogin]),
        boxShadow: [
          BoxShadow(color: azulLogin.withValues(alpha: 0.35), blurRadius: 18),
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
    border: borde(azulLogin.withValues(alpha: 0.5), 1.2),
    enabledBorder: borde(azulLogin.withValues(alpha: 0.5), 1.2),
    focusedBorder: borde(azulLogin, 2),
    errorBorder: borde(error, 1.2),
    focusedErrorBorder: borde(error, 2),
    floatingLabelStyle: TextStyle(
      color: context.paleta.oscuro
          ? azulLogin
          : context.paleta.tonoTexto(azulLogin),
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
    // Más larga: es la única señal de que la sesión se inició.
    duration: const Duration(milliseconds: 2800),
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
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
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
                                        color: azulLogin,
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
                                      color: azulLogin.withValues(
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
          ),
        ],
      ),
    );
  }
}

/// Círculo azul que se dibuja y, después, el check dentro.
class _Check extends CustomPainter {
  _Check({required this.avance});

  final double avance;

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = azulLogin
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final centro = size.center(Offset.zero);
    final radio = size.width / 2 - 4;
    canvas.drawCircle(
      centro,
      radio,
      Paint()
        ..color = azulLogin.withValues(alpha: 0.25 * avance)
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
