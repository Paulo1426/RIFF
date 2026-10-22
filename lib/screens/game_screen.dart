import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/instrumento.dart';
import '../models/nivel.dart';
import '../models/partida.dart';
import '../providers/providers.dart';
import '../services/audio_service.dart';
import '../services/firebase_game_repository.dart';
import '../services/musica_menu.dart';
import '../services/offline_game_store.dart';
import '../widgets/liquid_glass/liquid_background.dart';
import '../animations/liquid_ripple_effect.dart';
import '../animations/sound_wave_animation.dart';
import '../theme.dart';
import '../widgets/liquid_glass/liquid_glass_appbar.dart';
import '../widgets/liquid_glass/liquid_glass_button.dart';
import '../widgets/liquid_glass/liquid_glass_card.dart';
import '../widgets/reproductor_cancion.dart';

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
  // Partidas de sala: título propio ("Canción 3"), aviso arriba (reloj o
  // ronda), botón para saltar y compras hechas antes de salir y volver.
  final String? titulo;
  final Widget? cabecera;
  final VoidCallback? onSaltar;
  final Map<String, int> comprasPrevias;
  final bool melodiaDescubierta;

  const GameScreen({
    super.key,
    required this.nivel,
    required this.gameId,
    this.numeroVisible,
    this.onSiguiente,
    this.offlineMode = false,
    this.offlineLevel,
    this.onOfflineCompleted,
    this.titulo,
    this.cabecera,
    this.onSaltar,
    this.comprasPrevias = const {},
    this.melodiaDescubierta = false,
  });

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final _answerController = TextEditingController();
  late final AudioService _audioService;
  late final MusicaMenu _musicaMenu;
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
  // Canción revelada al acertar, para el reproductor final.
  String? _titulo;
  String? _artista;
  String? _portadaUrl;
  Timer? _reloj;
  final _confeti = ConfettiController(duration: const Duration(seconds: 2));
  late bool _playingOffline;
  int _playbackGeneration = 0;
  late final Partida? _offlinePartida;

  @override
  void initState() {
    super.initState();
    _audioService = ref.read(audioServiceProvider);
    // La música del menú se pausa mientras se juega y vuelve al salir.
    _musicaMenu = ref.read(musicaMenuProvider)..entrarNivel();
    _playingOffline = widget.offlineMode;
    _purchased.addAll(widget.comprasPrevias.keys);
    _prices.addAll(widget.comprasPrevias);
    _balance -= widget.comprasPrevias.values.fold(0, (a, b) => a + b);
    _melodyFound = widget.melodiaDescubierta;
    _offlinePartida = widget.offlineLevel != null
        ? Partida(
            instrumentos: widget.nivel.instrumentos,
            random: Random.secure(),
          )
        : null;
  }

  @override
  void dispose() {
    _musicaMenu.salirNivel();
    _reloj?.cancel();
    _confeti.dispose();
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

  /// Dos bloques: presupuesto restante (con barra de lo que queda) y
  /// instrumentos comprados de los 3 posibles (con un punto por compra).
  Widget _presupuesto() {
    final text = Theme.of(context).textTheme;
    final color = colorDificultad(widget.nivel.dificultad);
    final etiqueta = text.labelSmall?.copyWith(
      color: context.paleta.tonoTexto(color),
      fontWeight: FontWeight.w800,
      letterSpacing: 1,
    );
    const maxCompras = 3;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PRESUPUESTO', style: etiqueta),
              _monto(text),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: _balance / Nivel.presupuestoTotal,
                  minHeight: 6,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'de \$${formatearMiles(Nivel.presupuestoTotal)}',
                style: text.bodySmall?.copyWith(
                  color: context.paleta.tintaSuave,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('INSTRUMENTOS', style: etiqueta),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_purchased.length} de $maxCompras',
                  style: text.titleLarge,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 0; i < maxCompras; i++)
                    Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _purchased.length ? color : null,
                        border: Border.all(color: color, width: 2),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'de ${widget.nivel.instrumentos.length} disponibles',
                style: text.bodySmall?.copyWith(
                  color: context.paleta.tintaSuave,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Monto restante animado y, al comprar, el descuento que sube y se borra.
  Widget _monto(TextTheme text) {
    // Wrap: en pantallas angostas el descuento baja de línea.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 8,
      children: [
        TweenAnimationBuilder<int>(
          tween: IntTween(end: _balance),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('\$${formatearMiles(value)}', style: text.titleLarge),
          ),
        ),
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
          final offlinePath = widget.offlineLevel?.audioPaths[instrument.id];
          if (offlinePath != null && await File(offlinePath).exists()) {
            return (Uri.file(offlinePath).toString(), null);
          }
          if (_playingOffline) {
            throw StateError(
              'El audio ${instrument.nombre} no está descargado en este dispositivo',
            );
          }
          final audio = await repository.obtenerAudio(
            gameId: widget.gameId,
            tipo: 'stem',
            instrumento: instrument.id,
          );
          // Con la versión en la clave, un archivo reemplazado se vuelve a
          // bajar; si no cambió, se usa el ya guardado.
          return (
            audio.url,
            'level:${widget.nivel.id}:stem:${instrument.id}:${audio.version}',
          );
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
      _nowPlaying = type == 'instrumentalSong' ? 'Canción' : 'Canción original';
      _nowPlayingInstruments = const [];
    });
    try {
      String url;
      String? cacheKey;
      if (type == 'instrumentalSong') {
        final offlinePath = widget.offlineLevel?.instrumentalAudioPath;
        if (offlinePath != null && await File(offlinePath).exists()) {
          url = Uri.file(offlinePath).toString();
        } else if (_playingOffline) {
          throw StateError(
            'La pista instrumental no está descargada en este dispositivo',
          );
        } else {
          final audio = await ref
              .read(firebaseGameRepositoryProvider)
              .obtenerAudio(gameId: widget.gameId, tipo: type);
          url = audio.url;
          cacheKey =
              'song:${widget.nivel.cancionId}:instrumentalSong:${audio.version}';
        }
      } else {
        url =
            (await ref
                    .read(firebaseGameRepositoryProvider)
                    .obtenerAudio(gameId: widget.gameId, tipo: type))
                .url;
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
    return LiquidGlassCard(
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
      final resultado = await ref
          .read(firebaseGameRepositoryProvider)
          .enviarRespuesta(gameId: widget.gameId, respuesta: answer);
      if (!mounted) return;
      if (resultado.correcta) {
        _playbackGeneration++;
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
        // La portada se descarga antes de mostrar el reproductor para que
        // aparezca junto con la canción.
        await _cargarPortada();
        if (!mounted) return;
        setState(() {
          _ganar(
            titulo: resultado.titulo ?? answer,
            artista: resultado.artista,
          );
          _correct = true;
          _message = '¡Correcto! Reproduciendo la canción original.';
        });
        if (resultado.monedas > 0 || resultado.puntos > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                resultado.puntos > 0
                    ? '🏆 +${resultado.puntos} puntos'
                    : '🪙 +${resultado.monedas} monedas para Adivina la intro',
              ),
            ),
          );
        }
        // Sin await: la canción sigue sonando en el reproductor y la pantalla
        // queda libre (si no, "Comprobando respuesta" duraba toda la canción).
        unawaited(_playSong('fullSong', replaceCurrent: true));
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
      _ganar(titulo: answer);
      _correct = true;
      _message =
          '¡Correcto! La canción completa se reproducirá cuando tengas conexión a internet.';
    });
    await _audioService.detener();
  }

  // Llamar dentro de setState.
  void _ganar({required String titulo, String? artista}) {
    _won = true;
    _titulo = titulo;
    _artista = artista;
    _confeti.play();
    // Refresca la barra de progreso del reproductor mientras suena.
    _reloj ??= Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (mounted && _playing && !_paused) setState(() {});
    });
  }

  Future<void> _cargarPortada() async {
    try {
      final url =
          (await ref
                  .read(firebaseGameRepositoryProvider)
                  .obtenerAudio(gameId: widget.gameId, tipo: 'cover')
                  .timeout(const Duration(seconds: 4)))
              .url;
      if (!mounted) return;
      // Se baja a la caché de imágenes antes de mostrarla; si no existe o
      // tarda más de 4 s se sigue con el disco en su lugar.
      var cargada = true;
      await precacheImage(
        NetworkImage(url),
        context,
        onError: (_, _) => cargada = false,
      ).timeout(const Duration(seconds: 4), onTimeout: () => cargada = false);
      if (mounted && cargada) _portadaUrl = url;
    } catch (error) {
      // Sin portada subida se muestra el disco; no es un error para el jugador.
      debugPrint('No se pudo cargar la portada: $error');
    }
  }

  Future<void> _playPauseFinal() async {
    if (_playing) {
      await _togglePause();
    } else if (!_playingOffline) {
      await _playSong('fullSong');
    }
  }

  /// Pantalla al acertar: reproductor de la canción con su portada y, debajo,
  /// los botones para terminar o pasar al siguiente nivel.
  Widget _vistaGanada() => ReproductorCancion(
    color: colorDificultad(widget.nivel.dificultad),
    titulo: _titulo,
    artista: _artista,
    insignia:
        '¡ADIVINASTE! · ${(widget.titulo ?? 'Nivel ${widget.numeroVisible ?? widget.nivel.numero}').toUpperCase()}',
    portada: _portadaUrl == null ? null : NetworkImage(_portadaUrl!),
    reproduciendo: _playing,
    enPausa: _paused,
    posicion: _playing ? _audioService.posicion : Duration.zero,
    duracion: _playing
        ? (_audioService.duracion ?? Duration.zero)
        : Duration.zero,
    onReproducirPausar: _playingOffline ? null : _playPauseFinal,
    onDesdeInicio: _playingOffline
        ? null
        : () => _playing
              ? _audioService.buscar(Duration.zero)
              : _playSong('fullSong'),
    onDetener: _playing ? () => _audioService.detener() : null,
    onBuscar: _playing ? _audioService.buscar : null,
    confeti: _confeti,
    nota: _playingOffline
        ? 'La canción original se reproducirá cuando tengas conexión a internet.'
        : null,
    botones: _botonesFinales(),
  );

  Widget _botonesFinales() => Row(
    children: [
      Expanded(
        child: LiquidGlassButton(
          onPressed: _avanzando
              ? null
              : () => Navigator.of(context).pop(ResultadoNivel.terminar),
          label: 'Terminar nivel',
        ),
      ),
      if (widget.onSiguiente != null) ...[
        const SizedBox(width: 12),
        Expanded(
          child: LiquidGlassButton(
            variant: LiquidGlassButtonVariant.secondary,
            onPressed: _avanzando
                ? null
                : () {
                    setState(() => _avanzando = true);
                    widget.onSiguiente!();
                  },
            label: 'Siguiente nivel',
          ),
        ),
      ],
    ],
  );

  /// Alto de cada casilla de instrumento: lo que deja libre el resto del
  /// nivel, repartido en 2 filas, para que todo quepa sin desplazar.
  /// shortcut: el alto del resto es una estimación (texto ~360 px más los
  /// botones visibles); si el diseño cambia mucho, medirlo de verdad.
  double _altoCasilla(double altoDisponible) {
    final escala = MediaQuery.textScalerOf(context).scale(1);
    final extras =
        (_purchased.isNotEmpty || _melodyFound ? 60 : 0) +
        (_playing ? 72 : 0) +
        (_message != null ? 48 : 0);
    final libre = altoDisponible - 360 * escala - extras - 12;
    return (libre / 2).clamp(84.0, 150.0);
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
      child: LiquidGlassCard(
        tintColor: colorDificultad(widget.nivel.dificultad),
        borderColor: comprado ? scheme.primary : null,
        // Expandir hace que toda
        // la casilla responda al toque y el contenido quede centrado.
        child: SizedBox.expand(
          child: LiquidRippleEffect(
            onTap: disponible ? () => _buyAndPlay(instrumento) : null,
            child: Opacity(
              opacity: disponible ? 1 : 0.45,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                // Con letra grande del sistema se encoge en vez de desbordarse.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _emojiDe(instrumento.tipo),
                        style: const TextStyle(fontSize: 40),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          instrumento.nombre,
                          style: text.titleMedium,
                        ),
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
    // El fondo cubre también la barra para que el vidrio tenga qué mostrar.
    child: LiquidBackground(
      acento: colorDificultad(widget.nivel.dificultad),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: LiquidGlassAppBar(
          title: Text(
            widget.titulo ??
                'Nivel ${widget.numeroVisible ?? widget.nivel.numero}',
          ),
          actions: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _playing
                  ? Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: SoundWaveAnimation(
                        activo: !_paused,
                        color: colorDificultad(widget.nivel.dificultad),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        body: ConCarga(
          cargando: _sending || _avanzando,
          texto: _avanzando
              ? 'Cargando siguiente nivel...'
              : 'Comprobando respuesta...',
          child: _won
              ? _vistaGanada()
              : LayoutBuilder(
                  builder: (context, espacio) => ListView(
                    // En tablets el contenido queda centrado con un ancho máximo.
                    padding: EdgeInsets.symmetric(
                      horizontal: max(
                        16,
                        (MediaQuery.sizeOf(context).width - 680) / 2,
                      ),
                      vertical: 16,
                    ),
                    children: [
                      if (widget.cabecera case final cabecera?) ...[
                        cabecera,
                        const SizedBox(height: 12),
                      ],
                      Text(
                        widget.nivel.modoPrueba
                            ? 'Modo de prueba: ${widget.nivel.duracionFragmentoSegundos} segundos por escucha.'
                            : 'Compra un instrumento para escuchar un fragmento de la canción.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      LiquidGlassCard(
                        borderRadius: 18,
                        tintColor: colorDificultad(widget.nivel.dificultad),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: _presupuesto(),
                      ),
                      const SizedBox(height: 8),
                      GridView(
                        shrinkWrap: true,
                        // Sin el margen del sistema: la grilla va en medio de
                        // la pantalla, no contra el borde.
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        // 2 columnas en teléfonos, 3-4 en tablets. El alto sale
                        // del espacio libre para que el nivel quepa sin
                        // desplazar en teléfonos bajos.
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 240,
                          mainAxisExtent: _altoCasilla(espacio.maxHeight),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        children: [
                          for (final instrumento in widget.nivel.instrumentos)
                            _instrumentoTile(instrumento),
                        ],
                      ),
                      if (_purchased.isNotEmpty && !_melodyFound) ...[
                        const SizedBox(height: 8),
                        LiquidGlassButton(
                          variant: LiquidGlassButtonVariant.secondary,
                          onPressed: _buying || _playing
                              ? null
                              : _playPurchased,
                          icon: Icons.queue_music,
                          label: 'Escuchar instrumentos comprados',
                        ),
                      ],
                      if (_melodyFound) ...[
                        const SizedBox(height: 8),
                        LiquidGlassButton(
                          variant: LiquidGlassButtonVariant.secondary,
                          onPressed: _playing
                              ? null
                              : () => _playSong('instrumentalSong'),
                          icon: Icons.queue_music,
                          label: 'Escuchar canción',
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
                      const Divider(height: 24),
                      TextField(
                        controller: _answerController,
                        enabled: !_sending,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submitAnswer(),
                        decoration: const InputDecoration(
                          labelText: '¿Qué canción es?',
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
                      if (!_won)
                        LiquidGlassButton(
                          onPressed: _sending ? null : _submitAnswer,
                          label: 'Comprobar respuesta',
                        ),
                      if (!_won && widget.onSaltar != null) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _sending ? null : widget.onSaltar,
                          icon: const Icon(Icons.skip_next_rounded),
                          label: const Text('Saltar canción (0 puntos)'),
                        ),
                      ],
                    ],
                  ),
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
