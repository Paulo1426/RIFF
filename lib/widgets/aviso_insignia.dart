import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../models/genero.dart';
import '../models/logros.dart';
import '../models/nivel.dart';
import '../models/sala.dart';
import '../services/firebase_game_repository.dart';
import '../services/insignias_vistas.dart';
import '../theme.dart';
import 'liquid_glass/liquid_glass_dialog.dart';

/// Avance del jugador para calcular las insignias.
AvanceJuego avanceDe(
  List<ProgresoDificultadRemoto> dificultades,
  EstadoIntros? intros,
  Genero genero,
) {
  int completados(Dificultad dificultad) =>
      dificultades
          .where((item) => item.dificultad == dificultad)
          .firstOrNull
          ?.completados ??
      0;
  return AvanceJuego(
    facil: completados(Dificultad.facil),
    media: completados(Dificultad.medio),
    avanzada: completados(Dificultad.avanzado),
    nivelesPorDificultad: genero.nivelesPorDificultad,
    introsAdivinadas:
        intros?.intros
            .where((item) => item.estado == EstadoIntro.completada)
            .length ??
        0,
    totalIntros: intros == null
        ? genero.totalIntros
        : intros.intros.length + intros.restantes,
    unInstrumento: dificultades.fold(
      0,
      (total, item) => total + item.unInstrumento,
    ),
  );
}

/// Insignias conseguidas que el jugador aún no ha visto (las marca como
/// vistas). Pensado para llamarse justo tras acertar un nivel o una intro.
/// Ante cualquier fallo o tardanza devuelve vacío: el menú las avisará luego.
Future<List<Logro>> insigniasNuevas(FirebaseGameRepository repo) async {
  final uid = repo.uid;
  if (uid == null) return const [];
  try {
    final genero = generoActivo;
    final resultados = await Future.wait<Object?>([
      repo.cargarEstado(),
      repo.cargarIntros().then<EstadoIntros?>((e) => e, onError: (_) => null),
      repo.saldoSalas().first.then<SaldoSalas>(
        (s) => s,
        onError: (_) => const SaldoSalas(),
      ),
    ]).timeout(const Duration(seconds: 3));
    final estado = resultados[0]! as EstadoJuegoRemoto;
    final logrados = {
      for (final logro in logrosDe(
        resultados[2]! as SaldoSalas,
        avanceDe(estado.dificultades, resultados[1] as EstadoIntros?, genero),
        genero,
      ))
        if (logro.logrado) logro.nombre: logro,
    };
    final nuevas = await InsigniasVistas(uid).registrar(logrados.keys.toSet());
    return [for (final nombre in nuevas) logrados[nombre]!];
  } catch (error) {
    debugPrint('No se pudieron revisar las insignias: $error');
    return const [];
  }
}

/// Muestra las tarjetas una tras otra.
Future<void> mostrarInsignias(BuildContext context, List<Logro> logros) async {
  for (final logro in logros) {
    if (!context.mounted) return;
    await mostrarInsignia(context, logro);
  }
}

/// Avisa que se consiguió [logro]. La maestra del género (Vallenatólogo,
/// Rey del perreo...) sale con una corona gigante.
Future<void> mostrarInsignia(BuildContext context, Logro logro) {
  if (logro.dorada) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black87,
      pageBuilder: (context, _, _) => _Corona(logro: logro),
    );
  }
  final color = colorInsignia(logro.nivel);
  return showDialog<void>(
    context: context,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      return LiquidGlassDialog(
        icon: _Aparece(
          child: Text(logro.emoji, style: const TextStyle(fontSize: 72)),
        ),
        title: const Text('¡Nueva insignia!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              logro.nombre,
              textAlign: TextAlign.center,
              style: text.titleLarge?.copyWith(
                color: context.paleta.tonoTexto(color),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(logro.condicion, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('¡Genial!'),
          ),
        ],
      );
    },
  );
}

/// Crece con un rebote al aparecer.
class _Aparece extends StatelessWidget {
  const _Aparece({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 900),
    curve: Curves.elasticOut,
    builder: (context, t, hijo) => Transform.scale(scale: t, child: hijo),
    child: child,
  );
}

/// Pantalla completa: corona gigante, confeti dorado y felicitaciones.
class _Corona extends StatefulWidget {
  const _Corona({required this.logro});

  final Logro logro;

  @override
  State<_Corona> createState() => _CoronaState();
}

class _CoronaState extends State<_Corona> {
  final _confeti = ConfettiController(duration: const Duration(seconds: 3))
    ..play();

  @override
  void dispose() {
    _confeti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ancho = MediaQuery.sizeOf(context).shortestSide;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confeti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 40,
              colors: const [
                AppColors.oro,
                AppColors.medio,
                AppColors.paperWhite,
              ],
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Aparece(
                    child: Text(
                      '👑',
                      style: TextStyle(
                        fontSize: ancho * 0.55,
                        shadows: const [
                          Shadow(blurRadius: 40, color: AppColors.oro),
                        ],
                      ),
                    ),
                  ),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      '¡Felicitaciones!',
                      textAlign: TextAlign.center,
                      style: text.displaySmall?.copyWith(color: AppColors.oro),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Eres un ${widget.logro.nombre}: ganaste 30 salas y '
                    'completaste el 100 % del juego.',
                    textAlign: TextAlign.center,
                    style: text.titleMedium?.copyWith(
                      color: AppColors.paperWhite,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.oro,
                      foregroundColor: AppColors.graphiteInk,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('¡Soy ${widget.logro.nombre}!'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
