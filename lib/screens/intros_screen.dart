import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../animations/liquid_ripple_effect.dart';
import '../animations/refresco.dart';
import '../animations/sound_wave_animation.dart';
import '../providers/providers.dart';
import '../models/artistas.dart';
import '../models/genero.dart';
import '../services/audio_service.dart';
import '../services/firebase_game_repository.dart';
import '../services/musica_menu.dart';
import '../theme.dart';
import '../widgets/liquid_glass/liquid_background.dart';
import '../widgets/liquid_glass/liquid_glass_appbar.dart';
import '../widgets/liquid_glass/liquid_glass_button.dart';
import '../widgets/liquid_glass/liquid_glass_card.dart';
import '../widgets/recorrido.dart';
import '../widgets/reproductor_cancion.dart';
import '../widgets/monedas_genero.dart';

// Color de las intros del género que se está jugando.
Color get _colorIntros => paletaGenero(generoActivo).intro;

/// "Adivina la intro": cada moneda saca una carta con una intro al azar que
/// el jugador aún no tiene; las obtenidas quedan en su colección.
class IntrosScreen extends ConsumerStatefulWidget {
  const IntrosScreen({super.key, this.embebida = false, this.onEstado});

  // Dentro de una pestaña del menú: sin barra ni fondo propios; el título y
  // las monedas van en la barra del menú (avisadas con [onEstado]).
  final bool embebida;
  final ValueChanged<EstadoIntros>? onEstado;

  @override
  ConsumerState<IntrosScreen> createState() => _IntrosScreenState();
}

class _IntrosScreenState extends ConsumerState<IntrosScreen> {
  EstadoIntros? _estado;
  // Portadas guardadas en la caché de las intros adivinadas.
  Map<String, File> _portadas = const {};
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
      titulo: 'Monedas de cada género',
      texto:
          'Cada género tiene su moneda. Ganas 2, 3 o 4 al completar por '
          'primera vez un nivel; las monedas de Medley solo se usan allí.',
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
          'Toca una carta, escucha la intro y escribe la canción. Si '
          'aciertas, suena la original.',
    ),
  ];

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final estado = await ref
          .read(firebaseGameRepositoryProvider)
          .cargarIntros();
      if (!mounted) return;
      setState(() => _estado = estado);
      widget.onEstado?.call(estado);
      unawaited(_cargarPortadas(estado));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  Future<void> _cargarPortadas(EstadoIntros estado) async {
    final audio = ref.read(audioServiceProvider);
    final portadas = <String, File>{};
    for (final intro in estado.intros) {
      if (intro.estado != EstadoIntro.completada) continue;
      final archivo = await audio.cachedFile('intro:${intro.id}:cover');
      if (archivo != null) portadas[intro.id] = archivo;
    }
    if (mounted) setState(() => _portadas = portadas);
  }

  Future<void> _abrir(IntroAsignada intro, {bool reproducir = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            IntroGameScreen(intro: intro, reproducirAlAbrir: reproducir),
      ),
    );
    if (!mounted) return;
    await _cargar();
  }

  Future<void> _sacarCarta() async {
    setState(() => _sacando = true);
    try {
      final estado = await ref
          .read(firebaseGameRepositoryProvider)
          .sacarIntro();
      if (!mounted) return;
      setState(() => _estado = estado);
      widget.onEstado?.call(estado);
      final nueva = estado.intros.firstWhere((item) => item.id == estado.nueva);
      final jugar = await showDialog<bool>(
        context: context,
        builder: (context) => _CartaRevelada(intro: nueva),
      );
      if (jugar == true && mounted) await _abrir(nueva, reproducir: true);
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LiquidGlassButton(
          key: _claveSacar,
          onPressed: _sacando || !estado.puedeSacar || estado.restantes == 0
              ? null
              : _sacarCarta,
          icon: Icons.style_rounded,
          label: estado.restantes == 0
              ? '¡Tienes todas las intros!'
              : 'Sacar carta · 1 moneda',
        ),
        const SizedBox(height: 8),
        Text(
          estado.restantes == 0
              ? 'Descubriste las ${estado.intros.length} intros.'
              : !estado.puedeSacar
              ? 'Gana monedas completando niveles del género correspondiente.'
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
    final acciones = [
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
          child: MonedasGenero(
            genero: generoActivo,
            saldo: estado.monedas,
            saldos: estado.monedasPorGenero,
          ),
        ),
    ];
    if (widget.embebida) return _cuerpo(estado);
    return LiquidBackground(
      acento: _colorIntros,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: LiquidGlassAppBar(
          title: const Text('Adivina la intro'),
          actions: acciones,
        ),
        body: _cuerpo(estado),
      ),
    );
  }

  /// Colección: las cartas por adivinar primero (en el orden en que
  /// salieron) y después las descubiertas en orden alfabético por título.
  Widget _grillaCartas(EstadoIntros estado) {
    final pendientes = [
      for (final intro in estado.intros)
        if (intro.estado != EstadoIntro.completada || intro.titulo == null)
          intro,
    ];
    final descubiertas = [
      for (final intro in estado.intros)
        if (intro.estado == EstadoIntro.completada && intro.titulo != null)
          intro,
    ]..sort((a, b) => _claveOrden(a.titulo!).compareTo(_claveOrden(b.titulo!)));
    final cartas = [...pendientes, ...descubiertas];
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 140,
          childAspectRatio: 0.62,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: cartas.length,
        itemBuilder: (context, index) {
          final intro = cartas[index];
          final portada = _portadas[intro.id];
          return _TarjetaIntro(
            intro: intro,
            portada: portada == null ? null : FileImage(portada),
            onTap: () => _abrir(intro),
          );
        },
      ),
    );
  }

  Widget _cuerpo(EstadoIntros? estado) => _error != null
      ? Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  esErrorDeRed(_error!)
                      ? 'Necesitas conexión a internet.'
                      : '$_error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                LiquidGlassButton(onPressed: _cargar, label: 'Reintentar'),
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
                            SizedBox(
                              height: 160,
                              child: BandaMusical(color: _colorIntros),
                            ),
                            Text(
                              'Tu colección está vacía.\nSaca tu primera carta.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      )
                    else
                      _grillaCartas(estado),
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
        );
}

/// Color suave y estable para cada artista: el mismo artista principal
/// ("Martín Elías" en "Martín Elías y Rolando Ochoa") siempre da el mismo
/// tono, así las cartas de un artista se reconocen de un vistazo.
Color colorArtista(String? artista) {
  // Mismo color para todas las formas de un artista del catálogo.
  final conocido = artista == null ? null : artistaConocido(artista);
  final principal = (conocido ?? artista ?? '')
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

/// Orden alfabético sin distinguir mayúsculas ni tildes (la ñ tras la n).
String _claveOrden(String texto) => texto
    .toLowerCase()
    .replaceAll(RegExp('[áàä]'), 'a')
    .replaceAll(RegExp('[éèë]'), 'e')
    .replaceAll(RegExp('[íìï]'), 'i')
    .replaceAll(RegExp('[óòö]'), 'o')
    .replaceAll(RegExp('[úùü]'), 'u')
    .replaceAll('ñ', 'n~');

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
  // 0–0,6: la ruleta de notas gira y frena; 0,6–1: la carta se da vuelta.
  late final _giro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  static const _finRuleta = 0.6;
  // Nota en la que se detiene la ruleta: cambia en cada carta.
  final _notaElegida = Random().nextInt(_Ruleta.cantidad);

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
                Icon(Icons.headphones_rounded, size: 64, color: _colorIntros),
                const SizedBox(height: 12),
                Text('¡Lista!', style: text.headlineSmall),
                const SizedBox(height: 4),
                Text('Descúbrela', style: text.bodyLarge),
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
            if (_giro.value < _finRuleta) {
              return _Ruleta(
                avance: _giro.value / _finRuleta,
                elegida: _notaElegida,
              );
            }
            final t = Curves.easeInOutBack.transform(
              (_giro.value - _finRuleta) / (1 - _finRuleta),
            );
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
        // Los botones aparecen cuando la carta ya se reveló.
        AnimatedBuilder(
          animation: _giro,
          builder: (context, hijo) => AnimatedOpacity(
            opacity: _giro.value >= _finRuleta ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: _giro.value < _finRuleta,
              child: hijo,
            ),
          ),
          child: LiquidGlassButton(
            onPressed: () => Navigator.of(context).pop(true),
            icon: Icons.play_arrow_rounded,
            label: '¡Jugar ahora!',
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Después'),
        ),
      ],
    ),
  );
}

/// Ruleta de notas musicales que gira rápido y frena con una nota bajo el
/// marcador de arriba; [avance] va de 0 a 1.
class _Ruleta extends StatelessWidget {
  const _Ruleta({required this.avance, required this.elegida});

  final double avance;
  // Índice de la nota que queda bajo el marcador al terminar.
  final int elegida;

  static int get cantidad => _notas.length;

  static const _notas = [
    Icons.music_note_rounded,
    Icons.headphones_rounded,
    Icons.audiotrack_rounded,
    Icons.album_rounded,
    Icons.queue_music_rounded,
    Icons.piano_rounded,
    Icons.mic_rounded,
    Icons.library_music_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    const tamano = 250.0;
    const radio = 92.0;
    final paso = 2 * pi / _notas.length;
    // Tres vueltas que frenan al final y dejan la nota [elegida] arriba
    // (su ángulo termina en un múltiplo de 2π).
    final destino = 3 * 2 * pi + (_notas.length - elegida) * paso;
    final giro = Curves.easeOutCubic.transform(avance) * destino;
    // La nota que queda arriba al terminar se destaca en el último tramo.
    final destaque = ((avance - 0.85) / 0.15).clamp(0.0, 1.0);
    return SizedBox.square(
      dimension: tamano,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: tamano,
            height: tamano,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _colorIntros.withValues(alpha: 0.15),
              border: Border.all(color: _colorIntros, width: 3),
            ),
          ),
          for (var i = 0; i < _notas.length; i++)
            Transform.translate(
              offset: Offset(
                radio * sin(giro + i * paso),
                -radio * cos(giro + i * paso),
              ),
              child: Transform.scale(
                scale: i == elegida ? 1 + 0.5 * destaque : 1,
                child: Icon(
                  _notas[i],
                  size: 34,
                  color: i == elegida
                      ? Color.lerp(AppColors.paperWhite, _colorIntros, destaque)
                      : AppColors.paperWhite,
                ),
              ),
            ),
          const DiscoGirando(size: 70),
          // Marcador fijo arriba: señala la nota elegida.
          Align(
            alignment: Alignment.topCenter,
            child: Icon(
              Icons.arrow_drop_down_rounded,
              size: 48,
              color: _colorIntros,
            ),
          ),
        ],
      ),
    );
  }
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
    this.sala,
    this.reproducirAlAbrir = false,
  });

  final IntroAsignada intro;
  // Recién sacada de la ruleta: la intro empieza a sonar al entrar.
  final bool reproducirAlAbrir;
  final IntroEnSala? sala;

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
  int _playbackGeneration = 0;

  @override
  void initState() {
    super.initState();
    _audioService = ref.read(audioServiceProvider);
    _musicaMenu = ref.read(musicaMenuProvider)..entrarNivel();
    if (_won) {
      unawaited(_cargarPortada().then((_) => mounted ? setState(() {}) : null));
    } else if (widget.reproducirAlAbrir) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _play('intro');
      });
    }
  }

  @override
  void dispose() {
    _musicaMenu.salirNivel();
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

  /// [tipo]: 'intro' o 'fullSong'.
  Future<void> _play(String tipo) async {
    final generation = ++_playbackGeneration;
    setState(() {
      _playing = true;
      _paused = false;
      _message = null;
    });
    try {
      // Si ya está guardada, no hace falta red. shortcut: el servidor no manda
      // versión de la intro; al volver a cortarlas en Storage, subir la "v".
      final clave = tipo == 'intro'
          ? 'intro:v3:${widget.intro.id}'
          : 'intro:${widget.intro.id}:full';
      // Las salas pueden ser de otro género: su audio no pasa por la caché,
      // que se guarda por el género del menú.
      final enCache = widget.sala == null;
      final guardado = enCache ? await _audioService.cachedFile(clave) : null;
      final url = guardado != null
          ? Uri.file(guardado.path).toString()
          : await _urlRemota(tipo);
      if (!mounted || generation != _playbackGeneration) return;
      await _audioService.reproducir(
        urls: [url],
        cacheKeys: [guardado == null && enCache ? clave : null],
        duracion: tipo == 'intro' ? const Duration(seconds: 30) : null,
        fundidoSalida: tipo == 'intro'
            ? const Duration(seconds: 2)
            : Duration.zero,
      );
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _message = textoDeFallo('No se pudo reproducir el audio', error),
        );
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
    final clave = 'intro:${widget.intro.id}:cover';
    final enCache = widget.sala == null;
    final guardada = enCache ? await _audioService.cachedFile(clave) : null;
    if (guardada != null) {
      _portada = FileImage(guardada);
      return;
    }
    try {
      final url = await _urlRemota('cover').timeout(const Duration(seconds: 4));
      if (!mounted) return;
      // Se guarda para verla también sin conexión.
      if (enCache && !kIsWeb) {
        final archivo = await _audioService
            .descargarYGuardar(url, clave)
            .timeout(const Duration(seconds: 4));
        if (mounted) _portada = FileImage(archivo);
        return;
      }
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
      final sala = widget.sala;
      final resultado = sala == null
          ? await _repo.enviarRespuestaIntro(
              introId: widget.intro.id,
              respuesta: answer,
            )
          : await _repo.responderIntroSala(
              codigo: sala.codigo,
              respuesta: answer,
            );
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
              : textoDeFallo('No se pudo validar la respuesta', error),
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

  Future<void> _ganar(String titulo, String? artista) async {
    _playbackGeneration++;
    await _audioService.detener();
    if (!mounted) return;
    // Canción y portada a la vez; así salen juntas.
    unawaited(_play('fullSong'));
    await _cargarPortada();
    if (!mounted) return;
    setState(() {
      _won = true;
      _correct = true;
      _titulo = titulo;
      _artista = artista;
    });
    _confeti.play();
  }

  Widget _vistaGanada() => ReproductorCancion(
    color: _colorIntros,
    titulo: _titulo,
    artista: _artista,
    insignia: '¡ADIVINASTE! · ${_titulo0.toUpperCase()}',
    portada: _portada,
    reproduciendo: _playing,
    enPausa: _paused,
    posicion: () => _playing ? _audioService.posicion : Duration.zero,
    duracion: () =>
        _playing ? (_audioService.duracion ?? Duration.zero) : Duration.zero,
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

  /// Barra de avance de la intro con el tiempo transcurrido y el total. Se
  /// refresca sola mientras suena, sin reconstruir la pantalla.
  Widget _lineaDeTiempo() =>
      Refresco(activo: _playing && !_paused, builder: (_) => _barraDeTiempo());

  Widget _barraDeTiempo() {
    final text = Theme.of(context).textTheme;
    final posicion = _playing ? _audioService.posicion : Duration.zero;
    final total = _playing ? const Duration(seconds: 30) : null;
    final avance = total == null || total.inMilliseconds == 0
        ? 0.0
        : (posicion.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    String tiempo(Duration d) =>
        '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    return Semantics(
      label: 'Avance de la intro',
      value: total == null
          ? 'Sin reproducir'
          : '${tiempo(posicion)} de ${tiempo(total)}',
      excludeSemantics: true,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: avance,
              minHeight: 6,
              color: _colorIntros,
              backgroundColor: _colorIntros.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(tiempo(posicion), style: text.bodySmall),
              const Spacer(),
              Text(
                total == null ? '-:--' : tiempo(total),
                style: text.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

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
            const SizedBox(height: 12),
            _lineaDeTiempo(),
            const SizedBox(height: 12),
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
