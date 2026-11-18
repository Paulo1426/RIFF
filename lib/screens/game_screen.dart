import 'package:riff/iconos_phosphor.dart';
import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/genero.dart';
import '../models/instrumento.dart';
import '../models/nivel.dart';
import '../models/pista.dart';
import '../providers/providers.dart';
import '../services/audio_service.dart';
import '../services/firebase_game_repository.dart';
import '../services/musica_menu.dart';
import '../widgets/aviso_insignia.dart';
import '../widgets/liquid_glass/liquid_background.dart';
import '../animations/liquid_ripple_effect.dart';
import '../animations/sound_wave_animation.dart';
import '../theme.dart';
import '../widgets/liquid_glass/liquid_glass_appbar.dart';
import '../widgets/liquid_glass/liquid_glass_button.dart';
import '../widgets/liquid_glass/liquid_glass_card.dart';
import '../widgets/liquid_glass/pistas_dialog.dart';
import '../widgets/reproductor_cancion.dart';

enum ResultadoNivel { terminar, siguiente }

class GameScreen extends ConsumerStatefulWidget {
  final Nivel nivel;
  final String gameId;
  final int? numeroVisible;
  // Abre el siguiente nivel en lugar de este; null si no hay siguiente.
  final VoidCallback? onSiguiente;
  // Partidas de sala: título propio ("Canción 3"), aviso arriba (reloj o
  // ronda), botón para saltar y compras hechas antes de salir y volver.
  final String? titulo;
  final Widget? cabecera;
  final VoidCallback? onSaltar;
  final Map<String, int> comprasPrevias;
  final bool melodiaDescubierta;
  // En las salas no hay pistas: se compite en igualdad.
  final bool pistas;

  const GameScreen({
    super.key,
    required this.nivel,
    required this.gameId,
    this.numeroVisible,
    this.onSiguiente,
    this.titulo,
    this.cabecera,
    this.onSaltar,
    this.comprasPrevias = const {},
    this.melodiaDescubierta = false,
    this.pistas = true,
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
  String? _message;
  bool? _correct;
  final Set<String> _purchased = {};
  bool _melodyFound = false;
  bool _won = false;
  // Lo ganado al acertar; se muestra en la barra de arriba.
  (String, int, String)? _premio;
  bool _avanzando = false;
  // Canción revelada al acertar, para el reproductor final.
  String? _titulo;
  String? _artista;
  String? _portadaUrl;
  final _confeti = ConfettiController(duration: const Duration(seconds: 2));
  // Al descubrir la melodía: confeti y el aviso que se desvanece (cada
  // descubrimiento cambia la clave y reinicia la animación).
  final _confetiMelodia = ConfettiController(
    duration: const Duration(milliseconds: 1500),
  );
  int _celebracion = 0;
  int _playbackGeneration = 0;
  int _monedasDisponibles = 0;
  Map<String, int> _monedasPorGenero = const {};
  final Map<TipoPista, String> _pistasDesbloqueadas = {};
  TipoPista? _cargandoPista;

  Genero get _generoMoneda => generoActivo;

  @override
  void initState() {
    super.initState();
    _audioService = ref.read(audioServiceProvider);
    // La música del menú se pausa mientras se juega y vuelve al salir.
    _musicaMenu = ref.read(musicaMenuProvider)..entrarNivel();
    _purchased.addAll(widget.comprasPrevias.keys);
    _melodyFound = widget.melodiaDescubierta;
    unawaited(_cargarMonedas());
  }

  @override
  void didUpdateWidget(covariant GameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gameId != widget.gameId ||
        oldWidget.nivel.id != widget.nivel.id) {
      _pistasDesbloqueadas.clear();
      _cargandoPista = null;
      unawaited(_cargarMonedas());
    }
  }

  @override
  void dispose() {
    _musicaMenu.salirNivel();
    _confeti.dispose();
    _confetiMelodia.dispose();
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
    if (_buying || _won) return;
    HapticFeedback.selectionClick();
    if (_melodyFound || _purchased.contains(instrumento.id)) {
      try {
        await _cambiarA([instrumento]);
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
    try {
      final repository = ref.read(firebaseGameRepositoryProvider);
      final result = await repository.comprarInstrumento(
        gameId: widget.gameId,
        instrumento: instrumento.id,
      );
      if (!mounted) return;
      final descubierta = result.melodiaDescubierta && !_melodyFound;
      setState(() {
        _purchased
          ..clear()
          ..addAll(result.instrumentosComprados);
        _melodyFound = result.melodiaDescubierta;
        _message = result.melodiaDescubierta
            ? '¡Encontraste la melodía! Se desbloquearon todos los instrumentos.'
            : null;
      });
      if (descubierta) _celebrarMelodia();
      try {
        await _cambiarA([instrumento]);
      } catch (error) {
        if (!mounted) return;
        setState(
          () => _message = 'No se pudo reproducir el instrumento: $error',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = textoDeFallo(
            'No se pudo comprar el instrumento',
            error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Future<void> _cargarMonedas() async {
    try {
      final estado = await ref
          .read(firebaseGameRepositoryProvider)
          .cargarIntros();
      if (mounted) {
        setState(() {
          _monedasPorGenero = estado.monedasPorGenero;
          _monedasDisponibles =
              _monedasPorGenero[_generoMoneda.id] ?? estado.monedas;
        });
      }
    } catch (e) {
      debugPrint('No se pudieron cargar las monedas del usuario: $e');
    }
  }

  /// Pide la pista al servidor, que la calcula y cobra las monedas. La app
  /// solo la muestra cuando llega: no tiene el título ni el artista.
  Future<void> _pedirPista(TipoPista tipo) async {
    // La sorpresa se puede pedir varias veces (cada vez sale otra).
    if (_cargandoPista != null ||
        (tipo != TipoPista.sorpresa &&
            _pistasDesbloqueadas.containsKey(tipo))) {
      return;
    }
    setState(() => _cargandoPista = tipo);
    try {
      final resultado = await ref
          .read(firebaseGameRepositoryProvider)
          .pedirPista(gameId: widget.gameId, tipo: tipo);
      if (!mounted) return;
      setState(() {
        _monedasPorGenero = resultado.monedasPorGenero;
        _monedasDisponibles =
            _monedasPorGenero[_generoMoneda.id] ?? resultado.monedasRestantes;
        // Se guarda con el tipo que salió (la sorpresa trae el suyo).
        _pistasDesbloqueadas[resultado.tipo] =
            resultado.tipo == TipoPista.cuartoInstrumento
            ? _nombreInstrumento(resultado.valor)
            : resultado.valor;
        if (resultado.tipo == TipoPista.cuartoInstrumento) {
          // El que falta tiene la melodía: se descubre como al comprarlo.
          _purchased
            ..clear()
            ..addAll(resultado.instrumentosComprados);
          _melodyFound = true;
          _message =
              '¡Encontraste la melodía! Se desbloquearon todos los instrumentos.';
        }
      });
      if (resultado.tipo == TipoPista.cuartoInstrumento) _celebrarMelodia();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is GameRepositoryException
                  ? error.message
                  : 'No se pudo obtener la pista: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargandoPista = null);
    }
  }

  String _nombreInstrumento(String id) =>
      widget.nivel.instrumentos
          .where((instrumento) => instrumento.id == id)
          .firstOrNull
          ?.nombre ??
      id;

  Future<void> _abrirDialogoPistas() async {
    unawaited(_cargarMonedas());
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => PistasDialog(
          saldoMonedas: _monedasDisponibles,
          simboloMoneda: _generoMoneda.simboloMoneda,
          pistasDesbloqueadas: _pistasDesbloqueadas,
          cargandoTipo: _cargandoPista,
          onComprarPista: (tipo) async {
            final pedido = _pedirPista(tipo);
            // Muestra la carga y, al llegar, la pista o el saldo nuevo.
            if (dialogCtx.mounted) setDialogState(() {});
            await pedido;
            if (dialogCtx.mounted) setDialogState(() {});
          },
        ),
      ),
    );
  }

  /// Instrumentos comprados de los 3 posibles (con un punto por compra).
  Widget _presupuesto() {
    final text = Theme.of(context).textTheme;
    final color = _colorGenero;
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
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            widget.nivel.modoPrueba
                ? 'Modo de prueba: ${widget.nivel.duracionFragmentoSegundos} segundos por escucha.'
                : 'Selecciona un instrumento para escuchar un fragmento y adivina la canción.',
            textAlign: TextAlign.end,
            style: text.titleSmall,
          ),
        ),
      ],
    );
  }

  /// Si algo suena, lo apaga con un desvanecido y recién entonces arranca lo
  /// nuevo.
  Future<void> _cambiarA(List<Instrumento> instruments) async {
    if (_playing) {
      // Invalida la reproducción actual para que su cierre no apague el
      // indicador de "sonando" mientras entra la siguiente.
      final generacion = ++_playbackGeneration;
      await _audioService.desvanecer();
      if (!mounted || generacion != _playbackGeneration) return;
    }
    await _playStems(instruments);
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
        final audio = await ref
            .read(firebaseGameRepositoryProvider)
            .obtenerAudio(gameId: widget.gameId, tipo: type);
        url = audio.url;
        cacheKey =
            'song:${widget.nivel.cancionId}:instrumentalSong:${audio.version}';
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
        setState(
          () => _message = textoDeFallo(
            type == 'instrumentalSong'
                ? 'No se pudo reproducir la pista instrumental'
                : 'No se pudo reproducir la canción',
            error,
          ),
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
                  // Las ondas indican que suena (quietas en pausa); así la
                  // barra de arriba queda libre para el botón de pistas.
                  Semantics(
                    label: _paused ? 'En pausa' : 'Reproduciendo',
                    child: LayoutBuilder(
                      builder: (context, caja) => SoundWaveAnimation(
                        activo: !_paused,
                        color: _colorGenero,
                        width: caja.maxWidth,
                        height: 34,
                        barras: 24,
                      ),
                    ),
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
            _BotonConNombre(
              nombre: _paused ? 'Reanudar' : 'Pausa',
              filled: true,
              onPressed: _togglePause,
              icon: _paused ? PhosphorIconsFill.play : PhosphorIconsFill.pause,
            ),
            const SizedBox(width: 4),
            _BotonConNombre(
              nombre: 'Stop',
              onPressed: () => _audioService.detener(),
              icon: PhosphorIconsFill.stop,
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
        if (!mounted) return;
        // Canción y portada se piden a la vez: el reproductor aparece con la
        // portada lista (máx. ~2 s) y la canción ya cargando, así salen
        // juntas sin sumar las dos esperas.
        // Si el acierto da una insignia, su tarjeta sale antes de la canción.
        final insignias = insigniasNuevas(
          ref.read(firebaseGameRepositoryProvider),
        );
        final portada = _cargarPortada();
        final nuevas = await insignias;
        if (!mounted) return;
        if (nuevas.isEmpty) {
          unawaited(_playSong('fullSong', replaceCurrent: true));
        }
        await portada;
        if (!mounted) return;
        setState(() {
          _ganar(
            titulo: resultado.titulo ?? answer,
            artista: resultado.artista,
          );
          _correct = true;
          _message = '¡Correcto! Reproduciendo la canción original.';
          _premio = resultado.puntos > 0
              ? ('🏆', resultado.puntos, 'puntos')
              : resultado.monedas > 0
              ? (
                  generoActivo.simboloMoneda,
                  resultado.monedas,
                  'monedas para Adivina la intro',
                )
              : null;
        });
        if (nuevas.isNotEmpty) {
          await mostrarInsignias(context, nuevas);
          if (mounted) unawaited(_playSong('fullSong', replaceCurrent: true));
        }
      } else {
        HapticFeedback.lightImpact();
        setState(() {
          _correct = false;
          _message = 'Esa no es la canción. Intenta de nuevo.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          if (error is GameRepositoryException && error.statusCode == 429) {
            _message = error.message;
          } else {
            _message = textoDeFallo('No se pudo validar la respuesta', error);
          }
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // Llamar dentro de setState.
  void _ganar({required String titulo, String? artista}) {
    _won = true;
    _titulo = titulo;
    _artista = artista;
    HapticFeedback.mediumImpact();
    _confeti.play();
  }

  Future<void> _cargarPortada() async {
    try {
      final url =
          (await ref
                  .read(firebaseGameRepositoryProvider)
                  .obtenerAudio(gameId: widget.gameId, tipo: 'cover')
                  .timeout(const Duration(seconds: 2)))
              .url;
      if (!mounted) return;
      // Se baja a la caché de imágenes antes de mostrarla; si no existe o
      // tarda más de 2 s se sigue con el disco en su lugar.
      var cargada = true;
      await precacheImage(
        NetworkImage(url),
        context,
        onError: (_, _) => cargada = false,
      ).timeout(const Duration(seconds: 2), onTimeout: () => cargada = false);
      if (mounted && cargada) _portadaUrl = url;
    } catch (error) {
      // Sin portada subida se muestra el disco; no es un error para el jugador.
      debugPrint('No se pudo cargar la portada: $error');
    }
  }

  Future<void> _playPauseFinal() async {
    if (_playing) {
      await _togglePause();
    } else {
      await _playSong('fullSong');
    }
  }

  void _celebrarMelodia() {
    _confetiMelodia.play();
    setState(() => _celebracion++);
  }

  /// Confeti desde arriba y "¡Encontraste la melodía!" que aparece, crece un
  /// poco y se desvanece, encima de la vista de juego sin bloquear toques.
  Widget _conCelebracion(Widget vista) => Stack(
    children: [
      vista,
      Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          confettiController: _confetiMelodia,
          blastDirectionality: BlastDirectionality.explosive,
          numberOfParticles: 30,
          maxBlastForce: 20,
          minBlastForce: 8,
          gravity: 0.3,
          colors: [
            _colorGenero,
            AppColors.signalOrange,
            AppColors.medio,
            AppColors.verde,
            AppColors.paperWhite,
          ],
        ),
      ),
      if (_celebracion > 0)
        Center(
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(_celebracion),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 2600),
              builder: (context, t, hijo) => Opacity(
                // Aparece rápido, se queda y se desvanece.
                opacity: t < 0.15
                    ? t / 0.15
                    : t > 0.65
                    ? (1 - t) / 0.35
                    : 1,
                child: Transform.scale(scale: 0.9 + 0.15 * t, child: hijo),
              ),
              child: Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    '¡Encontraste la melodía! 🎶',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.paperWhite,
                      shadows: [
                        Shadow(blurRadius: 16, color: _colorGenero),
                        const Shadow(blurRadius: 4, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  /// Pantalla al acertar: reproductor de la canción con su portada y, debajo,
  /// los botones para terminar o pasar al siguiente nivel.
  Widget _vistaGanada() => ReproductorCancion(
    color: _colorGenero,
    titulo: _titulo,
    artista: _artista,
    insignia:
        '¡ADIVINASTE! · ${(widget.titulo ?? 'Nivel ${widget.numeroVisible ?? widget.nivel.numero}').toUpperCase()}',
    portada: _portadaUrl == null ? null : NetworkImage(_portadaUrl!),
    reproduciendo: _playing,
    enPausa: _paused,
    posicion: () => _playing ? _audioService.posicion : Duration.zero,
    duracion: () =>
        _playing ? (_audioService.duracion ?? Duration.zero) : Duration.zero,
    onReproducirPausar: _playPauseFinal,
    onDesdeInicio: () =>
        _playing ? _audioService.buscar(Duration.zero) : _playSong('fullSong'),
    onDetener: _playing ? () => _audioService.detener() : null,
    onBuscar: _playing ? _audioService.buscar : null,
    confeti: _confeti,
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
                : () async {
                    setState(() => _avanzando = true);
                    // Se libera el audio antes de la transición: soltar el
                    // reproductor de la canción completa durante el cambio de
                    // pantalla bloqueaba la app (ANR).
                    try {
                      await _audioService.detener();
                    } catch (error) {
                      debugPrint('No se pudo detener el audio: $error');
                    }
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
  /// shortcut: el alto del resto es una estimación (texto ~280 px más los
  /// botones visibles); si el diseño cambia mucho, medirlo de verdad.
  double _altoCasilla(double altoDisponible) {
    final escala = MediaQuery.textScalerOf(context).scale(1);
    final extras =
        (_purchased.isNotEmpty || _melodyFound ? 60 : 0) +
        (_playing ? 72 : 0) +
        (_message != null ? 48 : 0) +
        _pistasDesbloqueadas.length * 46;
    final libre = altoDisponible - 280 * escala - extras - 12;
    // Mínimo bajo: la casilla encoge su contenido (FittedBox) en pantallas chicas.
    return (libre / 2).clamp(56.0, 150.0);
  }

  Widget _instrumentoTile(Instrumento instrumento) {
    final comprado = _purchased.contains(instrumento.id);
    final limite = !_melodyFound && !comprado && _purchased.length >= 3;
    final disponible = !(_buying || _won || limite);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Tooltip(
      message: limite
          ? 'Ya compraste el máximo de 3 instrumentos'
          : comprado || _melodyFound
          ? 'Escuchar ${instrumento.nombre}'
          : 'Comprar y escuchar ${instrumento.nombre}',
      child: LiquidGlassCard(
        tintColor: _colorGenero,
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
                      Icon(
                        comprado
                            ? PhosphorIconsFill.checkCircle
                            : _melodyFound
                            ? PhosphorIconsFill.play
                            : Icons.shopping_cart,
                        color: comprado ? scheme.primary : null,
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

  /// Respuesta fija abajo (zona del pulgar, sobre el teclado): campo,
  /// mensaje y botón siempre a la vista mientras se escucha y se compra arriba.
  Widget _panelRespuesta() => Padding(
    padding: EdgeInsets.fromLTRB(
      max(16, (MediaQuery.sizeOf(context).width - 680) / 2),
      8,
      max(16, (MediaQuery.sizeOf(context).width - 680) / 2),
      12,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _answerController,
          enabled: !_sending,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitAnswer(),
          decoration: InputDecoration(
            labelText: '¿Qué canción es?',
            hintText: _pistasDesbloqueadas[TipoPista.iniciales],
          ),
        ),
        // El aviso entra con fundido y deslizamiento, como AnimatedContent en Compose.
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animacion) => FadeTransition(
              opacity: animacion,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, -0.4),
                  end: Offset.zero,
                ).animate(animacion),
                child: child,
              ),
            ),
            child: _message == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    key: ValueKey(_message),
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _correct == false
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                    ),
                  ),
          ),
        ),
        // El botón aparece al escribir algo.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _answerController,
          builder: (context, valor, _) => AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: !_won && valor.text.trim().isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: LiquidGlassButton(
                      // Del color del género, como el resto del nivel.
                      color: _colorGenero,
                      onPressed: _sending ? null : _submitAnswer,
                      label: 'Comprobar respuesta',
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
        if (!_won && widget.onSaltar != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _sending ? null : widget.onSaltar,
            icon: const Icon(PhosphorIconsFill.skipForward),
            label: const Text('Saltar canción (0 puntos)'),
          ),
        ],
      ],
    ),
  );

  // Los colores de la partida siguen a la tarjeta del género, no a la dificultad.
  Color get _colorGenero => colorGenero(generoActivo);

  @override
  // Tipografía del género (abre como pantalla aparte y no hereda el tema de su menú).
  Widget build(BuildContext context) => Theme(
    data: temaGenero(context, generoActivo),
    child: PopScope<ResultadoNivel>(
      // Al ganar, volver atrás también avisa para recargar el progreso.
      canPop: !_won,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_avanzando) {
          Navigator.of(context).pop(ResultadoNivel.terminar);
        }
      },
      // El fondo cubre también la barra para que el vidrio tenga qué mostrar.
      child: LiquidBackground(
        acento: _colorGenero,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: LiquidGlassAppBar(
            colorTitulo: _colorGenero,
            title: Text(
              widget.titulo ??
                  'Nivel ${widget.numeroVisible ?? widget.nivel.numero}',
            ),
            actions: [
              if (!_won && widget.pistas)
                IconButton(
                  tooltip:
                      'Pistas y comodines (${_generoMoneda.simboloMoneda} $_monedasDisponibles)',
                  icon: Badge(
                    label: Text('$_monedasDisponibles'),
                    isLabelVisible: _monedasDisponibles > 0,
                    backgroundColor: AppColors.signalOrange,
                    child: const Icon(PhosphorIconsFill.lightbulb),
                  ),
                  onPressed: _abrirDialogoPistas,
                ),
              if (_premio case (final emoji, final cantidad, final nombre))
                _Premio(emoji: emoji, cantidad: cantidad, nombre: nombre),
              const SizedBox(width: 8),
            ],
          ),
          // Sin SafeArea el campo de respuesta queda bajo los botones de
          // navegación del sistema en teléfonos con barra de 3 botones.
          body: SafeArea(
            top: false,
            child: ConCarga(
              cargando: _sending || _avanzando,
              texto: _avanzando
                  ? 'Cargando siguiente nivel...'
                  : 'Comprobando respuesta...',
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: KeyedSubtree(
                  key: ValueKey(_won),
                  child: _won
                      ? _vistaGanada()
                      : _conCelebracion(
                          Column(
                            children: [
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, espacio) => ListView(
                                    // En tablets el contenido queda centrado con un ancho máximo.
                                    padding: EdgeInsets.symmetric(
                                      horizontal: max(
                                        16,
                                        (MediaQuery.sizeOf(context).width -
                                                680) /
                                            2,
                                      ),
                                      vertical: 16,
                                    ),
                                    children: [
                                      if (widget.cabecera
                                          case final cabecera?) ...[
                                        cabecera,
                                        const SizedBox(height: 12),
                                      ],
                                      LiquidGlassCard(
                                        borderRadius: 18,
                                        tintColor: _colorGenero,
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
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        // 2 columnas en teléfonos, 3-4 en tablets. El alto sale
                                        // del espacio libre para que el nivel quepa sin
                                        // desplazar en teléfonos bajos.
                                        gridDelegate:
                                            SliverGridDelegateWithMaxCrossAxisExtent(
                                              maxCrossAxisExtent: 240,
                                              mainAxisExtent: _altoCasilla(
                                                espacio.maxHeight,
                                              ),
                                              crossAxisSpacing: 12,
                                              mainAxisSpacing: 12,
                                            ),
                                        children: [
                                          for (final instrumento
                                              in widget.nivel.instrumentos)
                                            _instrumentoTile(instrumento),
                                        ],
                                      ),
                                      if (_purchased.isNotEmpty &&
                                          !_melodyFound) ...[
                                        const SizedBox(height: 8),
                                        LiquidGlassButton(
                                          variant: LiquidGlassButtonVariant
                                              .secondary,
                                          onPressed: _buying || _playing
                                              ? null
                                              : _playPurchased,
                                          icon: PhosphorIconsFill.playlist,
                                          label:
                                              'Escuchar instrumentos comprados',
                                        ),
                                      ],
                                      // Al descubrir la melodía (comprando o con la pista
                                      // del instrumento faltante) se escucha sin voz.
                                      if (_melodyFound) ...[
                                        const SizedBox(height: 8),
                                        LiquidGlassButton(
                                          variant: LiquidGlassButtonVariant
                                              .secondary,
                                          onPressed: _playing
                                              ? null
                                              : () => _playSong(
                                                  'instrumentalSong',
                                                ),
                                          icon: PhosphorIconsFill.playlist,
                                          label: 'Escuchar canción sin voz',
                                        ),
                                      ],
                                      AnimatedSize(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        curve: Curves.easeOut,
                                        child: _playing
                                            ? Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8,
                                                ),
                                                child: _reproductor(),
                                              )
                                            : const SizedBox(
                                                width: double.infinity,
                                              ),
                                      ),
                                      const Divider(height: 24),
                                      // Pistas compradas, en el orden del diálogo.
                                      for (final tipo in TipoPista.values)
                                        if (_pistasDesbloqueadas[tipo]
                                            case final valor?)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.signalOrange
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: AppColors.signalOrange
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  tipo.icono,
                                                  size: 16,
                                                  color: AppColors.signalOrange,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    '${tipo.etiqueta}: $valor',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                      letterSpacing:
                                                          tipo ==
                                                              TipoPista
                                                                  .iniciales
                                                          ? 1.5
                                                          : null,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                    ],
                                  ),
                                ),
                              ),
                              _panelRespuesta(),
                            ],
                          ),
                        ),
                ),
              ),
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

String _emojiDe(TipoInstrumento tipo) => tipo.emoji;

/// Lo ganado al acertar, en la barra de arriba: aparece con un rebote junto a
/// su nombre para que se entienda qué se ganó.
class _Premio extends StatelessWidget {
  const _Premio({
    required this.emoji,
    required this.cantidad,
    required this.nombre,
  });

  final String emoji;
  final int cantidad;
  final String nombre;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.elasticOut,
      builder: (context, t, hijo) => Transform.scale(scale: t, child: hijo),
      child: Semantics(
        liveRegion: true,
        label: 'Ganaste $cantidad $nombre',
        excludeSemantics: true,
        child: Tooltip(
          message: '+$cantidad $nombre',
          child: Chip(
            visualDensity: VisualDensity.compact,
            backgroundColor: AppColors.medio.withValues(alpha: 0.3),
            side: const BorderSide(color: AppColors.medio, width: 1.5),
            avatar: Text(emoji),
            label: Text(
              '+$cantidad',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Botón redondo con su nombre debajo del ícono.
class _BotonConNombre extends StatelessWidget {
  const _BotonConNombre({
    required this.nombre,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String nombre;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      filled
          ? IconButton.filled(
              tooltip: nombre,
              onPressed: onPressed,
              icon: Icon(icon),
            )
          : IconButton(tooltip: nombre, onPressed: onPressed, icon: Icon(icon)),
      Text(nombre, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}
