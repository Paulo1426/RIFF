import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/instrumento.dart';
import '../models/nivel.dart';
import '../models/partida.dart';
import '../providers/providers.dart';
import '../services/audio_service.dart';
import '../services/firebase_game_repository.dart';
import '../services/offline_game_store.dart';
import '../theme.dart';

enum ResultadoNivel { terminar, siguiente }

class GameScreen extends ConsumerStatefulWidget {
  final Nivel nivel;
  final String gameId;
  final int? numeroVisible;
  // Abre el siguiente nivel en lugar de este; null si no hay siguiente.
  final VoidCallback? onSiguiente;
  final bool offlineMode;
  final OfflineLevelData? offlineLevel;
  final Future<void> Function(String levelId, String answer)?
  onOfflineCompleted;

  const GameScreen({
    super.key,
    required this.nivel,
    required this.gameId,
    this.numeroVisible,
    this.onSiguiente,
    this.offlineMode = false,
    this.offlineLevel,
    this.onOfflineCompleted,
  });

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final _answerController = TextEditingController();
  late final AudioService _audioService;
  bool _sending = false;
  bool _buying = false;
  bool _playing = false;
  bool _paused = false;
  String _nowPlaying = '';
  // Instrumentos sonando; vacío cuando suena la canción completa.
  List<Instrumento> _nowPlayingInstruments = const [];
  int _descuento = 0;
  int _descuentoId = 0;
  String? _message;
  bool? _correct;
  int _balance = Nivel.presupuestoTotal;
  final Set<String> _purchased = {};
  final Map<String, int> _prices = {};
  bool _melodyFound = false;
  bool _won = false;
  bool _avanzando = false;
  late bool _playingOffline;
  int _playbackGeneration = 0;
  late final Partida? _offlinePartida;

  @override
  void initState() {
    super.initState();
    _audioService = ref.read(audioServiceProvider);
    _playingOffline = widget.offlineMode;
    _offlinePartida = widget.offlineLevel != null
        ? Partida(
            instrumentos: widget.nivel.instrumentos,
            random: Random.secure(),
          )
        : null;
  }

  @override
  void dispose() {
    _playbackGeneration++;
    _answerController.dispose();
    unawaited(_stopAudioOnDispose());
    super.dispose();
  }

  Future<void> _stopAudioOnDispose() async {
    try {
      await _audioService.detener();
    } catch (error, stackTrace) {
      debugPrint('No se pudo detener el audio al salir del nivel: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _buyAndPlay(Instrumento instrumento) async {
    if (_buying || _playing || _won) return;
    if (_melodyFound || _purchased.contains(instrumento.id)) {
      try {
        await _playStems([instrumento]);
      } catch (error) {
        if (mounted) {
          setState(
            () => _message = 'No se pudo reproducir el instrumento: $error',
          );
        }
      }
      return;
    }

    setState(() {
      _buying = true;
      _message = null;
    });
    if (_playingOffline) {
      await _buyOfflineInstrument(instrumento);
      return;
    }
    try {
      final repository = ref.read(firebaseGameRepositoryProvider);
      final result = await repository.comprarInstrumento(
        gameId: widget.gameId,
        instrumento: instrumento.id,
      );
      if (!mounted) return;
      setState(() {
        if (result.compraRealizada) {
          _prices[instrumento.id] = result.precioInstrumento;
        }
        _setBalance(result.presupuestoRestante);
        _purchased
          ..clear()
          ..addAll(result.instrumentosComprados);
        _melodyFound = result.melodiaDescubierta;
        _message = result.melodiaDescubierta
            ? '¡Encontraste la melodía! Se desbloquearon todos los instrumentos.'
            : null;
      });
      try {
        await _playStems([instrumento]);
      } catch (error) {
        if (!mounted) return;
        setState(
          () => _message = 'No se pudo reproducir el instrumento: $error',
        );
      }
    } catch (error) {
      if (widget.offlineLevel != null && mounted) {
        debugPrint('No se pudo comprar online; continuará offline: $error');
        setState(() => _playingOffline = true);
        await _buyOfflineInstrument(instrumento);
        return;
      }
      if (mounted) {
        setState(() => _message = 'No se pudo comprar el instrumento: $error');
      }
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Future<void> _buyOfflineInstrument(Instrumento instrumento) async {
    try {
      final partida = _offlinePartida!;
      if (!partida.comprarTipo(instrumento.tipo)) {
        throw StateError('No se pudo comprar el instrumento offline');
      }
      final price = partida.precioDe(instrumento.tipo)!;
      var melodyFound = false;
      if (partida.comprados.length == Partida.maxInstrumentosComprados) {
        final random = Random.secure();
        final unpurchased = widget.nivel.instrumentos
            .where((item) => !partida.comprados.contains(item.tipo))
            .toList(growable: false);
        final melody = unpurchased.isNotEmpty && random.nextBool()
            ? unpurchased.first.tipo
            : partida.comprados[random.nextInt(partida.comprados.length)];
        partida.descubrirMelodia(melody);
        melodyFound = partida.melodiaDescubierta;
      }
      if (!mounted) return;
      setState(() {
        _prices[instrumento.id] = price;
        _setBalance(partida.presupuestoRestante);
        _purchased
          ..clear()
          ..addAll(partida.comprados.map((item) => item.id));
        _melodyFound = melodyFound;
        _message = melodyFound
            ? '¡Encontraste la melodía! Se desbloquearon todos los instrumentos.'
            : null;
      });
      await _playStems([instrumento]);
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = 'No se pudo comprar el instrumento offline: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  // Llamar dentro de setState: guarda el descuento para animarlo.
  void _setBalance(int nuevo) {
    if (nuevo < _balance) {
      _descuento = _balance - nuevo;
      _descuentoId++;
    }
    _balance = nuevo;
  }

  Widget _presupuesto() {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('Presupuesto restante: '),
        TweenAnimationBuilder<int>(
          tween: IntTween(end: _balance),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) =>
              Text('\$${formatearMiles(value)}', style: text.titleMedium),
        ),
        const SizedBox(width: 8),
        if (_descuentoId > 0)
          // La clave reinicia la animación en cada compra.
          TweenAnimationBuilder<double>(
            key: ValueKey(_descuentoId),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeOut,
            builder: (context, t, child) => Opacity(
              opacity: 1 - t,
              child: Transform.translate(
                offset: Offset(0, -18 * t),
                child: child,
              ),
            ),
            child: Text(
              '-\$${formatearMiles(_descuento)}',
              style: text.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _playPurchased() async {
    if (_playing || _buying) return;
    final instruments = widget.nivel.instrumentos
        .where((instrument) => _purchased.contains(instrument.id))
        .toList(growable: false);
    if (instruments.isEmpty) return;
    try {
      await _playStems(instruments);
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = 'No se pudieron reproducir los instrumentos: $error',
        );
      }
    }
  }

  Future<void> _playStems(List<Instrumento> instruments) async {
    final playbackGeneration = ++_playbackGeneration;
    setState(() {
      _playing = true;
      _paused = false;
      _nowPlaying = '';
      _nowPlayingInstruments = instruments;
    });
    try {
      final repository = ref.read(firebaseGameRepositoryProvider);
      final audio = await Future.wait(
        instruments.map((instrument) async {
          final cacheKey = 'level:${widget.nivel.id}:stem:${instrument.id}';
          final offlinePath = widget.offlineLevel?.audioPaths[instrument.id];
          if (offlinePath != null && await File(offlinePath).exists()) {
            return (Uri.file(offlinePath).toString(), null);
          }
          if (_playingOffline) {
            throw StateError(
              'El audio ${instrument.nombre} no está descargado en este dispositivo',
            );
          }
          final cachedFile = await _audioService.cachedFile(cacheKey);
          if (cachedFile != null) {
            return (Uri.file(cachedFile.path).toString(), null);
          }
          final url = await repository.obtenerUrlAudio(
            gameId: widget.gameId,
            tipo: 'stem',
            instrumento: instrument.id,
          );
          return (url, cacheKey);
        }),
      );
      if (!mounted) return;
      await _audioService.reproducir(
        urls: audio.map((item) => item.$1).toList(growable: false),
        cacheKeys: audio.map((item) => item.$2).toList(growable: false),
        duracion: Duration(seconds: widget.nivel.duracionFragmentoSegundos),
      );
    } finally {
      if (mounted && playbackGeneration == _playbackGeneration) {
        setState(() {
          _playing = false;
          _paused = false;
        });
      }
    }
  }

  Future<void> _playSong(String type, {bool replaceCurrent = false}) async {
    if (_playing && !replaceCurrent) return;
    if (_playingOffline && type == 'fullSong') {
      setState(
        () => _message =
            'La canción completa se reproducirá cuando tengas conexión a internet.',
      );
      return;
    }
    final playbackGeneration = ++_playbackGeneration;
    setState(() {
      _playing = true;
      _paused = false;
      _nowPlaying = type == 'instrumentalSong'
          ? 'Canción sin voz'
          : 'Canción original';
      _nowPlayingInstruments = const [];
    });
    try {
      String url;
      String? cacheKey;
      if (type == 'instrumentalSong') {
        final offlinePath = widget.offlineLevel?.instrumentalAudioPath;
        if (offlinePath != null && await File(offlinePath).exists()) {
          url = Uri.file(offlinePath).toString();
        } else {
          final instrumentalCacheKey =
              'song:${widget.nivel.cancionId}:instrumentalSong';
          final cachedFile = await _audioService.cachedFile(
            instrumentalCacheKey,
          );
          if (cachedFile != null) {
            url = Uri.file(cachedFile.path).toString();
          } else if (_playingOffline) {
            throw StateError(
              'La pista instrumental no está descargada en este dispositivo',
            );
          } else {
            url = await ref
                .read(firebaseGameRepositoryProvider)
                .obtenerUrlAudio(gameId: widget.gameId, tipo: type);
            cacheKey = instrumentalCacheKey;
          }
        }
      } else {
        url = await ref
            .read(firebaseGameRepositoryProvider)
            .obtenerUrlAudio(gameId: widget.gameId, tipo: type);
      }
      if (!mounted) return;
      await _audioService.reproducir(
        urls: [url],
        cacheKeys: [cacheKey],
        duracion: null,
      );
    } catch (error) {
      if (mounted) {
        if (widget.offlineLevel != null && type == 'fullSong') {
          setState(() {
            _playingOffline = true;
            _message =
                'La canción completa se reproducirá cuando tengas conexión a internet.';
          });
          return;
        }
        setState(
          () => _message = type == 'instrumentalSong'
              ? 'No se pudo reproducir la pista instrumental: $error'
              : 'No se pudo reproducir la canción: $error',
        );
      }
    } finally {
      if (mounted && playbackGeneration == _playbackGeneration) {
        setState(() {
          _playing = false;
          _paused = false;
        });
      }
    }
  }

  Future<void> _togglePause() async {
    if (_paused) {
      _audioService.reanudar();
    } else {
      await _audioService.pausar();
    }
    if (mounted) setState(() => _paused = !_paused);
  }

  Widget _reproductor() {
    return Vidrio(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 40,
              child: _nowPlayingInstruments.isEmpty
                  ? DiscoGirando(girando: !_paused)
                  : FittedBox(
                      child: Text(
                        _nowPlayingInstruments
                            .map((item) => _emojiDe(item.tipo))
                            .join(),
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _paused ? 'En pausa' : 'Reproduciendo',
                    style: _nowPlaying.isEmpty
                        ? Theme.of(context).textTheme.titleSmall
                        : Theme.of(context).textTheme.labelSmall,
                  ),
                  if (_nowPlaying.isNotEmpty)
                    Text(
                      _nowPlaying,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                ],
              ),
            ),
            IconButton.filled(
              tooltip: _paused ? 'Reanudar' : 'Pausar',
              onPressed: _togglePause,
              icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
            ),
            IconButton(
              tooltip: 'Detener',
              onPressed: () => _audioService.detener(),
              icon: const Icon(Icons.stop),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitAnswer() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _message = null;
      _correct = null;
    });
    try {
      if (_playingOffline) {
        await _checkOfflineAnswer(answer);
        return;
      }
      final correct = await ref
          .read(firebaseGameRepositoryProvider)
          .enviarRespuesta(gameId: widget.gameId, respuesta: answer);
      if (!mounted) return;
      if (correct) {
        _playbackGeneration++;
        setState(() {
          _won = true;
          _correct = true;
          _message = '¡Correcto! Reproduciendo la canción original.';
        });
        try {
          await _audioService.detener();
        } catch (error) {
          if (mounted) {
            setState(() {
              _playing = false;
              _message =
                  'Respuesta correcta, pero no se pudo detener el audio anterior: $error';
            });
          }
          return;
        }
        if (!mounted) return;
        await _playSong('fullSong', replaceCurrent: true);
      } else {
        setState(() {
          _correct = false;
          _message = 'Esa no es la canción. Intenta de nuevo.';
        });
      }
    } catch (error) {
      if (mounted) {
        if (widget.offlineLevel != null &&
            !_playingOffline &&
            error is! GameRepositoryException) {
          debugPrint('No se pudo validar online; comprobando offline: $error');
          setState(() => _playingOffline = true);
          try {
            await _checkOfflineAnswer(answer);
          } catch (offlineError) {
            if (mounted) {
              setState(
                () => _message =
                    'No se pudo guardar el progreso offline: $offlineError',
              );
            }
          }
        } else {
          setState(() {
            if (error is GameRepositoryException && error.statusCode == 429) {
              _message = error.message;
            } else {
              _message = _playingOffline
                  ? 'No se pudo guardar el progreso offline: $error'
                  : 'No se pudo validar la respuesta: $error';
            }
          });
        }
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _checkOfflineAnswer(String answer) async {
    final offlineLevel = widget.offlineLevel;
    if (offlineLevel == null) {
      throw StateError('El nivel no está guardado para jugar offline');
    }
    final correct =
        OfflineGameStore.normalizeAnswer(answer) ==
        OfflineGameStore.normalizeAnswer(offlineLevel.respuesta);
    if (!mounted) return;
    if (!correct) {
      setState(() {
        _correct = false;
        _message = 'Esa no es la canción. Intenta de nuevo.';
      });
      return;
    }
    await widget.onOfflineCompleted?.call(widget.nivel.id, answer);
    if (!mounted) return;
    _playbackGeneration++;
    setState(() {
      _won = true;
      _correct = true;
      _message =
          '¡Correcto! La canción completa se reproducirá cuando tengas conexión a internet.';
    });
    await _audioService.detener();
  }

  Widget _instrumentoTile(Instrumento instrumento) {
    final comprado = _purchased.contains(instrumento.id);
    final limite = !_melodyFound && !comprado && _purchased.length >= 3;
    final disponible = !(_buying || _playing || _won || limite);
    final precio = _prices[instrumento.id];
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Tooltip(
      message: limite
          ? 'Ya compraste el máximo de 3 instrumentos'
          : comprado || _melodyFound
          ? 'Escuchar ${instrumento.nombre}'
          : 'Comprar y escuchar ${instrumento.nombre}',
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radioVidrio),
          side: BorderSide(
            color: comprado
                ? scheme.primary
                : AppColors.purePaper.withValues(alpha: 0.85),
            width: comprado ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: disponible ? () => _buyAndPlay(instrumento) : null,
          child: Opacity(
            opacity: disponible ? 1 : 0.45,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    _emojiDe(instrumento.tipo),
                    style: const TextStyle(fontSize: 40),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(instrumento.nombre, style: text.titleMedium),
                  ),
                  if (precio != null)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '\$${formatearMiles(precio)}',
                        style: text.titleSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Icon(
                    comprado || _melodyFound
                        ? Icons.play_arrow
                        : Icons.shopping_cart,
                    size: 26,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope<ResultadoNivel>(
    // Al ganar, volver atrás también avisa para recargar el progreso.
    canPop: !_won,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !_avanzando) {
        Navigator.of(context).pop(ResultadoNivel.terminar);
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text('Nivel ${widget.numeroVisible ?? widget.nivel.numero}'),
      ),
      body: FondoRiff(
        child: ConCarga(
          cargando: _sending || _avanzando,
          texto: _avanzando
              ? 'Cargando siguiente nivel...'
              : 'Comprobando respuesta...',
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.nivel.modoPrueba
                    ? 'Modo de prueba: ${widget.nivel.duracionFragmentoSegundos} segundos por escucha.'
                    : 'Compra un instrumento para escuchar un fragmento de la canción.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _presupuesto(),
              const SizedBox(height: 4),
              Text(
                'Puedes comprar hasta 3 de los ${widget.nivel.instrumentos.length} instrumentos.',
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.25,
                children: [
                  for (final instrumento in widget.nivel.instrumentos)
                    _instrumentoTile(instrumento),
                ],
              ),
              if (_purchased.isNotEmpty && !_melodyFound) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _buying || _playing ? null : _playPurchased,
                  icon: const Icon(Icons.queue_music),
                  label: const Text('Escuchar instrumentos comprados'),
                ),
              ],
              if (_melodyFound) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _playing
                      ? null
                      : () => _playSong('instrumentalSong'),
                  icon: const Icon(Icons.queue_music),
                  label: const Text('Escuchar canción'),
                ),
              ],
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                child: _playing
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _reproductor(),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const Divider(height: 32),
              TextField(
                controller: _answerController,
                enabled: !_sending,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitAnswer(),
                decoration: const InputDecoration(
                  labelText: '¿Qué canción es?',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(
                  _message!,
                  style: TextStyle(
                    color: _correct == false
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_won) ...[
                FilledButton.icon(
                  onPressed: _playing || _playingOffline
                      ? null
                      : () => _playSong('fullSong'),
                  icon: const Icon(Icons.library_music),
                  label: Text(
                    _playingOffline
                        ? 'Canción original disponible con internet'
                        : 'Escuchar canción original',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _avanzando
                            ? null
                            : () => Navigator.of(
                                context,
                              ).pop(ResultadoNivel.terminar),
                        child: const Text('Terminar nivel'),
                      ),
                    ),
                    if (widget.onSiguiente != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _avanzando
                              ? null
                              : () {
                                  setState(() => _avanzando = true);
                                  widget.onSiguiente!();
                                },
                          child: const Text('Siguiente nivel'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              if (!_won)
                FilledButton(
                  onPressed: _sending ? null : _submitAnswer,
                  child: const Text('Comprobar respuesta'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 1000000 -> 1.000.000
String formatearMiles(int valor) => valor.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => '.',
);

String _emojiDe(TipoInstrumento tipo) => switch (tipo) {
  TipoInstrumento.bateria => '🥁',
  TipoInstrumento.acordeon => '🪗',
  TipoInstrumento.guitarra => '🎸',
  TipoInstrumento.bajo => '🎵',
};
