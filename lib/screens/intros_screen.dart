import 'package:riff/iconos_phosphor.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../animations/entrada.dart';
import '../animations/liquid_ripple_effect.dart';
import '../animations/refresco.dart';
import '../animations/sound_wave_animation.dart';
import '../providers/providers.dart';
import '../models/artistas.dart';
import '../models/genero.dart';
import '../models/logros.dart';
import '../widgets/aviso_insignia.dart';
import '../services/audio_service.dart';
import '../services/firebase_game_repository.dart';
import '../services/musica_menu.dart';
import '../theme.dart';
import '../widgets/genre_landscape/genre_landscape.dart';
import '../widgets/liquid_glass/liquid_background.dart';
import '../widgets/liquid_glass/liquid_glass_appbar.dart';
import '../widgets/liquid_glass/liquid_glass_button.dart';
import '../widgets/liquid_glass/liquid_glass_card.dart';
import '../widgets/recorrido.dart';
import '../widgets/reproductor_cancion.dart';
import '../widgets/monedas_genero.dart';
import '../widgets/notas_flotantes.dart';
import '../widgets/sin_conexion.dart';

// Color de las intros del género que se está jugando.
// Del color del género; solo Medley conserva el suyo.
Color get _colorIntros => generoActivo.esPopurri
    ? paletaGenero(generoActivo).intro
    : colorGenero(generoActivo);

/// "Adivina la intro": cada moneda saca una carta con una intro al azar que
/// el jugador aún no tiene; las obtenidas quedan en su colección.
class IntrosScreen extends ConsumerStatefulWidget {
  const IntrosScreen({super.key, this.embebida = false, this.onEstado});

  // Dentro de una pestaña del menú: sin barra ni fondo propios; el título y
  // las monedas van junto al botón de sacar carta (el menú las recibe con
  // [onEstado]).
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
  // Cada carta sacada reinicia el aviso "-1 moneda" sobre las monedas.
  int _restas = 0;
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
          'primera vez un nivel y 1 por cada intro adivinada; las de Medley solo '
          'se usan allí. Con la bombilla 💡 pides una pista al azar: 3 gratis por género y luego 1 moneda.',
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
    // Solo la primera carga espera, para poder leer la curiosidad.
    final minimo = _estado == null
        ? Future<void>.delayed(esperaMinimaCarga)
        : null;
    try {
      final estado = await ref
          .read(firebaseGameRepositoryProvider)
          .cargarIntros();
      await minimo;
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
        builder: (_) => IntroGameScreen(
          intro: intro,
          reproducirAlAbrir: reproducir,
          pistasGratis: _estado?.pistasGratis,
        ),
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
      if (mounted) setState(() => _restas++);
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
    return Entrada(
      indice: 3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, caja) {
              final boton = LiquidGlassButton(
                key: _claveSacar,
                onPressed:
                    _sacando || !estado.puedeSacar || estado.restantes == 0
                    ? null
                    : _sacarCarta,
                icon: Icons.style_rounded,
                label: estado.restantes == 0
                    ? '¡Tienes todas las intros!'
                    : 'Sacar carta',
                // La moneda en la píldora del botón, bien visible.
                precio: estado.restantes == 0
                    ? null
                    : '1 ${generoActivo.simboloMoneda}',
                precioBlanco: true,
                // Del color del género donde está.
                color: colorGenero(generoActivo),
              );
              // Las monedas del género, junto al botón que las gasta.
              final monedas = KeyedSubtree(
                key: _claveMonedas,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    MonedasGenero(
                      grande: true,
                      genero: generoActivo,
                      saldo: estado.monedas,
                      saldos: estado.monedasPorGenero,
                    ),
                    if (_restas > 0)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: _MenosUna(
                            key: ValueKey(_restas),
                            simbolo: generoActivo.simboloMoneda,
                          ),
                        ),
                      ),
                  ],
                ),
              );
              // Solo en pantallas muy angostas pasa encima del botón.
              if (caja.maxWidth < 300) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: monedas),
                    const SizedBox(height: 8),
                    boton,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: boton),
                  const SizedBox(width: 8),
                  monedas,
                ],
              );
            },
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
      ),
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
    ];
    if (widget.embebida) return _cuerpo(estado);
    return LiquidBackground(
      acento: _colorIntros,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: LiquidGlassAppBar(
          colorTitulo: _colorIntros,
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
          return Entrada(
            indice: index,
            child: _TarjetaIntro(
              intro: intro,
              portada: portada == null ? null : FileImage(portada),
              onTap: () => _abrir(intro),
            ),
          );
        },
      ),
    );
  }

  Widget _cuerpo(EstadoIntros? estado) => _error != null
      ? esErrorDeRed(_error!)
            ? SinConexion(onReintentar: _cargar)
            : Center(
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
              // El fondo no se desplaza: las cartas pasan por encima.
              child: ConFondo(
                fondo: FondoIntros.genero(generoActivo),
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
            ),
            // El botón para sacar cartas queda abajo, al alcance del
            // pulgar.
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(8, 8, 8, 16),
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
          completada
              ? PhosphorIconsFill.musicNotes
              : PhosphorIconsFill.headphones,
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
                PhosphorIconsFill.musicNotes,
                size: 72,
                color: AppColors.paperWhite,
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  PhosphorIconsFill.headphones,
                  size: 64,
                  color: _colorIntros,
                ),
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
            color: colorGenero(generoActivo),
            onPressed: () => Navigator.of(context).pop(true),
            icon: PhosphorIconsFill.play,
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
    PhosphorIconsFill.musicNotes,
    PhosphorIconsFill.headphones,
    PhosphorIconsFill.musicNote,
    Icons.album_rounded,
    PhosphorIconsFill.playlist,
    PhosphorIconsFill.pianoKeys,
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
    this.pistasGratis,
  });

  final IntroAsignada intro;
  // Pistas gratis que le quedan al jugador; null en salas, donde no hay pistas.
  final int? pistasGratis;
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
  late List<String>? _pista = widget.intro.pista;
  late int? _gratis = widget.pistasGratis;
  bool _pidiendoPista = false;

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

  /// Avisa del coste y, si acepta, revela la inicial de otra palabra al azar.
  Future<void> _pedirPista() async {
    final gratis = (_gratis ?? 0) > 0;
    final genero = generoActivo;
    final acepta = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Quieres usar una pista al azar?'),
        content: gratis
            ? null
            : Text(
                'Costará 1 moneda ${genero.simboloMoneda} de ${genero.nombre}.',
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorGenero(genero),
              foregroundColor: colorGenero(genero).computeLuminance() > 0.45
                  ? AppColors.graphiteInk
                  : AppColors.paperWhite,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Usar pista'),
          ),
        ],
      ),
    );
    if (acepta != true || !mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pidiendoPista = true;
      _message = null;
    });
    try {
      final estado = await _repo.pedirPistaIntro(widget.intro.id);
      final intro = estado.intros.firstWhere((i) => i.id == widget.intro.id);
      if (mounted) {
        setState(() {
          _pista = intro.pista;
          _gratis = estado.pistasGratis;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is GameRepositoryException
              ? error.message
              : textoDeFallo('No se pudo obtener la pista', error),
        );
      }
    } finally {
      if (mounted) setState(() => _pidiendoPista = false);
    }
  }

  void _fallo() {
    HapticFeedback.lightImpact();
    setState(() {
      _correct = false;
      _message = 'Esa no es la canción. Intenta de nuevo.';
    });
  }

  Future<void> _ganar(String titulo, String? artista) async {
    // Fuera de las salas, "Comprobando respuesta" queda a la vista un mínimo
    // para que carguen la canción y su portada.
    final minimo = widget.sala == null
        ? Future<void>.delayed(esperaMinimaCarga)
        : null;
    _playbackGeneration++;
    await _audioService.detener();
    if (!mounted) return;
    // Si el acierto da una insignia, su tarjeta sale antes de la canción.
    final insignias = widget.sala == null
        ? insigniasNuevas(_repo)
        : Future.value(const <Logro>[]);
    final portada = _cargarPortada();
    final nuevas = await insignias;
    if (!mounted) return;
    if (nuevas.isEmpty) unawaited(_play('fullSong'));
    await portada;
    await minimo;
    if (!mounted) return;
    setState(() {
      _won = true;
      _correct = true;
      _titulo = titulo;
      _artista = artista;
    });
    HapticFeedback.mediumImpact();
    _confeti.play();
    if (nuevas.isNotEmpty) {
      await mostrarInsignias(context, nuevas);
      if (mounted) unawaited(_play('fullSong'));
    }
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
  Widget _lineaDeTiempo(double alturaOnda) => Refresco(
    activo: _playing && !_paused,
    builder: (_) => _barraDeTiempo(alturaOnda),
  );

  Widget _barraDeTiempo(double alturaOnda) {
    // Tipografía pixel de la app, más grande que el texto chico.
    final numeros = Theme.of(
      context,
    ).textTheme.headlineSmall?.copyWith(fontSize: 22);
    final posicion = _playing ? _audioService.posicion : Duration.zero;
    final total = _playing ? const Duration(seconds: 30) : null;
    // La onda lo lee en cada cuadro, así que sigue la reproducción sin reconstruir.
    double avanceActual() => !_playing
        ? 0.0
        : (_audioService.posicion.inMilliseconds / 30000).clamp(0.0, 1.0);
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
          LayoutBuilder(
            builder: (context, caja) => SoundWaveAnimation(
              activo: _playing && !_paused,
              color: _colorIntros,
              width: caja.maxWidth,
              height: alturaOnda,
              barras: 32,
              progreso: () => avanceActual(),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(tiempo(posicion), style: numeros),
              const Spacer(),
              Text(total == null ? '-:--' : tiempo(total), style: numeros),
            ],
          ),
        ],
      ),
    );
  }

  /// Escucha arriba y, fijo abajo (zona del pulgar, siempre sobre el teclado),
  /// el campo de respuesta con su botón.
  Widget _vistaJuego() => Column(
    children: [
      Expanded(child: _zonaJuego()),
      _panelRespuesta(),
    ],
  );

  Widget _panelRespuesta() {
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, espacio) => Padding(
        padding: EdgeInsets.fromLTRB(
          espacio.maxWidth > 568 ? (espacio.maxWidth - 520) / 2 : 24,
          8,
          espacio.maxWidth > 568 ? (espacio.maxWidth - 520) / 2 : 24,
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
                // Las pistas van dentro del cuadro, donde se escribe la respuesta.
                hintText: _pista?.map((p) => p.isEmpty ? '_' : p).join('   '),
                hintStyle: text.titleMedium?.copyWith(letterSpacing: 2),
                floatingLabelBehavior: _pista == null
                    ? null
                    : FloatingLabelBehavior.always,
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
            // El botón aparece al escribir algo, igual que en Adivina la canción.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _answerController,
              builder: (context, valor, _) => AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: valor.text.trim().isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: LiquidGlassButton(
                          // Del color del género.
                          color: colorGenero(generoActivo),
                          onPressed: _sending ? null : _submitAnswer,
                          label: 'Comprobar respuesta',
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _zonaJuego() {
    return Stack(
      children: [
        Positioned.fill(
          child: NotasFlotantes(
            color: _colorIntros,
            activo: _playing && !_paused,
          ),
        ),
        _contenidoZonaJuego(),
      ],
    );
  }

  Widget _contenidoZonaJuego() {
    return LayoutBuilder(
      // Sin desplazamiento: según el alto libre (el teclado lo reduce)
      // se achican casete y onda. El FittedBox solo es
      // la red de seguridad.
      builder: (context, espacio) {
        final ancho = espacio.maxWidth > 568 ? 520.0 : espacio.maxWidth - 48;
        final alturaOnda = espacio.maxHeight < 520 ? 44.0 : 60.0;
        // Lo que no cambia: relleno, tarjeta, separaciones, botón y tiempo.
        final libre = espacio.maxHeight - 156 - alturaOnda;
        final caseteMax = min(264.0, ancho - 28) / 1.6;
        final alturaCasete = libre.clamp(72.0, caseteMax);
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: espacio.maxWidth > 568
                ? (espacio.maxWidth - 520) / 2
                : 24,
            vertical: 8,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            // Centrado en el espacio libre.
            alignment: Alignment.center,
            child: SizedBox(
              width: espacio.maxWidth > 568 ? 520 : espacio.maxWidth - 48,
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                      padding: const EdgeInsets.all(14),
                      child: CaseteGirando(
                        ancho: alturaCasete * 1.6,
                        girando: _playing && !_paused,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _lineaDeTiempo(alturaOnda),
                  const SizedBox(height: 18),
                  if (_playing)
                    Row(
                      children: [
                        Expanded(
                          child: LiquidGlassButton(
                            // Pausar naranja; Reanudar verde.
                            variant: _paused
                                ? LiquidGlassButtonVariant.secondary
                                : LiquidGlassButtonVariant.primary,
                            onPressed: _togglePause,
                            icon: _paused
                                ? PhosphorIconsFill.play
                                : PhosphorIconsFill.pause,
                            label: _paused ? 'Reanudar' : 'Pausar',
                          ),
                        ),
                        const SizedBox(width: 8),
                        LiquidGlassButton(
                          color: const Color(0xFFD64545),
                          onPressed: () => _audioService.detener(),
                          icon: PhosphorIconsFill.stop,
                          label: 'Stop',
                        ),
                      ],
                    )
                  else
                    LiquidGlassButton(
                      variant: LiquidGlassButtonVariant.secondary,
                      onPressed: () => _play('intro'),
                      icon: PhosphorIconsFill.headphones,
                      label: 'Escuchar intro',
                    ),

                  if (widget.sala?.onSaltar case final saltar?) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _sending ? null : saltar,
                      icon: const Icon(PhosphorIconsFill.skipForward),
                      label: const Text('Saltar intro (0 puntos)'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  // Tipografía y color del género (abre como pantalla aparte y no hereda el
  // tema de su menú).
  Widget build(BuildContext context) => Theme(
    data: temaGenero(context, generoActivo),
    child: Builder(builder: _pantalla),
  );

  Widget _pantalla(BuildContext context) => LiquidBackground(
    acento: _colorIntros,
    child: ConPaisaje(
      visible: !_won,
      genero: generoParaPaisaje(generoActivo, widget.intro.id),
      level: widget.intro.numero,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: LiquidGlassAppBar(
          title: Text(
            _titulo0,
            style: TextStyle(color: context.paleta.tonoTexto(_colorIntros)),
          ),
          actions: [
            if (!_won && _gratis != null && (_pista?.contains('') ?? true))
              IconButton(
                tooltip: (_gratis ?? 0) > 0
                    ? 'Pista al azar ($_gratis gratis)'
                    : 'Pista al azar (1 ${generoActivo.simboloMoneda})',
                onPressed: _sending || _pidiendoPista ? null : _pedirPista,
                icon: Badge(
                  isLabelVisible: (_gratis ?? 0) > 0,
                  label: Text('$_gratis'),
                  child: const Icon(Icons.lightbulb_outline),
                ),
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: ConCarga(
            cargando: _sending,
            texto: 'Comprobando respuesta...',
            child: _won ? _vistaGanada() : _vistaJuego(),
          ),
        ),
      ),
    ),
  );
}

/// "-1 🪙" que sube desde las monedas y se desvanece al gastar una.
class _MenosUna extends StatelessWidget {
  const _MenosUna({super.key, required this.simbolo});

  final String simbolo;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 1400),
    curve: Curves.easeOut,
    builder: (context, t, _) => Opacity(
      opacity: (1 - t * t).clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, -8 - 44 * t),
        child: Center(
          child: Text(
            '-1 $simbolo',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.error,
              shadows: const [Shadow(blurRadius: 6, color: Colors.black45)],
            ),
          ),
        ),
      ),
    ),
  );
}
