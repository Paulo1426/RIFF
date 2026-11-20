import 'package:riff/iconos_phosphor.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/genero.dart';
import '../models/logros.dart';
import '../models/nivel.dart';
import '../models/sala.dart';
import '../providers/providers.dart';
import '../services/validadores_acceso.dart';
import '../services/firebase_game_repository.dart';
import '../animations/ciclo_lento.dart';
import '../animations/entrada.dart';
import '../animations/transicion_musical.dart';
import '../animations/liquid_ripple_effect.dart';
import '../widgets/aviso_insignia.dart';
import '../widgets/con_reflejo.dart';
import '../widgets/dialogo_contrasena.dart';
import '../widgets/liquid_glass/liquid_background.dart';
import '../widgets/login_liquido.dart';
import '../services/insignias_vistas.dart';
import '../services/recordatorios.dart';
import '../theme.dart';
import '../theme/liquid_glass_theme.dart';
import '../widgets/liquid_glass/liquid_glass_appbar.dart';
import '../widgets/liquid_glass/liquid_glass_bottom_nav.dart';
import '../widgets/liquid_glass/liquid_glass_card.dart';
import '../widgets/liquid_glass/liquid_glass_dialog.dart';
import '../widgets/liquid_glass/liquid_level_card.dart';
import 'carrusel_dificultades.dart';
import 'game_screen.dart';
import 'informacion_dialog.dart';
import 'instrucciones_dialog.dart';
import '../widgets/puerta_terminos.dart';
import '../widgets/recorrido.dart';
import '../widgets/sin_conexion.dart';
import 'intros_screen.dart';
import 'salas_screen.dart';

part 'home_screen_ajustes.dart';
part 'home_screen_login.dart';
part 'home_screen_menu.dart';
part 'home_screen_progreso.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.authStateChanges});

  final Stream<User?>? authStateChanges;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Una cuenta registrada (correo o Google) entra directo al menú al abrir la
  // app; un invitado pasa por el login, porque su sesión se limpia al entrar.
  bool _entered = false;
  // El login estaba en pantalla: al entrar se muestra la bienvenida.
  bool _desdeLogin = false;
  // Género elegido en el selector; null muestra el selector.
  Genero? _genero;
  // Se volvió al menú principal: la transición va en sentido contrario.
  bool _volviendo = false;
  late final Stream<User?> _authStateChanges =
      widget.authStateChanges ?? FirebaseAuth.instance.authStateChanges();

  @override
  void initState() {
    super.initState();
    // La música del menú suena desde que se abre la app.
    ref.read(musicaMenuProvider).iniciar();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('No se pudo consultar la sesión: ${snapshot.error}'),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Cargando());
        }
        final user = snapshot.data;
        if (user == null || (!_entered && user.isAnonymous)) {
          _desdeLogin = true;
          // Al volver a entrar se elige género otra vez.
          _genero = null;
          return FirebaseAuthScreen(
            savedUser: user,
            onSignedIn: () => setState(() => _entered = true),
          );
        }
        // Los términos se aceptan una sola vez por cuenta, tras iniciar sesión.
        Widget conTerminos(Widget hijo) => PuertaTerminos(
          key: ValueKey(user.uid),
          uid: user.uid,
          onRechazar: () => _cerrarSesionDe(context, ref, user),
          child: hijo,
        );
        if (_desdeLogin) {
          return conTerminos(
            BienvenidaLogin(
              nombre: user.isAnonymous ? null : _nombreSesion(user),
              onFin: () {
                if (mounted) setState(() => _desdeLogin = false);
              },
            ),
          );
        }
        final genero = _genero;
        // Cada género tiene su música; el selector, Medley y las salas, la general.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => ref.read(musicaMenuProvider).usarGenero(genero),
        );
        // El mismo fundido cruzado que entre pestañas.
        return conTerminos(
          TransicionMusical(
            retroceso: _volviendo,
            child: KeyedSubtree(
              key: ValueKey(genero),
              child: genero == null
                  ? _SelectorGenero(
                      user: user,
                      onElegir: (genero) => setState(() {
                        generoActivo = genero;
                        _volviendo = false;
                        _genero = genero;
                      }),
                    )
                  : _AuthenticatedHome(
                      key: ValueKey(user.uid),
                      user: user,
                      genero: genero,
                      onCambiarGenero: () => setState(() {
                        _volviendo = true;
                        _genero = null;
                      }),
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// Primera pantalla tras el login: un carrusel giratorio, como los menús de
/// cada género, con los cinco géneros, "Aleatorio" y las salas (las salas
/// tienen su propio género, por eso están aquí y no en cada menú). Solo los
/// géneros disponibles abren su menú; el resto sale bloqueado.
class _SelectorGenero extends ConsumerStatefulWidget {
  const _SelectorGenero({required this.user, required this.onElegir});

  final User user;
  final ValueChanged<Genero> onElegir;

  @override
  ConsumerState<_SelectorGenero> createState() => _SelectorGeneroState();
}

class _SelectorGeneroState extends ConsumerState<_SelectorGenero> {
  // Tarjeta al frente: tiñe el fondo.
  // Arranca en la tarjeta del género que se estaba jugando.
  int _frente = Genero.values.indexOf(generoActivo);
  final _carrusel = GlobalKey<CarruselGiratorioState>();
  // Pestaña lateral tocada: la gota va hasta ella mientras gira el carrusel
  // y vuelve al centro con el nombre nuevo.
  int? _pestanaTocada;
  // Nivel e intros de cada género disponible (sin dato, sin línea).
  final _avance = <Genero, String>{};
  // Lo mismo sin formato, para el progreso general.
  final _datos = <Genero, ({EstadoJuegoRemoto estado, EstadoIntros? intros})>{};
  bool _cargandoAvances = false;
  // Las salas son de todos los géneros.
  SaldoSalas _saldo = const SaldoSalas();
  StreamSubscription<SaldoSalas>? _suscripcionSaldo;
  Timer? _temporizadorAviso;

  @override
  void initState() {
    super.initState();
    // Con cualquier cuenta o de invitado: si hay red, deja una canción por
    // género lista para jugar sin conexión. Sin red no hace nada.
    unawaited(
      ref
          .read(firebaseGameRepositoryProvider)
          .prepararOffline()
          .catchError(
            (Object error) => debugPrint('Modo sin conexión: $error'),
          ),
    );
    // Un rato después, cuando el logo y los géneros ya terminaron de entrar.
    _temporizadorAviso = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) _avisoAuriculares(context);
    });
    if (!widget.user.isAnonymous) {
      _suscripcionSaldo = ref
          .read(firebaseGameRepositoryProvider)
          .saldoSalas()
          .listen(
            (saldo) => setState(() => _saldo = saldo),
            onError: (Object error) =>
                debugPrint('No se pudo leer el saldo de salas: $error'),
          );
    }
  }

  @override
  void dispose() {
    _temporizadorAviso?.cancel();
    _suscripcionSaldo?.cancel();
    super.dispose();
  }

  Future<void> _cargarAvances() async {
    for (final genero in _generosDelProgreso) {
      if (!mounted) return;
      await _cargarAvance(genero);
    }
  }

  List<Genero> get _generosDelProgreso => Genero.values
      .where((genero) => genero.disponible && !genero.esPopurri)
      .toList();

  Future<void> _cargarAvance(Genero genero) async {
    final repo = ref.read(firebaseGameRepositoryProvider);
    try {
      final estado = await repo.cargarEstado(genero: genero);
      final intros = await repo
          .cargarIntros(genero: genero)
          .then<EstadoIntros?>((e) => e, onError: (_) => null);
      // Sin niveles cargados (género en preparación) no hay nivel que mostrar.
      final hayNiveles = estado.dificultades.any((d) => d.total > 0);
      final adivinadas = intros?.intros
          .where((i) => i.estado == EstadoIntro.completada)
          .length;
      final partes = [
        if (hayNiveles) _textoNivel(estado),
        if (adivinadas != null) '🎧 $adivinadas intros descubiertas',
      ];
      if (mounted) {
        setState(() {
          if (!genero.esPopurri) {
            _datos[genero] = (estado: estado, intros: intros);
          }
        });
      }
      if (mounted && partes.isNotEmpty) {
        setState(() => _avance[genero] = partes.join('\n'));
      }
    } catch (error) {
      // Sin conexión o sin progreso aún: la tarjeta sale sin la línea.
      debugPrint('Sin avance de ${genero.nombre}: $error');
    }
  }

  Future<void> _abrirProgresoTodo() async {
    if (_cargandoAvances) return;
    final tieneTodo =
        _datos.length == _generosDelProgreso.length &&
        _datos.values.every((dato) => dato.intros != null);
    if (!tieneTodo) {
      setState(() => _cargandoAvances = true);
      try {
        await _cargarAvances();
      } finally {
        if (mounted) setState(() => _cargandoAvances = false);
      }
    }
    if (!mounted) return;
    _abrir(
      'Progreso general',
      _ProgresoTodo(
        datos: Map.of(_datos),
        saldo: _saldo,
        esInvitado: widget.user.isAnonymous,
      ),
      acento: AppColors.oro,
    );
  }

  // Después de los géneros (Medley incluido) van las salas y el progreso
  // general.
  int get _total => Genero.values.length + 2;
  static final _iProgreso = Genero.values.length + 1;

  ({IconData icon, String label}) _pestanaDe(int index) =>
      index < Genero.values.length
      ? (
          icon: switch (Genero.values[index]) {
            Genero.vallenato => PhosphorIconsFill.musicNotes,
            Genero.reggaeton => PhosphorIconsFill.headphones,
            Genero.rockPop => Icons.electric_bolt_rounded,
            Genero.salsa => Icons.nightlife_rounded,
            Genero.popular => Icons.mic_external_on_rounded,
            Genero.aleatorio => PhosphorIconsFill.shuffle,
          },
          label: Genero.values[index].nombre,
        )
      : index == _iProgreso
      ? (icon: Icons.insights_rounded, label: 'Progreso')
      : (icon: PhosphorIconsFill.trophy, label: 'Salas');

  Color _color(int index) => index < Genero.values.length
      ? colorGenero(Genero.values[index])
      : index == _iProgreso
      ? AppColors.oro
      : azulLogin;

  void _abrir(
    String titulo,
    Widget cuerpo, {
    Color? acento,
    List<Widget>? acciones,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LiquidBackground(
        acento: acento,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: LiquidGlassAppBar(
            title: Text(titulo),
            colorTitulo: acento,
            actions: acciones,
          ),
          body: cuerpo,
        ),
      ),
    ),
  );

  void _abrirAjustes() => _abrir(
    'Ajustes',
    Consumer(
      builder: (context, ref, _) => _PestanaConfiguracion(
        onCerrarSesion: () => _cerrarSesionDe(context, ref, widget.user),
        onReiniciar: widget.user.isAnonymous
            ? null
            : () => _reiniciarCuenta(context, ref),
      ),
    ),
  );

  Widget _cuadro(int index, bool alFrente, {bool animar = true}) {
    // Solo la del frente se mueve; las laterales, quietas.
    final moverse = animar && alFrente;
    if (index < Genero.values.length) {
      final genero = Genero.values[index];
      return _CuadroModo(
        emoji: genero.instrumentos,
        animacion: _Animacion.tocar,
        titulo: genero.nombre,
        detalle: genero.disponible ? 'Toca para jugar' : 'Próximamente',
        info: _avance[genero],
        color: colorGenero(genero),
        alFrente: alFrente,
        animar: moverse,
        bloqueado: !genero.disponible,
        onTap: genero.disponible ? () => widget.onElegir(genero) : null,
      );
    }
    if (index == _iProgreso) {
      final niveles = _datos.values.fold(
        0,
        (s, d) =>
            s + d.estado.dificultades.fold(0, (s, x) => s + x.completados),
      );
      final intros = _datos.values.fold(
        0,
        (s, d) =>
            s +
            (d.intros?.intros
                    .where((i) => i.estado == EstadoIntro.completada)
                    .length ??
                0),
      );
      return _CuadroModo(
        emoji: '📈',
        animacion: _Animacion.saltar,
        titulo: 'Progreso general',
        detalle: _cargandoAvances
            ? 'Cargando tu progreso...'
            : 'Toca para consultar todos tus géneros.',
        info: _datos.isEmpty ? null : '$niveles niveles · 🎧 $intros intros',
        color: AppColors.oro,
        alFrente: alFrente,
        animar: moverse,
        onTap: _cargandoAvances ? null : _abrirProgresoTodo,
      );
    }
    final invitado = widget.user.isAnonymous;
    return _CuadroModo(
      emoji: '🏆',
      animacion: _Animacion.saltar,
      titulo: 'Salas',
      detalle: invitado
          ? 'Crea una cuenta para jugar en salas.'
          : 'Desafía a tus amigos',
      grande: true,
      color: azulLogin,
      alFrente: alFrente,
      animar: moverse,
      bloqueado: invitado,
      onTap: invitado
          ? null
          : () => _abrir(
              'Salas',
              const SalasPanel(),
              acento: azulLogin,
              // Fichas para crear y entrar a salas, al día.
              acciones: [
                StreamBuilder<SaldoSalas>(
                  stream: ref.read(firebaseGameRepositoryProvider).saldoSalas(),
                  initialData: _saldo,
                  builder: (context, saldo) =>
                      _Saldo('🎟️', saldo.data?.fichas ?? 0, 'fichas'),
                ),
                const SizedBox(width: 8),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LiquidBackground(
      acento: _color(_frente),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: LiquidGlassAppBar(
          // El logo se queda a la izquierda y "Inicio" va al centro de la barra.
          leadingWidth: 72,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Image.asset(
              'lib/assets/images/logo/riff_logo.png',
              height: 56,
              cacheHeight: 192,
              semanticLabel: 'RIFF',
            ),
          ),
          colorTitulo: azulLogin,
          title: Text('Inicio', style: text.headlineMedium),
          actions: [
            IconButton(
              tooltip: 'Ajustes',
              icon: const Icon(Icons.settings_rounded),
              onPressed: _abrirAjustes,
            ),
            const SizedBox(width: 8),
          ],
        ),
        // Anterior, actual (centro) y siguiente del carrusel; tocar un lado
        // lo gira hacia allá.
        bottomNavigationBar: LiquidGlassBottomNav(
          items: [
            for (final paso in [-1, 0, 1])
              _pestanaDe((_frente + paso) % _total),
          ],
          colores: [
            for (final paso in [-1, 0, 1]) _color((_frente + paso) % _total),
          ],
          currentIndex: _pestanaTocada ?? 1,
          escalaInactivas: 0.8,
          onTap: (i) {
            if (i == 1) return;
            setState(() => _pestanaTocada = i);
            _carrusel.currentState?.girar(i - 1);
          },
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                '¿Qué quieres adivinar hoy?',
                textAlign: TextAlign.center,
                style: text.headlineSmall?.copyWith(
                  color: context.paleta.tonoTexto(_color(_frente)),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: CarruselGiratorio(
                  key: _carrusel,
                  inicial: _frente,
                  itemCount: _total,
                  autoGiro: const Duration(seconds: 5),
                  compacto: true,
                  // Un poco más grandes que en los menús: llevan el avance.
                  anchoRelativo: 0.84,
                  proporcion: 1.3,
                  colorDe: _color,
                  onCambio: (index) => setState(() {
                    _frente = index;
                    _pestanaTocada = null;
                  }),
                  itemBuilder: (context, index, alFrente) => ConReflejo(
                    color: _color(index),
                    tarjeta: _cuadro(index, alFrente),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _claveAvisoAuriculares = 'aviso_auriculares_visto';

/// Recomienda usar auriculares con un aviso discreto, solo la primera vez que
/// se abre la app en este teléfono.
Future<void> _avisoAuriculares(BuildContext context) async {
  // Los recordatorios se programan en cada apertura, haya o no aviso.
  unawaited(Recordatorios.programar());
  final mensajes = ScaffoldMessenger.of(context);
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_claveAvisoAuriculares) ?? false) return;
  await prefs.setBool(_claveAvisoAuriculares, true);
  mensajes.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 6),
      showCloseIcon: true,
      content: Row(
        children: [
          const Icon(PhosphorIconsFill.headphones, color: azulLogin),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Usa auriculares para distinguir bien cada instrumento.',
            ),
          ),
        ],
      ),
    ),
  );
}

// GoogleSignIn se inicializa una sola vez (login y confirmar la cuenta).
Future<void>? _googleListo;
Future<void> prepararGoogle() =>
    _googleListo ??= GoogleSignIn.instance.initialize(
      // Cliente web (client_type 3) de google-services.json: da el idToken
      // que Firebase valida, sin depender del recurso generado.
      serverClientId: kIsWeb ? null : _clienteWebGoogle,
    );

const _clienteWebGoogle =
    '655179331422-8turslccahe27035sehn4d1mjc6cg642.apps.googleusercontent.com';

class _AuthenticatedHome extends ConsumerStatefulWidget {
  const _AuthenticatedHome({
    super.key,
    required this.user,
    required this.genero,
    required this.onCambiarGenero,
  });

  final User user;
  // Tiñe el menú con el color e instrumentos del género.
  final Genero genero;
  // Vuelve al selector de géneros.
  final VoidCallback onCambiarGenero;

  @override
  ConsumerState<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends ConsumerState<_AuthenticatedHome> {
  EstadoJuegoRemoto? _estado;
  Object? _error;
  bool _loading = true;
  String? _startingLevelId;
  // Dificultad mostrada en el centro; null = la dificultad activa.
  Dificultad? _seleccionada;
  // Pestaña Canción: false muestra el carrusel de dificultades; true, la
  // tarjeta con todos los niveles de la seleccionada.
  bool _nivelesAbiertos = false;
  // Barra inferior: 0 menú, 1 Adivina la canción, 2 Adivina la intro,
  // 3 progreso, 4 configuración. Las salas están en el selector de géneros.
  int _pestana = 0;
  static const _pCancion = 1, _pIntro = 2, _pProgreso = 3;
  static const _pAjustes = 4;
  Future<EstadoIntros?>? _introsFuturo;
  // Para las tarjetas del menú: cuántas intros tiene y salas ganadas.
  EstadoIntros? _resumenIntros;
  SaldoSalas _saldo = const SaldoSalas();
  StreamSubscription<SaldoSalas>? _suscripcionSaldo;
  // Monedas de Adivina la intro para la barra (null hasta saberlas).
  int? _monedas;
  Map<String, int> _monedasPorGenero = const {};
  // El saldo de salas ya llegó (antes es todo cero y no sirve para insignias).
  bool _saldoCargado = false;
  // Revisando insignias o mostrando avisos al terminar un nivel.
  bool _avisando = false;
  bool _revisarOtraVez = false;
  // Elementos que resalta el recorrido guiado.
  final _claveMenu = GlobalKey();
  final _clavesPestanas = List.generate(5, (_) => GlobalKey());
  bool _recorridoRevisado = false;

  Future<void> _verRecorrido() => mostrarRecorrido(context, _pasosMenu());

  List<PasoRecorrido> _pasosMenu() => [
    PasoRecorrido(
      clave: _claveMenu,
      titulo: '🎮 Menú principal',
      texto:
          'Desliza las tarjetas para elegir modo. Con "Inicio", arriba a la '
          'derecha, vuelves a los géneros y a las salas.',
    ),
    PasoRecorrido(
      clave: _clavesPestanas[_pCancion],
      titulo: '${widget.genero.instrumentos.characters.first} Canción',
      texto: 'Las dificultades y niveles de Adivina la canción.',
    ),
    PasoRecorrido(
      clave: _clavesPestanas[_pIntro],
      titulo: '🎧 Intro',
      texto:
          'Tu colección, las monedas de este género y el botón para sacar cartas.',
    ),
    PasoRecorrido(
      clave: _clavesPestanas[_pProgreso],
      titulo: '📈 Progreso',
      texto:
          'Tus niveles, las monedas de este género, tus fichas 🎟️ y las canciones que '
          'ya adivinaste.',
    ),
    PasoRecorrido(
      clave: _clavesPestanas[_pAjustes],
      titulo: '⚙️ Ajustes',
      texto: 'Instrucciones, recorrido guiado, música del menú y modo oscuro.',
    ),
  ];

  /// La primera vez que se abre la app, al ver el menú, empieza el recorrido.
  Future<void> _recorridoSiEsNuevo() async {
    if (_recorridoRevisado) return;
    _recorridoRevisado = true;
    await const RecorridoInicial('menu').mostrarSiEsNuevo(context, _pasosMenu);
  }

  final _claveDificultades = GlobalKey();

  void _recorridoDificultades() {
    const RecorridoInicial('dificultades').mostrarSiEsNuevo(
      context,
      () => [
        PasoRecorrido(
          clave: _claveDificultades,
          titulo: '🎚️ Dificultades y niveles',
          texto:
              'Desliza entre Fácil, Media y Avanzada. Completa sus 5 niveles '
              'para abrir la siguiente y ganar monedas de este género.',
        ),
      ],
    );
  }

  /// Avisa de las insignias conseguidas desde la última vez. Solo con todos
  /// los datos cargados, para no tomar como nueva una que ya se tenía.
  Future<void> _revisarInsignias() async {
    final estado = _estado;
    if (estado == null || _loading) return;
    if (!widget.user.isAnonymous && !_saldoCargado) return;
    if (_resumenIntros == null) return;
    if (_avisando) {
      _revisarOtraVez = true;
      return;
    }
    _avisando = true;
    try {
      final logrados = {
        for (final logro in logrosDe(
          _saldo.deGenero(widget.genero),
          avanceDe(estado.dificultades, _resumenIntros, widget.genero),
          widget.genero,
        ))
          if (logro.logrado) logro.nombre: logro,
      };
      final nuevas = await InsigniasVistas(
        widget.user.uid,
      ).registrar(logrados.keys.toSet());
      for (final nombre in nuevas) {
        if (!mounted) break;
        await mostrarInsignia(context, logrados[nombre]!);
      }
    } finally {
      _avisando = false;
    }
    if (_revisarOtraVez && mounted) {
      _revisarOtraVez = false;
      await _revisarInsignias();
    }
  }

  @override
  void initState() {
    super.initState();
    if (!widget.user.isAnonymous) {
      _suscripcionSaldo = ref
          .read(firebaseGameRepositoryProvider)
          .saldoSalas()
          .listen(
            (saldo) {
              setState(() {
                _saldo = saldo;
                _saldoCargado = true;
              });
              _revisarInsignias();
            },
            onError: (Object error) =>
                debugPrint('No se pudo leer el saldo de salas: $error'),
          );
    }
    if (widget.user.isAnonymous) {
      _iniciarSesionInvitado();
    } else {
      _cargar(esperar: true);
    }
  }

  @override
  void dispose() {
    _suscripcionSaldo?.cancel();
    super.dispose();
  }

  Future<void> _iniciarSesionInvitado() async {
    try {
      await ref.read(firebaseGameRepositoryProvider).iniciarSesionInvitado();
      if (mounted) await _cargar(esperar: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  /// [esperar]: en la primera carga se deja la pantalla [esperaMinimaCarga] para
  /// leer la curiosidad; las recargas (tras un nivel) no esperan.
  Future<void> _cargar({bool esperar = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = ref.read(firebaseGameRepositoryProvider);
      final minimo = esperar ? Future<void>.delayed(esperaMinimaCarga) : null;
      final estado = await repository.cargarEstado();
      await minimo;
      if (!mounted) return;
      setState(() {
        _estado = estado;
        _loading = false;
      });
      unawaited(_revisarInsignias());
      unawaited(
        _estadoIntros().then((intros) {
          if (mounted) {
            setState(() {
              _resumenIntros = intros;
              _monedas = intros?.monedas ?? _monedas;
              _monedasPorGenero = intros?.monedasPorGenero ?? _monedasPorGenero;
            });
            _revisarInsignias();
          }
        }),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<ResultadoNivel?> _iniciar(
    Nivel nivel, {
    int? numeroVisible,
    bool haySiguiente = false,
    bool reemplazar = false,
  }) async {
    if (_startingLevelId != null) return null;
    setState(() => _startingLevelId = nivel.id);
    try {
      final partida = await ref
          .read(firebaseGameRepositoryProvider)
          .iniciarNivel(nivel.id);
      return await _pushGame(
        nivel: partida.nivel,
        gameId: partida.gameId,
        numeroVisible: numeroVisible,
        haySiguiente: haySiguiente,
        reemplazar: reemplazar,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo iniciar el nivel: $error')),
        );
        // El nivel anterior sigue abierto esperando al siguiente: se cierra.
        if (reemplazar) Navigator.of(context).pop();
      }
      return null;
    } finally {
      if (mounted) setState(() => _startingLevelId = null);
    }
  }

  Future<ResultadoNivel?> _pushGame({
    required Nivel nivel,
    required String gameId,
    required int? numeroVisible,
    required bool haySiguiente,
    required bool reemplazar,
  }) async {
    if (!mounted) return null;
    final navigator = Navigator.of(context);
    // "Siguiente nivel" no cierra la pantalla: el próximo nivel la reemplaza.
    final siguiente = Completer<ResultadoNivel>();
    final route = MaterialPageRoute<ResultadoNivel>(
      builder: (_) => GameScreen(
        nivel: nivel,
        gameId: gameId,
        numeroVisible: numeroVisible,
        onSiguiente: haySiguiente
            ? () {
                if (!siguiente.isCompleted) {
                  siguiente.complete(ResultadoNivel.siguiente);
                }
              }
            : null,
      ),
    );
    if (reemplazar) {
      unawaited(navigator.pushReplacement(route));
    } else {
      unawaited(navigator.push(route));
    }
    final resultado = await Future.any([route.popped, siguiente.future]);
    if (resultado == ResultadoNivel.siguiente) {
      // Sin avisos: el nivel ganado sigue en pantalla y un diálogo pendiente
      // lo dejaría congelado. Desbloqueos y fin de juego solo ocurren en el
      // último nivel, que no tiene "Siguiente nivel".
      await _cargar();
    } else if (resultado != null) {
      final antes = _desbloqueadas();
      final terminadoAntes = _juegoTerminado();
      // Las insignias esperan a que salgan estos avisos.
      _avisando = true;
      await _cargar();
      final nuevas = _desbloqueadas().difference(antes);
      for (final dificultad in nuevas) {
        if (!mounted) break;
        await _avisarDesbloqueo(dificultad);
      }
      if (!terminadoAntes && _juegoTerminado() && mounted) {
        await _avisarJuegoTerminado();
      }
      _avisando = false;
      _revisarOtraVez = false;
      await _revisarInsignias();
    }
    return resultado;
  }

  Set<Dificultad> _desbloqueadas() => {
    for (final progreso in _estado?.dificultades ?? const [])
      // Fácil siempre está desbloqueada; no hay dificultad previa que celebrar.
      if (progreso.desbloqueada && progreso.dificultad != Dificultad.facil)
        progreso.dificultad,
  };

  bool _juegoTerminado() =>
      _estado?.dificultades.any(
        (progreso) =>
            progreso.dificultad == Dificultad.avanzado &&
            progreso.total >= 5 &&
            progreso.completados >= progreso.total,
      ) ??
      false;

  Future<void> _avisarJuegoTerminado() => showDialog<void>(
    context: context,
    builder: (context) => LiquidGlassDialog(
      icon: const Icon(PhosphorIconsFill.trophy, size: 56),
      title: const Text('¡Juego completado!', textAlign: TextAlign.center),
      content: const Text(
        'Superaste las tres dificultades: Fácil, Media y Avanzada. '
        '¡Tienes un oído de campeón! Puedes repetir cualquier nivel cuando quieras.',
        textAlign: TextAlign.center,
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('¡Genial!'),
        ),
      ],
    ),
  );

  Future<void> _avisarDesbloqueo(Dificultad desbloqueada) {
    final completada = Dificultad.values[desbloqueada.index - 1];
    return showDialog<void>(
      context: context,
      builder: (context) => LiquidGlassDialog(
        icon: const Icon(PhosphorIconsFill.trophy, size: 48),
        title: Text(
          '¡Dificultad ${_nombreDificultad(completada)} completada!',
          textAlign: TextAlign.center,
        ),
        content: Text(
          'Superaste los 5 niveles. Ya puedes jugar la dificultad '
          '${_nombreDificultad(desbloqueada)}.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('¡Vamos!'),
          ),
        ],
      ),
    );
  }

  List<NivelAsignado> _nivelesDe(Dificultad dificultad) {
    final estado = _estado;
    if (estado == null) return const [];
    final esDificultadActiva = estado.dificultadActiva == dificultad;
    final nivelesRemotos = esDificultadActiva
        ? estado.niveles
        : estado.nivelesRepetibles
              .where((item) => item.nivel.dificultad == dificultad)
              .toList(growable: false);
    return nivelesRemotos;
  }

  Future<EstadoIntros?> _estadoIntros() async {
    try {
      return await ref
          .read(firebaseGameRepositoryProvider)
          .cargarIntros()
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
  }

  /// Juega el nivel [index] y sigue con los siguientes mientras el jugador
  /// elija "Siguiente nivel".
  Future<void> _jugar(Dificultad dificultad, int index) async {
    var actual = index;
    var reemplazar = false;
    while (mounted) {
      final niveles = _nivelesDe(dificultad);
      final puedeJugar =
          actual < niveles.length &&
          (niveles[actual].completado || niveles[actual].puedeIniciar);
      if (!puedeJugar) {
        // El nivel ganado sigue abierto esperando al siguiente: se cierra.
        if (reemplazar) Navigator.of(context).pop();
        break;
      }
      final resultado = await _iniciar(
        niveles[actual].nivel,
        numeroVisible: actual + 1,
        haySiguiente: actual + 1 < niveles.length,
        reemplazar: reemplazar,
      );
      if (!mounted) return;
      setState(() {});
      if (resultado != ResultadoNivel.siguiente) break;
      actual++;
      reemplazar = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = _estado;
    // El fondo cubre también la barra para que el vidrio tenga qué mostrar.
    return Theme(
      data: temaGenero(context, widget.genero),
      child: LiquidBackground(
        // Canción, Intro y Progreso van del color del género; solo Medley
        // conserva los suyos.
        acento: switch (_pestana) {
          _ when !widget.genero.esPopurri => colorGenero(widget.genero),
          _pCancion when estado != null => colorDificultad(
            _seleccionada ?? estado.dificultadActiva,
          ),
          _pIntro => paletaGenero(widget.genero).intro,
          _ => colorGenero(widget.genero),
        },
        manchas: (
          paletaGenero(widget.genero).mancha1,
          paletaGenero(widget.genero).mancha2,
        ),
        // Atrás desde cualquier pestaña vuelve al menú, y desde el menú, a los
        // géneros.
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_pestana == 0) {
              widget.onCambiarGenero();
              // Desde los niveles se vuelve primero a las dificultades.
            } else if (_pestana == _pCancion && _nivelesAbiertos) {
              _cerrarNiveles();
            } else {
              _cambiarPestana(0);
            }
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: LiquidGlassAppBar(
              // Título centrado y del color del género; el logo (menú) o el
              // botón atrás se quedan a la izquierda.
              colorTitulo: colorGenero(widget.genero),
              leadingWidth: _pestana == 0 && !_nivelesAbiertos ? 72 : null,
              leading: _pestana == _pCancion && _nivelesAbiertos
                  ? IconButton(
                      tooltip: 'Volver a las dificultades',
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: _cerrarNiveles,
                    )
                  : _pestana != 0
                  ? IconButton(
                      tooltip: 'Volver al menú del género',
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => _cambiarPestana(0),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(left: 16),
                      // Tocar el logo hace lo mismo que "Inicio".
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: widget.onCambiarGenero,
                        child: Tooltip(
                          message: 'Menú principal',
                          child: Image.asset(
                            'lib/assets/images/logo/riff_logo.png',
                            height: 56,
                            cacheHeight: 192,
                            semanticLabel: 'RIFF',
                          ),
                        ),
                      ),
                    ),
              title: _tituloBarra(estado),
              actions: [..._accionesBarra(), const SizedBox(width: 8)],
            ),
            // Sin "Menú": el carrusel de tarjetas aparece al entrar al género
            // (y con atrás); la barra solo lleva a las secciones.
            bottomNavigationBar: LiquidGlassBottomNav(
              colores: List.filled(
                4,
                paletaGenero(widget.genero).barraSecciones,
              ),
              claves: _clavesPestanas.sublist(1),
              // En el carrusel (pestaña 0) no hay ninguna marcada.
              currentIndex: _pestana - 1,
              onTap: (i) => _cambiarPestana(i + 1),
              items: const [
                (icon: PhosphorIconsFill.musicNotes, label: 'Canción'),
                (icon: PhosphorIconsFill.headphones, label: 'Intro'),
                (icon: Icons.insights_rounded, label: 'Progreso'),
                (icon: Icons.settings_rounded, label: 'Ajustes'),
              ],
            ),
            body: TransicionMusical(
              child: switch (_pestana) {
                _pCancion => _pestanaCancion(estado),
                _pIntro => _pestanaIntro(),
                _pProgreso => _PestanaProgreso(
                  key: const ValueKey('progreso'),
                  dificultades: estado?.dificultades ?? const [],
                  intros: _introsFuturo,
                  saldo: _saldo.deGenero(widget.genero),
                  esInvitado: widget.user.isAnonymous,
                ),
                // Dentro de un género no hay reiniciar, eliminar ni cerrar sesión.
                _pAjustes => _PestanaConfiguracion(
                  key: const ValueKey('configuracion'),
                  onRecorrido: _verRecorrido,
                ),
                _ => _pestanaMenu(estado),
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Título de la barra de arriba según la pestaña: el logo en el menú y el
  /// nombre de la sección en las demás.
  Widget _tituloBarra(EstadoJuegoRemoto? estado) => switch (_pestana) {
    _pCancion => const Text('Adivina la canción'),
    _pIntro => const Text('Adivina la intro'),
    _pProgreso => const Text('Progreso'),
    _pAjustes => const Text('Ajustes'),
    // El género, para saber dónde se está (el logo va a la izquierda).
    _ => Text(widget.genero.nombre),
  };

  /// Moneda del género en Intro y Progreso; fichas 🎟️ en Salas y Progreso.
  List<Widget> _accionesBarra() => [
    // Siempre a la vista: vuelve a la selección de género y a las salas.
    Tooltip(
      message: 'Menú principal',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onCambiarGenero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.home_rounded, size: 28),
              Text(
                'Inicio',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    ),
  ];

  void _cambiarPestana(int pestana) {
    setState(() {
      // Sentido de la onda de la transición: hacia la pestaña nueva.
      _pestana = pestana;
      _nivelesAbiertos = false;
      // Progreso se vuelve a pedir al abrir la pestaña, para que esté al día.
      if (pestana == _pProgreso) {
        _introsFuturo = _estadoIntros()
          ..then((intros) {
            if (mounted && intros != null) {
              setState(() {
                _monedas = intros.monedas;
                _monedasPorGenero = intros.monedasPorGenero;
                _resumenIntros = intros;
              });
              _revisarInsignias();
            }
          });
      }
    });
    if (pestana == _pCancion && _estado != null) _recorridoDificultades();
  }

  /// Carga o error del progreso; null si ya está listo.
  Widget? _esperandoProgreso() {
    if (_loading) {
      return const Cargando(
        key: ValueKey('cargando'),
        texto: 'Cargando progreso...',
      );
    }
    if (_error != null) return _ErrorPanel(error: _error!, onRetry: _cargar);
    if (_estado == null) {
      return const Center(child: Text('No se pudo cargar el progreso.'));
    }
    return null;
  }

  Widget _pestanaMenu(EstadoJuegoRemoto? estado) {
    if (_esperandoProgreso() case final espera?) return espera;
    return _MenuPrincipal(
      key: const ValueKey('menu'),
      genero: widget.genero,
      claveCarrusel: _claveMenu,
      onVisible: _recorridoSiEsNuevo,
      infoCancion: _infoCancion(estado!),
      infoIntros: _resumenIntros == null
          ? null
          : '${_resumenIntros!.intros.length} intros desbloqueadas',
      onInstrumentos: () => _cambiarPestana(_pCancion),
      onIntros: () => _cambiarPestana(_pIntro),
      onProgreso: () => _cambiarPestana(_pProgreso),
      infoProgreso: _infoProgreso(estado),
    );
  }

  String _infoCancion(EstadoJuegoRemoto estado) => _textoNivel(estado);

  /// "7 de 15 niveles" del género.
  String? _infoProgreso(EstadoJuegoRemoto estado) {
    final total = estado.dificultades.fold(0, (suma, d) => suma + d.total);
    if (total == 0) return null;
    final hechos = estado.dificultades.fold(
      0,
      (suma, d) => suma + d.completados,
    );
    return '$hechos de $total niveles';
  }

  Widget _pestanaIntro() {
    if (_esperandoProgreso() case final espera?) return espera;
    return IntrosScreen(
      key: const ValueKey('intro'),
      embebida: true,
      onEstado: (intros) {
        setState(() {
          _monedas = intros.monedas;
          _monedasPorGenero = intros.monedasPorGenero;
          _resumenIntros = intros;
        });
        _revisarInsignias();
      },
    );
  }

  void _cerrarNiveles() => setState(() => _nivelesAbiertos = false);

  Widget _pestanaCancion(EstadoJuegoRemoto? estado) {
    if (_esperandoProgreso() case final espera?) return espera;
    return _PanelDificultades(
      key: _claveDificultades,
      estado: estado!,
      seleccionada: _seleccionada ?? estado.dificultadActiva,
      esInvitado: widget.user.isAnonymous,
      nivelesDe: _nivelesDe,
      abierta: _nivelesAbiertos,
      onCambio: (dificultad) => setState(() => _seleccionada = dificultad),
      onAbrir: (dificultad) => setState(() {
        _seleccionada = dificultad;
        _nivelesAbiertos = true;
      }),
      onJugar: _jugar,
      onRefresh: _cargar,
    );
  }
}

String _nombreSesion(User user) {
  final nombre = user.displayName;
  if (nombre != null && nombre.trim().isNotEmpty) return nombre;
  return user.email ?? 'usuario';
}
