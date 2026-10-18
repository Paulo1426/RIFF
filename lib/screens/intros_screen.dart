import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../animations/liquid_ripple_effect.dart';
import '../animations/sound_wave_animation.dart';
import '../providers/providers.dart';
import '../services/audio_service.dart';
import '../services/firebase_game_repository.dart';
import '../services/musica_menu.dart';
import '../services/offline_intro_store.dart';
import '../theme.dart';
import '../widgets/liquid_glass/liquid_background.dart';
import '../widgets/liquid_glass/liquid_glass_appbar.dart';
import '../widgets/liquid_glass/liquid_glass_button.dart';
import '../widgets/liquid_glass/liquid_glass_card.dart';
import '../widgets/recorrido.dart';
import '../widgets/reproductor_cancion.dart';

const _colorIntros = AppColors.signalOrange;

/// "Adivina la intro": cada moneda saca una carta con una intro al azar que
/// el jugador aún no tiene; las obtenidas quedan en su colección.
class IntrosScreen extends ConsumerStatefulWidget {
  const IntrosScreen({super.key});

  @override
  ConsumerState<IntrosScreen> createState() => _IntrosScreenState();
}

class _IntrosScreenState extends ConsumerState<IntrosScreen> {
  EstadoIntros? _estado;
  // Copia descargada para jugar sin conexión.
  OfflineIntroSnapshot? _offline;
  bool _sinConexion = false;
  Object? _error;
  bool _sacando = false;
  final _claveMonedas = GlobalKey();
  final _claveColeccion = GlobalKey();
  final _claveSacar = GlobalKey();

  @override
  void initState() {
    super.initState();
    _cargar().then((_) {
      if (mounted && _estado != null) {
        const RecorridoInicial('intros').mostrarSiEsNuevo(context, _pasos);
      }
    });
  }

  List<PasoRecorrido> _pasos() => [
    PasoRecorrido(
      clave: _claveMonedas,
      titulo: '🪙 Tus monedas',
      texto:
          'Las ganas al completar por primera vez un nivel de Adivina por '
          'instrumentos: Fácil 2, Media 3 y Avanzada 4.',
    ),
    PasoRecorrido(
      clave: _claveSacar,
      titulo: '🃏 Sacar carta',
      texto: 'Gasta 1 moneda para sacar una intro al azar que aún no tengas.',
    ),
    PasoRecorrido(
      clave: _claveColeccion,
      titulo: '🎧 Tu colección',
      texto:
          'Toca una carta, escucha la intro y escribe el nombre de la '
          'canción. Si aciertas, suena la original. Tras 3 fallos seguidos '
          'hay que esperar 30 segundos.',
    ),
  ];

  OfflineIntroStore get _store => ref.read(offlineIntroStoreProvider);

  Future<void> _cargar() async {
    setState(() => _error = null);
    final uid = ref.read(firebaseGameRepositoryProvider).uid;
    _offline ??= uid == null ? null : await _store.load(uid);
    try {
      // Los aciertos sin conexión se envían antes, para que cuenten.
      if (uid != null && (_offline?.pendientes.isNotEmpty ?? false)) {
        _offline = await _store.actualizar(uid);
      }
      final estado = await ref
          .read(firebaseGameRepositoryProvider)
          .cargarIntros();
      if (!mounted) return;
      setState(() {
        _estado = estado;
        _sinConexion = false;
      });
      if (uid != null) unawaited(_descargar(uid));
    } catch (error) {
      if (!mounted) return;
      final offline = _offline;
      setState(() {
        if (offline == null) {
          _error = error;
        } else {
          _estado = offline.estado;
          _sinConexion = true;
        }
      });
    }
  }

  /// Baja en segundo plano intro, original y portada de cada carta obtenida.
  Future<void> _descargar(String uid) async {
    try {
      final snapshot = await _store.actualizar(uid);
      if (mounted) setState(() => _offline = snapshot);
    } catch (error) {
      debugPrint('No se pudieron descargar las intros offline: $error');
    }
  }

  Future<void> _abrir(IntroAsignada intro) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => IntroGameScreen(
          intro: intro,
          sinConexion: _sinConexion,
          offline: _offline?.intros[intro.id],
          onOfflineCompletada: (answer) async {
            final snapshot = _offline;
            if (snapshot == null) {
              throw StateError('No hay intros descargadas en este teléfono');
            }
            final actualizado = snapshot.completadaLocalmente(intro.id, answer);
            await _store.save(actualizado);
            _offline = actualizado;
          },
        ),
      ),
    );
    if (!mounted) return;
    if (_sinConexion) {
      setState(() => _estado = _offline?.estado ?? _estado);
    } else {
      await _cargar();
    }
  }

  Future<void> _sacarCarta() async {
    setState(() => _sacando = true);
    try {
      final estado = await ref
          .read(firebaseGameRepositoryProvider)
          .sacarIntro();
      if (!mounted) return;
      setState(() => _estado = estado);
      final nueva = estado.intros.firstWhere((item) => item.id == estado.nueva);
      final jugar = await showDialog<bool>(
        context: context,
        builder: (context) => _CartaRevelada(intro: nueva),
      );
      if (jugar == true && mounted) await _abrir(nueva);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _sacando = false);
    }
  }

  Widget _panelInferior(EstadoIntros estado) {
    final text = Theme.of(context).textTheme;
    final sinMonedas = estado.monedas < 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LiquidGlassButton(
          key: _claveSacar,
          onPressed:
              _sacando || _sinConexion || sinMonedas || estado.restantes == 0
              ? null
              : _sacarCarta,
          icon: Icons.style_rounded,
          label: estado.restantes == 0
              ? '¡Tienes todas las intros!'
              : 'Sacar carta · 🪙 1',
        ),
        const SizedBox(height: 8),
        Text(
          _sinConexion
              ? 'Sin conexión: juega las intros descargadas. Para sacar '
                    'cartas necesitas internet.'
              : estado.restantes == 0
              ? 'Descubriste las ${estado.intros.length} intros.'
              : sinMonedas
              ? 'Gana monedas adivinando canciones del juego principal: '
                    'Fácil 2, Media 3 y Avanzada 4.'
              : 'Quedan ${estado.restantes} intros por descubrir.',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: context.paleta.tintaSuave),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = _estado;
    return LiquidBackground(
      acento: _colorIntros,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: LiquidGlassAppBar(
          title: const Text('Adivina la intro'),
          actions: [
            IconButton(
              tooltip: 'Ver ayuda',
              icon: const Icon(Icons.help_outline_rounded),
              onPressed: estado == null
                  ? null
                  : () => mostrarRecorrido(context, _pasos()),
            ),
            if (estado != null)
              Padding(
                key: _claveMonedas,
                padding: const EdgeInsets.only(right: 12),
                child: Semantics(
                  label: '${estado.monedas} monedas',
                  excludeSemantics: true,
                  child: Chip(
                    avatar: const Text('🪙'),
                    label: Text('${estado.monedas}'),
                  ),
                ),
              ),
          ],
        ),
        body: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$_error', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      LiquidGlassButton(
                        onPressed: _cargar,
                        label: 'Reintentar',
                      ),
                    ],
                  ),
                ),
              )
            : estado == null
            ? const Cargando(texto: 'Cargando intros...')
            : Column(
                children: [
                  Expanded(
                    key: _claveColeccion,
                    child: RefreshIndicator(
                      onRefresh: _cargar,
                      child: CustomScrollView(
                        slivers: [
                          if (estado.intros.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    height: 160,
                                    child: BandaMusical(color: _colorIntros),
                                  ),
                                  Text(
                                    'Tu colección está vacía.\nSaca tu primera carta.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                ],
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              sliver: SliverGrid.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 140,
                                      childAspectRatio: 0.62,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                    ),
                                itemCount: estado.intros.length,
                                itemBuilder: (context, index) {
                                  final intro = estado.intros[index];
                                  final portada =
                                      _offline?.intros[intro.id]?.coverPath;
                                  return _TarjetaIntro(
                                    intro: intro,
                                    portada: portada == null
                                        ? null
                                        : FileImage(File(portada)),
                                    onTap: () => _abrir(intro),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // El botón para sacar cartas queda abajo, al alcance del
                  // pulgar.
                  SafeArea(
                    top: false,
                    minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: _panelInferior(estado),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Color suave y estable para cada artista: el mismo artista principal
/// ("Martín Elías" en "Martín Elías y Rolando Ochoa") siempre da el mismo
/// tono, así las cartas de un artista se reconocen de un vistazo.
Color colorArtista(String? artista) {
  final principal = (artista ?? '')
      .split(RegExp(r',| y | e | & ', caseSensitive: false))
      .first
      .trim()
      .toLowerCase();
  // Hash propio: String.hashCode no garantiza el mismo valor entre ejecuciones.
  var hash = 0;
  for (final unidad in principal.codeUnits) {
    hash = (hash * 31 + unidad) & 0x7fffffff;
  }
  return HSLColor.fromAHSL(1, (hash % 360).toDouble(), 0.55, 0.82).toColor();
}

class _TarjetaIntro extends StatelessWidget {
  const _TarjetaIntro({
    required this.intro,
    required this.portada,
    required this.onTap,
  });

  final IntroAsignada intro;
  // Portada descargada; null mientras no esté en el teléfono.
  final ImageProvider? portada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final completada = intro.estado == EstadoIntro.completada;
    // Sin adivinar es una carta misteriosa: portada, nombre o color de artista
    // delatarían la respuesta.
    final color = completada ? colorArtista(intro.artista) : _colorIntros;
    final disco = ColoredBox(
      color: Color.lerp(color, AppColors.paperWhite, 0.35)!,
      child: Center(
        child: Icon(
          completada ? Icons.music_note_rounded : Icons.headphones_rounded,
          size: 36,
          color: completada
              ? context.paleta.tonoTexto(color)
              : AppColors.paperWhite,
        ),
      ),
    );
    return Semantics(
      button: true,
      label: completada
          ? '${intro.titulo ?? 'Canción adivinada'}, ${intro.artista ?? ''}'
          : 'Intro sin adivinar, jugar',
      excludeSemantics: true,
      child: Material(
        color: completada ? color : null,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: completada
              ? null
              : BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _colorIntros,
                      Color.lerp(_colorIntros, Colors.black, 0.2)!,
                    ],
                  ),
                ),
          child: LiquidRippleEffect(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: completada && portada != null
                          ? Image(
                              image: portada!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => disco,
                            )
                          : disco,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: Text(
                      completada
                          ? intro.titulo ?? 'Canción adivinada'
                          : '¿Qué canción es?',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: text.labelLarge?.copyWith(
                        color: completada
                            ? context.paleta.tonoTexto(color)
                            : AppColors.paperWhite,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (completada && intro.artista != null)
                    Text(
                      intro.artista!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: text.labelSmall?.copyWith(
                        color: context.paleta
                            .tonoTexto(color)
                            .withValues(alpha: 0.8),
                      ),
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

/// La carta recién sacada: aparece de dorso y gira para mostrar la intro.
class _CartaRevelada extends StatefulWidget {
  const _CartaRevelada({required this.intro});

  final IntroAsignada intro;

  @override
  State<_CartaRevelada> createState() => _CartaReveladaState();
}

class _CartaReveladaState extends State<_CartaRevelada>
    with SingleTickerProviderStateMixin {
  late final _giro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _giro.value = 1;
    } else if (_giro.isDismissed) {
      _giro.forward();
    }
  }

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  Widget _cara({required bool dorso}) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: 180,
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dorso
              ? [_colorIntros, Color.lerp(_colorIntros, Colors.black, 0.25)!]
              : [context.paleta.superficie, context.paleta.fondo],
        ),
        border: Border.all(color: _colorIntros, width: 3),
        boxShadow: const [BoxShadow(blurRadius: 24, color: Color(0x33000000))],
      ),
      child: dorso
          ? const Center(
              child: Icon(
                Icons.music_note_rounded,
                size: 72,
                color: AppColors.paperWhite,
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.headphones_rounded,
                  size: 64,
                  color: _colorIntros,
                ),
                const SizedBox(height: 12),
                Text('Intro #${widget.intro.numero}', style: text.titleLarge),
                const SizedBox(height: 4),
                Text('¿La reconoces?', style: text.bodyMedium),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _giro,
          builder: (context, _) {
            final t = Curves.easeInOutBack.transform(_giro.value);
            // De dorso (π) a frente (0); la cara visible cambia a mitad.
            final angulo = pi * (1 - t);
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(angulo),
              child: angulo > pi / 2
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(pi),
                      child: _cara(dorso: true),
                    )
                  : _cara(dorso: false),
            );
          },
        ),
        const SizedBox(height: 24),
        LiquidGlassButton(
          onPressed: () => Navigator.of(context).pop(true),
          label: '¡Jugar ahora!',
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Después'),
        ),
      ],
    ),
  );
}

/// Una intro: se escucha el fragmento y se escribe el nombre de la canción.
/// Al acertar aparece el mismo reproductor del juego principal con la
/// canción original y su portada.
/// Lo que cambia al jugar una intro dentro de una sala: audio y respuestas
/// van por la sala, con su título, aviso (reloj o ronda) y botones propios.
class IntroEnSala {
  const IntroEnSala({
    required this.codigo,
    required this.titulo,
    this.cabecera,
    this.onSaltar,
    this.onSiguiente,
  });

  final String codigo;
  final String titulo;
  final Widget? cabecera;
  final VoidCallback? onSaltar;
  final VoidCallback? onSiguiente;
}

class IntroGameScreen extends ConsumerStatefulWidget {
  const IntroGameScreen({
    super.key,
    required this.intro,
    this.sinConexion = false,
    this.offline,
    this.onOfflineCompletada,
    this.sala,
  });

  final IntroAsignada intro;
  final IntroEnSala? sala;
  final bool sinConexion;
  // Datos descargados; permiten validar la respuesta sin internet.
  final OfflineIntroData? offline;
  final Future<void> Function(String answer)? onOfflineCompletada;

  @override
  ConsumerState<IntroGameScreen> createState() => _IntroGameScreenState();
}

class _IntroGameScreenState extends ConsumerState<IntroGameScreen> {
  final _answerController = TextEditingController();
  final _confeti = ConfettiController(duration: const Duration(seconds: 2));
  late final AudioService _audioService;
  late final MusicaMenu _musicaMenu;
  bool _playing = false;
  bool _paused = false;
  bool _sending = false;
  String? _message;
  bool? _correct;
  late bool _won = widget.intro.estado == EstadoIntro.completada;
  late String? _titulo = widget.intro.titulo;
  late String? _artista = widget.intro.artista;
  ImageProvider? _portada;
  Timer? _reloj;
  int _playbackGeneration = 0;

  @override
  void initState() {
    super.initState();
    _audioService = ref.read(audioServiceProvider);
    _musicaMenu = ref.read(musicaMenuProvider)..entrarNivel();
    if (_won) {
      _iniciarReloj();
      unawaited(_cargarPortada().then((_) => mounted ? setState(() {}) : null));
    }
  }

  @override
  void dispose() {
    _musicaMenu.salirNivel();
    _reloj?.cancel();
    _confeti.dispose();
    _playbackGeneration++;
    _answerController.dispose();
    unawaited(_audioService.detener().catchError((_) {}));
    super.dispose();
  }

  FirebaseGameRepository get _repo => ref.read(firebaseGameRepositoryProvider);

  String get _titulo0 => widget.sala?.titulo ?? 'Intro #${widget.intro.numero}';

  /// [tipo]: 'intro', 'fullSong' o 'cover'.
  Future<String> _urlRemota(String tipo) {
    final sala = widget.sala;
    return sala == null
        ? _repo.obtenerUrlIntro(introId: widget.intro.id, tipo: tipo)
        : _repo.audioIntroSala(
            codigo: sala.codigo,
            introId: widget.intro.id,
            tipo: tipo,
          );
  }

  // Refresca la barra de progreso del reproductor mientras suena.
  void _iniciarReloj() =>
      _reloj ??= Timer.periodic(const Duration(milliseconds: 300), (_) {
        if (mounted && _playing && !_paused) setState(() {});
      });

  /// [tipo]: 'intro' o 'fullSong'.
  Future<void> _play(String tipo) async {
    final generation = ++_playbackGeneration;
    setState(() {
      _playing = true;
      _paused = false;
      _message = null;
    });
    try {
      // Mismas claves que la descarga offline: si ya está, no hace falta red.
      final clave = tipo == 'intro'
          ? 'intro:${widget.intro.id}'
          : 'intro:${widget.intro.id}:full';
      final guardado = await _audioService.cachedFile(clave);
      final url = guardado != null
          ? Uri.file(guardado.path).toString()
          : await _urlRemota(tipo);
      if (!mounted || generation != _playbackGeneration) return;
      await _audioService.reproducir(
        urls: [url],
        cacheKeys: [guardado == null ? clave : null],
        duracion: null,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'No se pudo reproducir el audio: $error');
      }
    } finally {
      if (mounted && generation == _playbackGeneration) {
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

  Future<void> _cargarPortada() async {
    final guardada = await _audioService.cachedFile(
      'intro:${widget.intro.id}:cover',
    );
    if (guardada != null) {
      _portada = FileImage(guardada);
      return;
    }
    if (widget.sinConexion) return;
    try {
      final url = await _urlRemota('cover').timeout(const Duration(seconds: 4));
      if (!mounted) return;
      var cargada = true;
      await precacheImage(
        NetworkImage(url),
        context,
        onError: (_, _) => cargada = false,
      ).timeout(const Duration(seconds: 4), onTimeout: () => cargada = false);
      if (mounted && cargada) _portada = NetworkImage(url);
    } catch (error) {
      // Sin portada subida se muestra el disco; no es un error para el jugador.
      debugPrint('No se pudo cargar la portada de la intro: $error');
    }
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
      if (widget.sinConexion) {
        await _comprobarSinConexion(answer);
        return;
      }
      final ResultadoRespuesta resultado;
      try {
        final sala = widget.sala;
        resultado = sala == null
            ? await _repo.enviarRespuestaIntro(
                introId: widget.intro.id,
                respuesta: answer,
              )
            : await _repo.responderIntroSala(
                codigo: sala.codigo,
                respuesta: answer,
              );
      } catch (error) {
        // Se cayó la conexión: si la intro está descargada se valida aquí.
        if (widget.offline == null || error is GameRepositoryException) {
          rethrow;
        }
        await _comprobarSinConexion(answer);
        return;
      }
      if (!mounted) return;
      if (!resultado.correcta) {
        _fallo();
        return;
      }
      if (resultado.puntos > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🏆 +${resultado.puntos} puntos')),
        );
      }
      await _ganar(resultado.titulo ?? answer, resultado.artista);
    } catch (error) {
      if (mounted) {
        setState(
          () => _message =
              error is GameRepositoryException && error.statusCode == 429
              ? error.message
              : 'No se pudo validar la respuesta: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _fallo() => setState(() {
    _correct = false;
    _message = 'Esa no es la canción. Intenta de nuevo.';
  });

  /// El acierto queda guardado en el teléfono y se envía al reconectar.
  Future<void> _comprobarSinConexion(String answer) async {
    final offline = widget.offline;
    if (offline == null) {
      throw StateError(
        'Esta intro aún no está descargada; conéctate a internet para jugarla.',
      );
    }
    if (!offline.acierta(answer)) {
      _fallo();
      return;
    }
    await widget.onOfflineCompletada?.call(answer);
    await _ganar(offline.titulo ?? answer, offline.artista);
  }

  Future<void> _ganar(String titulo, String? artista) async {
    _playbackGeneration++;
    await _audioService.detener();
    await _cargarPortada();
    if (!mounted) return;
    setState(() {
      _won = true;
      _correct = true;
      _titulo = titulo;
      _artista = artista;
    });
    _confeti.play();
    _iniciarReloj();
    unawaited(_play('fullSong'));
  }

  Widget _vistaGanada() => ReproductorCancion(
    color: _colorIntros,
    titulo: _titulo,
    artista: _artista,
    insignia: '¡ADIVINASTE! · ${_titulo0.toUpperCase()}',
    portada: _portada,
    reproduciendo: _playing,
    enPausa: _paused,
    posicion: _playing ? _audioService.posicion : Duration.zero,
    duracion: _playing
        ? (_audioService.duracion ?? Duration.zero)
        : Duration.zero,
    onReproducirPausar: () => _playing ? _togglePause() : _play('fullSong'),
    onDesdeInicio: () =>
        _playing ? _audioService.buscar(Duration.zero) : _play('fullSong'),
    onDetener: _playing ? () => _audioService.detener() : null,
    onBuscar: _playing ? _audioService.buscar : null,
    confeti: _confeti,
    botones: Row(
      children: [
        Expanded(
          child: LiquidGlassButton(
            onPressed: () => Navigator.of(context).pop(),
            label: widget.sala == null
                ? 'Volver a las intros'
                : 'Volver a la sala',
          ),
        ),
        if (widget.sala?.onSiguiente case final siguiente?) ...[
          const SizedBox(width: 12),
          Expanded(
            child: LiquidGlassButton(
              variant: LiquidGlassButtonVariant.secondary,
              onPressed: siguiente,
              label: 'Siguiente intro',
            ),
          ),
        ],
      ],
    ),
  );

  Widget _vistaJuego() {
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, espacio) => SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: espacio.maxWidth > 568
              ? (espacio.maxWidth - 520) / 2
              : 24,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.sala?.cabecera case final cabecera?) ...[
              cabecera,
              const SizedBox(height: 12),
            ],
            Center(
              child: LiquidGlassCard(
                borderRadius: 26,
                tintColor: _colorIntros,
                padding: const EdgeInsets.all(24),
                child: DiscoGirando(
                  size: (espacio.maxHeight * 0.28).clamp(120.0, 220.0),
                  girando: _playing && !_paused,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Escucha la intro y escribe el nombre de la canción.',
              textAlign: TextAlign.center,
              style: text.bodyLarge,
            ),
            const SizedBox(height: 16),
            if (_playing)
              Row(
                children: [
                  Expanded(
                    child: LiquidGlassButton(
                      variant: LiquidGlassButtonVariant.secondary,
                      onPressed: _togglePause,
                      icon: _paused ? Icons.play_arrow : Icons.pause,
                      label: _paused ? 'Reanudar' : 'Pausar',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Detener',
                    onPressed: () => _audioService.detener(),
                    icon: const Icon(Icons.stop),
                  ),
                ],
              )
            else
              LiquidGlassButton(
                variant: LiquidGlassButtonVariant.secondary,
                onPressed: () => _play('intro'),
                icon: Icons.headphones_rounded,
                label: 'Escuchar intro',
              ),
            const Divider(height: 32),
            TextField(
              controller: _answerController,
              enabled: !_sending,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitAnswer(),
              decoration: const InputDecoration(labelText: '¿Qué canción es?'),
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
            LiquidGlassButton(
              onPressed: _sending ? null : _submitAnswer,
              label: 'Comprobar respuesta',
            ),
            if (widget.sala?.onSaltar case final saltar?) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _sending ? null : saltar,
                icon: const Icon(Icons.skip_next_rounded),
                label: const Text('Saltar intro (0 puntos)'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LiquidBackground(
    acento: _colorIntros,
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: LiquidGlassAppBar(
        title: Text(_titulo0),
        actions: [
          if (_playing)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SoundWaveAnimation(activo: !_paused, color: _colorIntros),
            ),
        ],
      ),
      body: SafeArea(top: false, child: _won ? _vistaGanada() : _vistaJuego()),
    ),
  );
}
