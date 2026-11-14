import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../animations/liquid_ripple_effect.dart';
import '../models/genero.dart';
import '../models/instrumento.dart';
import '../services/sonidos_instrumento.dart';
import '../theme.dart';
import 'liquid_glass/liquid_glass_button.dart';
import 'liquid_glass/liquid_glass_card.dart';

/// Pantalla sin red: tres instrumentos para tocar mientras vuelve la
/// conexión, y debajo el aviso.
class SinConexion extends StatefulWidget {
  const SinConexion({super.key, required this.onReintentar});

  final VoidCallback onReintentar;

  @override
  State<SinConexion> createState() => _SinConexionState();
}

class _SinConexionState extends State<SinConexion> {
  // En otro orden cada vez que se abre.
  late final _instrumentos = List.of(instrumentosComunes)..shuffle();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = colorGenero(generoActivo);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  for (final (i, tipo) in _instrumentos.indexed) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: _Instrumento(tipo: tipo, color: color),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'No hay conexión a internet',
                textAlign: TextAlign.center,
                style: text.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Toca los instrumentos mientras vuelve la red.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: context.paleta.tintaSuave,
                ),
              ),
              const SizedBox(height: 20),
              LiquidGlassButton(
                onPressed: widget.onReintentar,
                icon: Icons.refresh_rounded,
                label: 'Reintentar',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Instrumento extends StatefulWidget {
  const _Instrumento({required this.tipo, required this.color});

  final TipoInstrumento tipo;
  final Color color;

  @override
  State<_Instrumento> createState() => _InstrumentoState();
}

class _InstrumentoState extends State<_Instrumento> {
  AudioPlayer? _player;
  bool _cargado = false;
  // Cada toque reinicia el rebote.
  int _toques = 0;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _tocar() async {
    HapticFeedback.selectionClick();
    setState(() => _toques++);
    try {
      final player = _player ??= AudioPlayer();
      if (!_cargado) {
        await player.setAudioSource(FuenteBytes(sonidoDe(widget.tipo)));
        _cargado = true;
      }
      await player.seek(Duration.zero);
      await player.play();
    } catch (error) {
      debugPrint('No se pudo sonar ${widget.tipo.name}: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return TweenAnimationBuilder<double>(
      key: ValueKey(_toques),
      tween: Tween(begin: _toques == 0 ? 1 : 0.85, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (context, escala, hijo) =>
          Transform.scale(scale: escala, child: hijo),
      child: Semantics(
        button: true,
        label: 'Tocar ${widget.tipo.nombre}',
        child: LiquidGlassCard(
          borderRadius: 20,
          tintColor: widget.color,
          child: LiquidRippleEffect(
            onTap: _tocar,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.tipo.emoji, style: const TextStyle(fontSize: 44)),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(widget.tipo.nombre, style: text.titleSmall),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
