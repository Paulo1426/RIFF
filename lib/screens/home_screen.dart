import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/genero.dart';
import '../models/logros.dart';
import '../models/nivel.dart';
import '../models/sala.dart';
import '../providers/providers.dart';
import '../services/firebase_game_repository.dart';
import '../services/offline_game_store.dart';
import '../animations/ciclo_lento.dart';
import '../animations/transicion_musical.dart';
import '../animations/liquid_ripple_effect.dart';
import '../widgets/aviso_insignia.dart';
import '../widgets/boton_tema.dart';
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
import 'instrucciones_dialog.dart';
import '../widgets/recorrido.dart';
import 'intros_screen.dart';
import 'salas_screen.dart';

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
  // Sentido del cambio entre el selector y el menú del género: 1 al entrar,
  // -1 al volver (se hace polvo), 0 sin animación (tras el login).
  int _direccionGenero = 0;
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
          _direccionGenero = 0;
          return FirebaseAuthScreen(
            savedUser: user,
            onSignedIn: () => setState(() => _entered = true),
          );
        }
        if (_desdeLogin) {
          return BienvenidaLogin(
            nombre: user.isAnonymous ? null : _nombreSesion(user),
            onFin: () {
              if (mounted) setState(() => _desdeLogin = false);
            },
          );
        }
        final genero = _genero;
        // Como entre pestañas: al entrar a un género el menú llega
        // deslizándose; al volver a los géneros se hace polvo.
        return TransicionMusical(
          pestana: genero?.index ?? -1,
          direccion: _direccionGenero,
          color: genero == null ? azulLogin : colorGenero(genero),
          child: KeyedSubtree(
            key: ValueKey(genero),
            child: genero == null
                ? _SelectorGenero(
                    user: user,
                    onElegir: (genero) => setState(() {
                      generoActivo = genero;
                      _genero = genero;
                      _direccionGenero = 1;
                    }),
                  )
                : _AuthenticatedHome(
                    key: ValueKey(user.uid),
                    user: user,
                    genero: genero,
                    onCambiarGenero: () => setState(() {
                      _genero = null;
                      _direccionGenero = -1;
                    }),
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
  int _frente = 0;
  final _carrusel = GlobalKey<CarruselGiratorioState>();
  // Pestaña lateral tocada: la gota va hasta ella mientras gira el carrusel
  // y vuelve al centro con el nombre nuevo.
  int? _pestanaTocada;
  // Nivel e intros de cada género disponible (sin dato, sin línea).
  final _avance = <Genero, String>{};
  // Lo mismo sin formato, para el progreso general.
  final _datos = <Genero, ({EstadoJuegoRemoto estado, EstadoIntros? intros})>{};
  // Las salas son de todos los géneros.
  SaldoSalas _saldo = const SaldoSalas();
  StreamSubscription<SaldoSalas>? _suscripcionSaldo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _avisoAuriculares(context);
    });
    for (final genero in Genero.values.where((g) => g.disponible)) {
      unawaited(_cargarAvance(genero));
    }
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
    _suscripcionSaldo?.cancel();
    super.dispose();
  }

  Future<void> _cargarAvance(Genero genero) async {
    final repo = ref.read(firebaseGameRepositoryProvider);
    try {
      final estado = await repo.cargarEstado(genero: genero);
      // Sin niveles cargados (género en preparación) no hay nivel que mostrar.
      final hayNiveles = estado.dificultades.any((d) => d.total > 0);
      // Las intros se desbloquean con el primer nivel: si fallan, sin dato.
      final intros = await repo
          .cargarIntros(genero: genero)
          .then<EstadoIntros?>((e) => e, onError: (_) => null);
      final adivinadas = intros?.intros
          .where((i) => i.estado == EstadoIntro.completada)
          .length;
      final partes = [
        if (hayNiveles) _textoNivel(estado),
        if (adivinadas != null) '🎧 $adivinadas intros descubiertas',
      ];
      if (mounted) {
        setState(() => _datos[genero] = (estado: estado, intros: intros));
      }
      if (mounted && partes.isNotEmpty) {
        setState(() => _avance[genero] = partes.join('\n'));
      }
    } catch (error) {
      // Sin conexión o sin progreso aún: la tarjeta sale sin la línea.
      debugPrint('Sin avance de ${genero.nombre}: $error');
    }
  }

  // Después de los géneros va "Aleatorio" y al final, las salas.
  static final _iAleatorio = Genero.values.length;

  int get _total => Genero.values.length + 3;
  static final _iProgreso = Genero.values.length + 2;

  ({IconData icon, String label}) _pestanaDe(int index) =>
      index < Genero.values.length
      ? (
          icon: switch (Genero.values[index]) {
            Genero.vallenato => Icons.music_note_rounded,
            Genero.reggaeton => Icons.headphones_rounded,
            Genero.rockPop => Icons.electric_bolt_rounded,
            Genero.salsa => Icons.nightlife_rounded,
            Genero.popular => Icons.mic_external_on_rounded,
          },
          label: Genero.values[index].nombre,
        )
      : index == _iAleatorio
      ? (icon: Icons.casino_rounded, label: 'Aleatorio')
      : index == _iProgreso
      ? (icon: Icons.insights_rounded, label: 'Progreso')
      : (icon: Icons.emoji_events_rounded, label: 'Salas');

  Color _color(int index) => index < Genero.values.length
      ? colorGenero(Genero.values[index])
      : index == _iAleatorio
      ? colorAleatorio
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
          appBar: LiquidGlassAppBar(title: Text(titulo), actions: acciones),
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
    // Solo la del frente se mueve; laterales y reflejo, quietas.
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
    if (index == _iAleatorio) {
      return _CuadroModo(
        emoji: '🎲',
        animacion: _Animacion.saltar,
        titulo: 'Aleatorio',
        detalle: 'Próximamente',
        color: colorAleatorio,
        alFrente: alFrente,
        animar: moverse,
        bloqueado: true,
        onTap: null,
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
        detalle: 'Todos los géneros, salas e insignias generales.',
        info: _datos.isEmpty ? null : '$niveles niveles · 🎧 $intros intros',
        color: AppColors.oro,
        alFrente: alFrente,
        animar: moverse,
        onTap: () => _abrir(
          'Progreso general',
          _ProgresoTodo(
            datos: Map.of(_datos),
            saldo: _saldo,
            esInvitado: widget.user.isAnonymous,
          ),
          acento: AppColors.oro,
        ),
      );
    }
    final invitado = widget.user.isAnonymous;
    return _CuadroModo(
      emoji: '🏆',
      animacion: _Animacion.saltar,
      titulo: 'Salas',
      detalle: invitado
          ? 'Crea una cuenta para jugar en salas.'
          : 'Reta a hasta 5 amigos en el género que elijas. Con historial.',
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
          centerTitle: false,
          title: // Solo el logo, a la izquierda; ya dice RIFF.
          Image.asset(
            'lib/assets/images/logo/riff_logo.png',
            height: 56,
            semanticLabel: 'RIFF',
          ),
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
                    // La copia del reflejo va sin desenfoque.
                    reflejo: _cuadro(index, false, animar: false),
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

/// Empezar desde cero: confirma, pide la contraseña (o Google) de nuevo y
/// borra el progreso de todos los géneros en el servidor y en el teléfono.
/// [alEmpezar] corre ya confirmada la cuenta. Devuelve si se reinició.
Future<bool> _reiniciarCuenta(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? alEmpezar,
}) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (context) => LiquidGlassDialog(
      icon: const Icon(Icons.warning_amber_rounded, size: 56),
      title: const Text('¿Empezar desde cero?', textAlign: TextAlign.center),
      content: const Text(
        'Se borrarán tus niveles, intros, monedas, fichas, estadísticas de '
        'salas e insignias. No se puede deshacer.',
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
  final user = FirebaseAuth.instance.currentUser;
  if (confirmar != true || user == null || !context.mounted) return false;
  final mensajes = ScaffoldMessenger.of(context);
  try {
    final conCorreo = user.providerData.any(
      (proveedor) => proveedor.providerId == 'password',
    );
    if (conCorreo) {
      final clave = await showDialog<String>(
        context: context,
        builder: (_) => const DialogoContrasena(accion: 'Reiniciar'),
      );
      if (clave == null) return false;
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: clave),
      );
    } else {
      await prepararGoogle();
      final cuenta = await GoogleSignIn.instance.authenticate();
      final idToken = cuenta.authentication.idToken;
      if (idToken == null) throw StateError('Google no confirmó la cuenta.');
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    }
    alEmpezar?.call();
    await ref.read(firebaseGameRepositoryProvider).reiniciarProgreso();
    await OfflineGameStore().borrar(user.uid);
    await ref.read(offlineIntroStoreProvider).borrar(user.uid);
    await InsigniasVistas(user.uid).borrar();
    mensajes.showSnackBar(
      const SnackBar(content: Text('Tu progreso empezó desde cero.')),
    );
    return true;
  } catch (error) {
    final mensaje = switch (error) {
      FirebaseAuthException(code: 'wrong-password' || 'invalid-credential') =>
        'La contraseña no es correcta.',
      GameRepositoryException(:final message) => message,
      _ => 'No se pudo reiniciar el progreso: $error',
    };
    mensajes.showSnackBar(SnackBar(content: Text(mensaje)));
    return false;
  }
}

/// Cierra la sesión; la de invitado se borra entera. Las pantallas abiertas
/// encima (ajustes, salas) se cierran con ella.
Future<void> _cerrarSesionDe(
  BuildContext context,
  WidgetRef ref,
  User user,
) async {
  final mensajes = ScaffoldMessenger.of(context);
  Navigator.of(context).popUntil((route) => route.isFirst);
  try {
    if (user.isAnonymous) {
      await ref.read(firebaseGameRepositoryProvider).finalizarSesionInvitado();
      await user.delete();
    }
    await FirebaseAuth.instance.signOut();
  } catch (error) {
    mensajes.showSnackBar(
      SnackBar(content: Text('No se pudo cerrar sesión: $error')),
    );
  }
}

// Una vez por apertura de la app; cerrar sesión y volver a entrar no lo repite.
var _avisoAuricularesMostrado = false;

/// Tras el login, antes de elegir género: se recomienda usar auriculares.
Future<void> _avisoAuriculares(BuildContext context) async {
  if (_avisoAuricularesMostrado) return;
  _avisoAuricularesMostrado = true;
  await showDialog<void>(
    context: context,
    builder: (context) => LiquidGlassDialog(
      icon: const Icon(Icons.headphones_rounded, size: 64, color: azulLogin),
      title: const Text('Usa auriculares', textAlign: TextAlign.center),
      content: const Text(
        'Se recomienda usar cascos (audífonos o auriculares) para '
        'distinguir bien cada instrumento.',
        textAlign: TextAlign.center,
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: azulLogin,
            foregroundColor: AppColors.paperWhite,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
  unawaited(Recordatorios.programar());
}

// GoogleSignIn se inicializa una sola vez (login y confirmar la cuenta).
Future<void>? _googleListo;
Future<void> prepararGoogle() =>
    _googleListo ??= GoogleSignIn.instance.initialize();

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
  bool _offlineMode = false;
  String? _startingLevelId;
  final _offlineStore = OfflineGameStore();
  OfflineGameSnapshot? _offlineSnapshot;
  // Dificultad mostrada en el centro; null = la dificultad activa.
  Dificultad? _seleccionada;
  // Pestaña Canción: false muestra el carrusel de dificultades; true, la
  // tarjeta con todos los niveles de la seleccionada.
  bool _nivelesAbiertos = false;
  // Sentido de la transición entre dificultades y niveles: 1 al abrir, -1 al
  // volver, 0 sin animación (al entrar a la pestaña).
  int _direccionNiveles = 0;
  // Barra inferior: 0 menú, 1 Adivina la canción, 2 Adivina la intro,
  // 3 progreso, 4 configuración. Las salas están en el selector de géneros.
  int _pestana = 0;
  // Sentido del último cambio de pestaña (0 al abrir: sin onda).
  int _direccion = 0;
  static const _pCancion = 1, _pIntro = 2, _pProgreso = 3;
  static const _pAjustes = 4;
  Future<EstadoIntros?>? _introsFuturo;
  // Para las tarjetas del menú: cuántas intros tiene y salas ganadas.
  EstadoIntros? _resumenIntros;
  SaldoSalas _saldo = const SaldoSalas();
  StreamSubscription<SaldoSalas>? _suscripcionSaldo;
  // Monedas de Adivina la intro para la barra (null hasta saberlas).
  int? _monedas;
  // El saldo de salas ya llegó (antes es todo cero y no sirve para insignias).
  bool _saldoCargado = false;
  // Revisando insignias o mostrando avisos al terminar un nivel.
  bool _avisando = false;
  bool _revisarOtraVez = false;
  // El paquete offline se actualiza en segundo plano, uno tras otro.
  Future<void> _paquete = Future.value();
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
          'Desliza las tarjetas para elegir modo. Con el botón de arriba a '
          'la derecha vuelves a los géneros y a las salas.',
    ),
    PasoRecorrido(
      clave: _clavesPestanas[_pCancion],
      titulo: '${widget.genero.instrumentos.characters.first} Canción',
      texto: 'Las dificultades y niveles de Adivina la canción.',
    ),
    PasoRecorrido(
      clave: _clavesPestanas[_pIntro],
      titulo: '🎧 Intro',
      texto: 'Tu colección de Adivina la intro y el botón para sacar cartas.',
    ),
    PasoRecorrido(
      clave: _clavesPestanas[_pProgreso],
      titulo: '📈 Progreso',
      texto:
          'Tus niveles, tus monedas 🪙, tus fichas 🎟️ y las canciones que '
          'ya adivinaste.',
    ),
    PasoRecorrido(
      clave: _clavesPestanas[_pAjustes],
      titulo: '⚙️ Ajustes',
      texto:
          'Instrucciones, música del menú, modo oscuro, '
          'reiniciar el progreso y cerrar sesión.',
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
              'para abrir la siguiente y gana monedas 🪙 para las intros.',
        ),
      ],
    );
  }

  // "Adivina la intro" se abre al completar el primer nivel.
  bool get _introsDisponibles =>
      _estado?.dificultades.any((item) => item.completados > 0) ?? false;

  /// Avisa de las insignias conseguidas desde la última vez. Solo con todos
  /// los datos cargados, para no tomar como nueva una que ya se tenía.
  Future<void> _revisarInsignias() async {
    final estado = _estado;
    if (estado == null || _loading) return;
    if (!widget.user.isAnonymous && !_saldoCargado) return;
    if (_introsDisponibles && _resumenIntros == null) return;
    if (_avisando) {
      _revisarOtraVez = true;
      return;
    }
    _avisando = true;
    try {
      final logrados = {
        for (final logro in logrosDe(
          _saldo.deGenero(widget.genero),
          _avanceDe(estado.dificultades, _resumenIntros),
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
      _cargar();
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
      if (mounted) await _cargar();
    } catch (error) {
      if (!mounted) return;
      await _loadOfflineSnapshot(error);
    }
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      OfflineGameSnapshot? snapshot;
      try {
        snapshot = await _offlineStore.load(widget.user.uid);
      } on FormatException catch (error) {
        debugPrint('La copia offline está dañada: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'La copia local de progreso no se pudo leer; se intentará recuperar desde internet.',
              ),
            ),
          );
        }
      } on FileSystemException catch (error) {
        debugPrint('No se pudo leer la copia offline: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo leer el almacenamiento local; se intentará cargar desde internet.',
              ),
            ),
          );
        }
      }
      if (snapshot != null) {
        await _syncPendingCompletions(snapshot);
      }
      final repository = ref.read(firebaseGameRepositoryProvider);
      final estado = await repository.cargarEstado();
      if (!mounted) return;
      setState(() {
        _estado = estado;
        _offlineMode = false;
        _loading = false;
      });
      unawaited(_revisarInsignias());
      if (_introsDisponibles) {
        unawaited(
          _estadoIntros().then((intros) {
            if (mounted) {
              setState(() {
                _resumenIntros = intros;
                _monedas = intros?.monedas ?? _monedas;
              });
              _revisarInsignias();
            }
          }),
        );
      }
    } catch (error) {
      if (!mounted) return;
      await _loadOfflineSnapshot(error);
    }
  }

  /// Baja en segundo plano [levelId] recién ganado para repetirlo sin
  /// conexión. Los instrumentos que ya sonaron salen de la caché.
  Future<void> _actualizarPaquete(String levelId) async {
    try {
      _seguirEnGenero();
      final bundle = await ref
          .read(firebaseGameRepositoryProvider)
          .descargarPaqueteOffline(levelId);
      final refreshed = await _cacheOfflineBundle(
        bundle,
        widget.user.uid,
        widget.user.isAnonymous,
      );
      if (!mounted) return;
      setState(() => _offlineSnapshot = refreshed);
    } catch (error) {
      debugPrint(
        'No se pudo descargar $levelId para jugar sin conexión: $error',
      );
    }
  }

  Future<void> _loadOfflineSnapshot(Object onlineError) async {
    try {
      final snapshot = await _offlineStore.load(widget.user.uid);
      if (!mounted) return;
      if (snapshot == null) {
        setState(() {
          _error = onlineError;
          _loading = false;
        });
        return;
      }
      setState(() {
        _offlineSnapshot = snapshot;
        _estado = snapshot.estado;
        _offlineMode = true;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<OfflineGameSnapshot> _cacheOfflineBundle(
    Map<String, dynamic> bundle,
    String uid,
    bool guest,
  ) async {
    final state = Map<String, dynamic>.from(bundle['estado'] as Map);
    final rawLevels = bundle['levels'] as List<dynamic>;
    final audioService = ref.read(audioServiceProvider);
    Future<OfflineLevelData> descargarNivel(dynamic rawLevel) async {
      final data = Map<String, dynamic>.from(rawLevel as Map);
      final entry = Map<String, dynamic>.from(data['entry'] as Map);
      final nivelJson = Map<String, dynamic>.from(entry['nivel'] as Map);
      final nivel = Nivel.fromJson(nivelJson);
      final urls = Map<String, dynamic>.from(data['audioUrls'] as Map);
      // Versión de cada archivo: si se reemplaza en Storage se baja otra vez.
      final versiones = Map<String, dynamic>.from(
        data['audioVersions'] as Map? ?? const {},
      );
      final paths = <String, String>{};
      for (final instrument in nivel.instrumentos) {
        final url = urls[instrument.id];
        if (url is! String || url.isEmpty) {
          throw FormatException(
            'Falta el enlace offline del instrumento ${instrument.id} en ${nivel.id}',
          );
        }
        final key =
            'level:${nivel.id}:stem:${instrument.id}:'
            '${versiones[instrument.id] ?? ''}';
        _seguirEnGenero();
        final file = await audioService.descargarYGuardar(url, key);
        paths[instrument.id] = file.path;
      }
      final instrumentalUrl = data['instrumentalAudioUrl'];
      if (instrumentalUrl is! String || instrumentalUrl.isEmpty) {
        throw FormatException(
          'Falta el enlace offline de la pista instrumental de ${nivel.id}',
        );
      }
      _seguirEnGenero();
      final instrumentalFile = await audioService.descargarYGuardar(
        instrumentalUrl,
        'song:${nivel.cancionId}:instrumentalSong:'
        '${versiones['instrumental'] ?? ''}',
      );
      return OfflineLevelData(
        nivel: nivel,
        completado: entry['completado'] as bool? ?? false,
        puedeIniciar: entry['puede_iniciar'] as bool? ?? false,
        respuestaHash:
            data['respuestaHash'] as String? ??
            OfflineGameStore.huella(
              nivel.id,
              (data['respuesta'] as String?) ?? '',
            ),
        audioPaths: paths,
        instrumentalAudioPath: instrumentalFile.path,
      );
    }

    // De a 3 niveles: no satura la red, el disco ni la batería mientras el
    // jugador ya está usando la app (corre en segundo plano).
    const lote = 3;
    final nuevos = <OfflineLevelData>[];
    for (var i = 0; i < rawLevels.length; i += lote) {
      nuevos.addAll(
        await Future.wait(rawLevels.skip(i).take(lote).map(descargarNivel)),
      );
    }
    // Se suman a los ya guardados: cada nivel llega al ganarlo.
    final ids = {for (final level in nuevos) level.nivel.id};
    final levels = [
      if (_offlineSnapshot?.uid == uid)
        ..._offlineSnapshot!.levels.where(
          (level) => !ids.contains(level.nivel.id),
        ),
      ...nuevos,
    ];
    final snapshot = OfflineGameSnapshot(
      uid: uid,
      guest: guest,
      stateJson: state,
      levels: levels,
      pendingCompletions: _offlineSnapshot?.uid == uid
          ? _offlineSnapshot!.pendingCompletions
          : const [],
    );
    _seguirEnGenero();
    await _offlineStore.save(snapshot);
    return snapshot;
  }

  /// Las descargas y sincronizaciones siguen en segundo plano al volver al
  /// selector: si ya se eligió otro género, paran antes de mezclar los dos.
  void _seguirEnGenero() {
    if (generoActivo != widget.genero) throw StateError('Cambió el género');
  }

  Future<void> _syncPendingCompletions(OfflineGameSnapshot snapshot) async {
    var current = snapshot;
    final repository = ref.read(firebaseGameRepositoryProvider);
    for (final completion in snapshot.pendingCompletions) {
      final levelId = completion['levelId'];
      final answer = completion['answer'];
      if (levelId == null || answer == null) {
        throw const FormatException('Hay un progreso offline incompleto');
      }
      _seguirEnGenero();
      await repository.sincronizarNivelOffline(
        levelId: levelId,
        respuesta: answer,
      );
      current = current.withoutPendingCompletion(levelId);
      _seguirEnGenero();
      await _offlineStore.save(current);
    }
    _offlineSnapshot = current;
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
      OfflineLevelData? offlineLevel;
      for (final cachedLevel
          in _offlineSnapshot?.levels ?? const <OfflineLevelData>[]) {
        if (cachedLevel.nivel.id == nivel.id) {
          offlineLevel = cachedLevel;
          break;
        }
      }
      // Sin conexión solo se repiten niveles ya aprobados y descargados.
      final repetible = offlineLevel != null && offlineLevel.completado;
      if (_offlineMode) {
        if (!repetible) {
          throw StateError(
            'Sin conexión solo puedes repetir niveles que ya aprobaste.',
          );
        }
        return await _pushGame(
          nivel: offlineLevel.nivel,
          gameId: 'offline-${DateTime.now().microsecondsSinceEpoch}',
          numeroVisible: numeroVisible,
          haySiguiente: haySiguiente,
          reemplazar: reemplazar,
          offlineLevel: offlineLevel,
        );
      }
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
          offlineLevel: offlineLevel,
        );
      } catch (error) {
        if (!repetible) rethrow;
        debugPrint(
          'No se pudo iniciar online; usando nivel descargado: $error',
        );
        return await _pushGame(
          nivel: offlineLevel.nivel,
          gameId: 'offline-${DateTime.now().microsecondsSinceEpoch}',
          numeroVisible: numeroVisible,
          haySiguiente: haySiguiente,
          reemplazar: reemplazar,
          offlineLevel: offlineLevel,
        );
      }
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
    required OfflineLevelData? offlineLevel,
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
        offlineLevel: offlineLevel,
        offlineMode: _offlineMode || gameId.startsWith('offline-'),
        onOfflineCompleted: (levelId, answer) async {
          final snapshot = _offlineSnapshot;
          if (snapshot == null) {
            throw StateError('No existe progreso offline para sincronizar');
          }
          final updated = snapshot.completedLocally(levelId, answer);
          await _offlineStore.save(updated);
          _offlineSnapshot = updated;
        },
      ),
    );
    if (reemplazar) {
      unawaited(navigator.pushReplacement(route));
    } else {
      unawaited(navigator.push(route));
    }
    final resultado = await Future.any([route.popped, siguiente.future]);
    // Ganado con conexión: se baja en segundo plano para repetirlo offline.
    if (resultado != null && !gameId.startsWith('offline-')) {
      _paquete = _paquete.then((_) => _actualizarPaquete(nivel.id));
    }
    if (resultado != null) {
      final antes = _desbloqueadas();
      final terminadoAntes = _juegoTerminado();
      final introsAntes = _introsDisponibles;
      // Las insignias esperan a que salgan estos avisos.
      _avisando = true;
      await _cargar();
      if (!introsAntes && _introsDisponibles && mounted) {
        await _avisarIntros();
      }
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
      icon: const Icon(Icons.workspace_premium_rounded, size: 56),
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

  Future<void> _avisarIntros() => showDialog<void>(
    context: context,
    builder: (context) => LiquidGlassDialog(
      icon: const Icon(Icons.headphones_rounded, size: 48),
      title: const Text(
        '¡Desbloqueaste Adivina la intro!',
        textAlign: TextAlign.center,
      ),
      content: const Text(
        'Cada canción que adivines te da monedas: Fácil 2, Media 3 y '
        'Avanzada 4. Úsalas en el menú principal para sacar cartas con intros.',
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
        icon: const Icon(Icons.emoji_events_rounded, size: 48),
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
    final niveles = _offlineMode && _offlineSnapshot != null
        ? _offlineSnapshot!.levels
              .where((item) => item.nivel.dificultad == dificultad)
              .map(
                (item) => NivelAsignado(
                  nivel: item.nivel,
                  completado: item.completado,
                  puedeIniciar: item.puedeIniciar,
                ),
              )
              .toList(growable: false)
        : nivelesRemotos;
    return niveles;
  }

  /// Intros del jugador: del servidor o, sin conexión, de la copia guardada.
  Future<EstadoIntros?> _estadoIntros() async {
    if (!_introsDisponibles) return null;
    try {
      return await ref
          .read(firebaseGameRepositoryProvider)
          .cargarIntros()
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return (await ref.read(offlineIntroStoreProvider).load(widget.user.uid))
          ?.estado;
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

  Future<void> _reiniciarProgreso() async {
    final listo = await _reiniciarCuenta(
      context,
      ref,
      alEmpezar: () {
        if (mounted) {
          setState(() {
            _pestana = 0;
            _loading = true;
          });
        }
      },
    );
    if (!mounted) return;
    if (listo) {
      setState(() {
        _offlineSnapshot = null;
        _resumenIntros = null;
        _monedas = null;
        _seleccionada = null;
      });
    }
    // También si falló a medias: se vuelve a cargar lo que haya.
    if (_loading) await _cargar();
  }

  Future<void> _cerrarSesion() => _cerrarSesionDe(context, ref, widget.user);

  @override
  Widget build(BuildContext context) {
    final estado = _estado;
    // El fondo cubre también la barra para que el vidrio tenga qué mostrar.
    return Theme(
      data: temaGenero(context, widget.genero),
      child: LiquidBackground(
        acento: switch (_pestana) {
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
              centerTitle: false,
              leading: _pestana == _pCancion && _nivelesAbiertos
                  ? IconButton(
                      tooltip: 'Volver a las dificultades',
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: _cerrarNiveles,
                    )
                  : null,
              title: _tituloBarra(estado),
              actions: [..._accionesBarra(), const SizedBox(width: 8)],
            ),
            bottomNavigationBar: LiquidGlassBottomNav(
              colorMenu: paletaGenero(widget.genero).barraMenu,
              colorSecciones: paletaGenero(widget.genero).barraSecciones,
              claves: _clavesPestanas,
              currentIndex: _pestana,
              onTap: _cambiarPestana,
              items: const [
                (icon: Icons.home_rounded, label: 'Menú'),
                (icon: Icons.music_note_rounded, label: 'Canción'),
                (icon: Icons.headphones_rounded, label: 'Intro'),
                (icon: Icons.insights_rounded, label: 'Progreso'),
                (icon: Icons.settings_rounded, label: 'Ajustes'),
              ],
            ),
            body: TransicionMusical(
              pestana: _pestana,
              direccion: _direccion,
              color: switch (_pestana) {
                0 => colorGenero(widget.genero),
                _pCancion when estado != null => colorDificultad(
                  _seleccionada ?? estado.dificultadActiva,
                ),
                _ => paletaGenero(widget.genero).intro,
              },
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
                _pAjustes => _PestanaConfiguracion(
                  key: const ValueKey('configuracion'),
                  onRecorrido: _verRecorrido,
                  onCerrarSesion: _cerrarSesion,
                  onReiniciar: widget.user.isAnonymous
                      ? null
                      : _reiniciarProgreso,
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
    _ => // Solo el logo, a la izquierda; ya dice RIFF.
    Image.asset(
      'lib/assets/images/logo/riff_logo.png',
      height: 56,
      semanticLabel: 'RIFF',
    ),
  };

  /// Monedas 🪙 en Intro y Progreso; fichas 🎟️ en Salas y Progreso.
  List<Widget> _accionesBarra() => [
    // Desde el menú se vuelve a la selección de género (Ajustes está abajo).
    if (_pestana == 0)
      IconButton(
        tooltip: 'Elegir género',
        icon: const Icon(Icons.apps_rounded),
        onPressed: widget.onCambiarGenero,
      ),
    if ((_pestana == _pIntro || _pestana == _pProgreso) && _monedas != null)
      _Saldo('🪙', _monedas!, 'monedas'),
  ];

  void _cambiarPestana(int pestana) {
    setState(() {
      // Sentido de la onda de la transición: hacia la pestaña nueva.
      _direccion = pestana == _pestana ? 0 : (pestana > _pestana ? 1 : -1);
      _pestana = pestana;
      _nivelesAbiertos = false;
      _direccionNiveles = 0;
      // Progreso se vuelve a pedir al abrir la pestaña, para que esté al día.
      if (pestana == _pProgreso) {
        _introsFuturo = _estadoIntros()
          ..then((intros) {
            if (mounted && intros != null) {
              setState(() {
                _monedas = intros.monedas;
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
      introsDisponibles: _introsDisponibles,
      offlineMode: _offlineMode,
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
    if (!_introsDisponibles) {
      return _bloqueada(
        'intro-bloqueada',
        'Adivina la intro se desbloquea al completar tu primer nivel de '
            'Adivina la canción.',
      );
    }
    return IntrosScreen(
      key: const ValueKey('intro'),
      embebida: true,
      onEstado: (intros) {
        setState(() {
          _monedas = intros.monedas;
          _resumenIntros = intros;
        });
        _revisarInsignias();
      },
    );
  }

  Widget _bloqueada(String clave, String motivo) => Center(
    key: ValueKey(clave),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, size: 40),
            const SizedBox(height: 12),
            Text(motivo, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );

  void _cerrarNiveles() => setState(() {
    _nivelesAbiertos = false;
    _direccionNiveles = -1;
  });

  Widget _pestanaCancion(EstadoJuegoRemoto? estado) {
    if (_esperandoProgreso() case final espera?) return espera;
    return _PanelDificultades(
      key: _claveDificultades,
      estado: estado!,
      seleccionada: _seleccionada ?? estado.dificultadActiva,
      esInvitado: widget.user.isAnonymous,
      offlineMode: _offlineMode,
      nivelesDe: _nivelesDe,
      abierta: _nivelesAbiertos,
      onCambio: (dificultad) => setState(() => _seleccionada = dificultad),
      direccion: _direccionNiveles,
      onAbrir: (dificultad) => setState(() {
        _seleccionada = dificultad;
        _nivelesAbiertos = true;
        _direccionNiveles = 1;
      }),
      onJugar: _jugar,
      onRefresh: _cargar,
    );
  }
}

/// Avance del jugador para calcular las insignias.
AvanceJuego _avanceDe(
  List<ProgresoDificultadRemoto> dificultades,
  EstadoIntros? intros,
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
    nivelesPorDificultad: _ProgresoGeneral._nivelesPorDificultad,
    introsAdivinadas:
        intros?.intros
            .where((item) => item.estado == EstadoIntro.completada)
            .length ??
        0,
    totalIntros: intros == null
        ? _ProgresoGeneral._totalIntros
        : intros.intros.length + intros.restantes,
    unInstrumento: dificultades.fold(
      0,
      (total, item) => total + item.unInstrumento,
    ),
  );
}

/// Pestaña Progreso: avance de niveles e intros, estadísticas de salas e
/// insignias.
/// Progreso general (desde el selector de géneros): avance de cada género
/// disponible, las salas (que son de todos los géneros) y las insignias
/// generales. Mismo carrusel que la pestaña Progreso de cada género.
class _ProgresoTodo extends StatelessWidget {
  const _ProgresoTodo({
    required this.datos,
    required this.saldo,
    required this.esInvitado,
  });

  final Map<Genero, ({EstadoJuegoRemoto estado, EstadoIntros? intros})> datos;
  final SaldoSalas saldo;
  final bool esInvitado;

  static const _colores = [AppColors.oro, azulLogin, colorAleatorio];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final avances = [
      for (final d in datos.values) _avanceDe(d.estado.dificultades, d.intros),
    ];
    final logros = logrosGenerales(saldo, avances);
    // Niveles cargados de verdad (un género en preparación suma 0) e intros.
    var hechos = 0, total = 0;
    final filas = <Widget>[];
    for (final MapEntry(key: genero, value: d) in datos.entries) {
      final niveles = d.estado.dificultades.fold(
        0,
        (s, x) => s + x.completados,
      );
      final totalNiveles = d.estado.dificultades.fold(0, (s, x) => s + x.total);
      final intros = d.intros;
      final adivinadas =
          intros?.intros
              .where((i) => i.estado == EstadoIntro.completada)
              .length ??
          0;
      final totalIntros = intros == null
          ? _ProgresoGeneral._totalIntros
          : intros.intros.length + intros.restantes;
      hechos += niveles + adivinadas;
      total += totalNiveles + totalIntros;
      filas.add(
        _ProgresoGeneral._fila(
          context,
          nombre: genero.nombre,
          hechos: niveles + adivinadas,
          total: totalNiveles + totalIntros,
          color: colorGenero(genero),
          detalle: totalNiveles == 0
              ? '$adivinadas de $totalIntros intros · niveles en preparación'
              : '$niveles de $totalNiveles niveles · '
                    '$adivinadas de $totalIntros intros',
        ),
      );
    }
    final porcentaje = total == 0 ? 0.0 : hechos / total;
    Widget tarjeta(int index, bool alFrente) => switch (index) {
      0 => _CuadroProgreso(
        color: _colores[0],
        alFrente: alFrente,
        onTap: null,
        children: [
          _tituloTarjeta(context, '📈 Progreso general', _colores[0]),
          const SizedBox(height: 8),
          Text(
            '${(porcentaje * 100).round()}%',
            textAlign: TextAlign.center,
            style: text.displaySmall?.copyWith(
              color: context.paleta.tonoTexto(_colores[0]),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: porcentaje,
              minHeight: 12,
              color: _colores[0],
            ),
          ),
          const SizedBox(height: 20),
          if (filas.isEmpty)
            const Center(child: CircularProgressIndicator())
          else
            ...filas,
        ],
      ),
      1 => _ResumenSalas(
        saldo: saldo,
        esInvitado: esInvitado,
        color: _colores[1],
        alFrente: alFrente,
      ),
      _ => _ResumenInsignias(
        logros: logros,
        color: _colores[2],
        alFrente: alFrente,
        onTap: () => _PestanaProgreso._verDetalle(
          context,
          'Insignias generales',
          () => _GrillaInsignias(logros: logros),
        ),
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: CarruselGiratorio(
        itemCount: _colores.length,
        compacto: true,
        proporcion: 1.45,
        colorDe: (index) => _colores[index],
        itemBuilder: (context, index, alFrente) => ConReflejo(
          color: _colores[index],
          tarjeta: tarjeta(index, alFrente),
          reflejo: tarjeta(index, false),
        ),
      ),
    );
  }
}

class _PestanaProgreso extends StatelessWidget {
  const _PestanaProgreso({
    super.key,
    required this.dificultades,
    required this.intros,
    required this.saldo,
    required this.esInvitado,
  });

  final List<ProgresoDificultadRemoto> dificultades;
  final Future<EstadoIntros?>? intros;
  final SaldoSalas saldo;
  final bool esInvitado;

  // Colores del género que se está jugando (las pestañas son de su menú).
  List<Color> get _colores => [
    paletaGenero(generoActivo).progreso,
    paletaGenero(generoActivo).mancha1,
    colorGenero(generoActivo),
  ];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EstadoIntros?>(
      future: intros,
      builder: (context, snapshot) {
        final estadoIntros = snapshot.data;
        final cargando = snapshot.connectionState != ConnectionState.done;
        final logros = logrosDe(
          saldo,
          _avanceDe(dificultades, estadoIntros),
          generoActivo,
        );
        // Progreso y Salas muestran todo en la tarjeta; Insignias abre una
        // hoja con todas al tocarla.
        Widget tarjeta(int index, bool alFrente) => switch (index) {
          0 => _CuadroProgreso(
            color: _colores[0],
            alFrente: alFrente,
            onTap: null,
            children: [
              _tituloTarjeta(context, '📈 Progreso', _colores[0]),
              const SizedBox(height: 8),
              _ProgresoGeneral(
                dificultades: dificultades,
                intros: estadoIntros,
                cargandoIntros: cargando,
              ),
            ],
          ),
          1 => _ResumenSalas(
            saldo: saldo,
            esInvitado: esInvitado,
            color: _colores[1],
            alFrente: alFrente,
          ),
          _ => _ResumenInsignias(
            logros: logros,
            color: _colores[2],
            alFrente: alFrente,
            onTap: () => _verDetalle(
              context,
              'Insignias',
              () => _GrillaInsignias(logros: logros),
            ),
          ),
        };
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CarruselGiratorio(
            itemCount: _colores.length,
            // Como el menú principal: más pequeñas, con reflejo y las otras
            // asomando detrás.
            compacto: true,
            // Algo más altas que las del menú: Progreso y Salas traen todo.
            proporcion: 1.45,
            colorDe: (index) => _colores[index],
            itemBuilder: (context, index, alFrente) => ConReflejo(
              color: _colores[index],
              tarjeta: tarjeta(index, alFrente),
              // La copia del reflejo va sin desenfoque.
              reflejo: tarjeta(index, false),
            ),
          ),
        );
      },
    );
  }

  static void _verDetalle(
    BuildContext context,
    String titulo,
    Widget Function() contenido,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.paleta.fondo,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, desplazamiento) => ListView(
        controller: desplazamiento,
        padding: EdgeInsets.symmetric(
          horizontal: max(16, (MediaQuery.sizeOf(context).width - 680) / 2),
          vertical: 16,
        ),
        children: [
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          contenido(),
        ],
      ),
    ),
  );
}

/// Tarjeta del carrusel de Progreso: vidrio de color, toda tocable y con el
/// contenido encogido si no cabe (letra grande, pantallas bajas).
class _CuadroProgreso extends StatelessWidget {
  const _CuadroProgreso({
    required this.color,
    required this.alFrente,
    required this.onTap,
    required this.children,
  });

  final Color color;
  final bool alFrente;
  final VoidCallback? onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LiquidGlassCard(
    borderRadius: 28,
    tintColor: color,
    borderColor: alFrente ? color : null,
    // Las laterales solo se ven al girar: sin desenfoque, que es caro.
    blur: alFrente ? LiquidGlass.glassBlur : 0,
    child: LiquidRippleEffect(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: 280,
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        ),
      ),
    ),
  );
}

/// "Toca para ver más" al pie de las tarjetas de Progreso.
Widget _verMas(BuildContext context, Color color) {
  final tono = context.paleta.tonoTexto(color);
  return Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Ver detalle',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: tono),
        ),
        Icon(Icons.chevron_right_rounded, color: tono),
      ],
    ),
  );
}

/// Título de una tarjeta de Progreso, del color de la tarjeta.
Widget _tituloTarjeta(BuildContext context, String titulo, Color color) => Text(
  titulo,
  textAlign: TextAlign.center,
  style: Theme.of(
    context,
  ).textTheme.headlineSmall?.copyWith(color: context.paleta.tonoTexto(color)),
);

/// Salas: las seis estadísticas a la vista.
class _ResumenSalas extends StatelessWidget {
  const _ResumenSalas({
    required this.saldo,
    required this.esInvitado,
    required this.color,
    required this.alFrente,
  });

  final SaldoSalas saldo;
  final bool esInvitado;
  final Color color;
  final bool alFrente;

  @override
  Widget build(BuildContext context) => _CuadroProgreso(
    color: color,
    alFrente: alFrente,
    onTap: null,
    children: [
      _tituloTarjeta(context, '👥 Salas', color),
      const SizedBox(height: 16),
      if (esInvitado)
        Text(
          'Crea una cuenta para jugar en salas y ver tus estadísticas.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.paleta.tintaSuave),
        )
      else
        _EstadisticasSalas(saldo: saldo),
    ],
  );
}

List<_Dato> _datosSalas(SaldoSalas saldo) => [
  _Dato('🎮', '${saldo.jugadas}', 'Jugadas'),
  _Dato('🏆', '${saldo.ganadas}', 'Ganadas'),
  _Dato('😔', '${saldo.derrotas}', 'Derrotas'),
  _Dato('📊', '${(saldo.porcentajeVictorias * 100).round()}%', 'Victorias'),
  _Dato('🏅', '${saldo.podios}', 'Podios'),
  _Dato('🎟️', '${saldo.fichasGanadas}', 'Fichas ganadas'),
];

/// Insignias conseguidas como etiquetas del color de su dificultad, igual que
/// los niveles completados; las pendientes se ven en el detalle.
class _ResumenInsignias extends StatelessWidget {
  const _ResumenInsignias({
    required this.logros,
    required this.color,
    required this.alFrente,
    required this.onTap,
  });

  final List<Logro> logros;
  final Color color;
  final bool alFrente;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final conseguidas = logros.where((logro) => logro.logrado).toList();
    return _CuadroProgreso(
      color: color,
      alFrente: alFrente,
      onTap: onTap,
      children: [
        Text(
          '🏅 Insignias',
          style: text.headlineSmall?.copyWith(
            color: context.paleta.tonoTexto(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${conseguidas.length} de ${logros.length}',
          style: text.bodyMedium?.copyWith(color: context.paleta.tintaSuave),
        ),
        const SizedBox(height: 12),
        if (conseguidas.isEmpty)
          Text(
            'Aún no tienes insignias. ¡Toca para ver cómo ganarlas!',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: context.paleta.tintaSuave),
          )
        else
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final logro in conseguidas) _EtiquetaInsignia(logro: logro),
            ],
          ),
        _verMas(context, color),
      ],
    );
  }
}

/// Nombre de una insignia en una píldora de su color (dorada Vallenatólogo).
class _EtiquetaInsignia extends StatelessWidget {
  const _EtiquetaInsignia({required this.logro});

  final Logro logro;

  @override
  Widget build(BuildContext context) {
    final color = logro.dorada ? AppColors.oro : colorInsignia(logro.nivel);
    final tono = context.paleta.tonoTexto(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color, width: logro.dorada ? 2 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(logro.emoji),
          const SizedBox(width: 4),
          Text(
            logro.nombre,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: tono,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.check_circle_rounded, size: 16, color: tono),
        ],
      ),
    );
  }
}

/// Todas las estadísticas de salas: dos filas de tres datos.
class _EstadisticasSalas extends StatelessWidget {
  const _EstadisticasSalas({required this.saldo});

  final SaldoSalas saldo;

  @override
  Widget build(BuildContext context) {
    final datos = _datosSalas(saldo);
    return Column(
      children: [
        for (final fila in [datos.sublist(0, 3), datos.sublist(3)])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, dato) in fila.indexed) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: dato),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Todas las insignias, conseguidas o no, del mismo tamaño.
class _GrillaInsignias extends StatelessWidget {
  const _GrillaInsignias({required this.logros});

  final List<Logro> logros;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, espacio) {
      // Dos por fila en teléfonos, más en tablets.
      final columnas = max(2, (espacio.maxWidth / 200).floor());
      final ancho = (espacio.maxWidth - 10 * (columnas - 1)) / columnas;
      // Todas del mismo alto: cabe nombre en 2 líneas y condición en 4;
      // crece con la letra del sistema.
      final alto = MediaQuery.textScalerOf(context).scale(224);
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final logro in logros)
            SizedBox(
              width: ancho,
              height: alto,
              child: TarjetaLogro(logro: logro),
            ),
        ],
      );
    },
  );
}

/// Un número de las estadísticas de salas con su emoji y nombre.
class _Dato extends StatelessWidget {
  const _Dato(this.emoji, this.valor, this.nombre);

  final String emoji;
  final String valor;
  final String nombre;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: context.paleta.superficie.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.paleta.borde),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          Text(valor, style: text.titleLarge),
          Text(
            nombre,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: context.paleta.tintaSuave),
          ),
        ],
      ),
    );
  }
}

/// Insignia con el color de su dificultad: llena si se consiguió; si no,
/// apagada con su avance. Vallenatólogo conseguida va en dorado.
@visibleForTesting
class TarjetaLogro extends StatelessWidget {
  const TarjetaLogro({super.key, required this.logro});

  final Logro logro;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hecho = logro.logrado;
    final color = colorInsignia(logro.nivel);
    final dorada = hecho && logro.dorada;
    return Semantics(
      label:
          '${logro.nombre}: ${hecho ? 'conseguida' : 'pendiente, '
                    '${min(logro.actual, logro.meta)} de ${logro.meta}'}. '
          '${logro.condicion}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hecho
              ? color.withValues(alpha: 0.22)
              : context.paleta.superficie.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: dorada
                ? AppColors.oro
                : hecho
                ? color
                : color.withValues(alpha: 0.45),
            width: dorada ? 3 : (hecho ? 2 : 1),
          ),
        ),
        child: Column(
          children: [
            Opacity(
              opacity: hecho ? 1 : 0.35,
              child: Text(logro.emoji, style: const TextStyle(fontSize: 34)),
            ),
            const SizedBox(height: 4),
            Text(
              logro.nombre,
              textAlign: TextAlign.center,
              style: dorada
                  ? text.titleSmall?.copyWith(
                      color: context.paleta.tonoTexto(AppColors.oro),
                      fontWeight: FontWeight.w800,
                    )
                  : text.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              logro.condicion,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: context.paleta.tintaSuave),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            // El avance queda abajo en todas, aunque el texto sea corto.
            const Spacer(),
            const SizedBox(height: 8),
            if (hecho)
              Text(
                '✅ Conseguida',
                style: text.labelMedium?.copyWith(
                  color: context.paleta.tonoTexto(color),
                  fontWeight: FontWeight.w800,
                ),
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: logro.meta == 0
                      ? 0
                      : min(logro.actual, logro.meta) / logro.meta,
                  minHeight: 5,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${min(logro.actual, logro.meta)}/${logro.meta}',
                style: text.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pestaña Configuración: instrucciones, música del menú, tema y sesión.
/// Saldo en la barra de arriba: emoji y número en una píldora.
class _Saldo extends StatelessWidget {
  const _Saldo(this.emoji, this.valor, this.nombre);

  final String emoji;
  final int valor;
  final String nombre;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: Semantics(
      label: '$valor $nombre',
      excludeSemantics: true,
      child: Chip(
        visualDensity: VisualDensity.compact,
        avatar: Text(emoji),
        label: Text('$valor'),
      ),
    ),
  );
}

class _PestanaConfiguracion extends ConsumerStatefulWidget {
  const _PestanaConfiguracion({
    super.key,
    this.onRecorrido,
    required this.onCerrarSesion,
    this.onReiniciar,
  });

  // null fuera de un género: el recorrido explica el menú del género.
  final VoidCallback? onRecorrido;
  final VoidCallback onCerrarSesion;
  // null para invitados: su progreso ya se borra al salir.
  final VoidCallback? onReiniciar;

  @override
  ConsumerState<_PestanaConfiguracion> createState() =>
      _PestanaConfiguracionState();
}

class _PestanaConfiguracionState extends ConsumerState<_PestanaConfiguracion> {
  @override
  Widget build(BuildContext context) {
    final musica = ref.read(musicaMenuProvider);
    final oscuro = context.paleta.oscuro;
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: max(16, (MediaQuery.sizeOf(context).width - 680) / 2),
        vertical: 16,
      ),
      children: [
        LiquidGlassCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.menu_book_rounded),
                title: const Text('Instrucciones'),
                subtitle: const Text('Cómo se juega cada modo'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => mostrarInstrucciones(context),
              ),
              if (widget.onRecorrido != null)
                ListTile(
                  leading: const Icon(Icons.tour_rounded),
                  title: const Text('Recorrido guiado'),
                  subtitle: const Text('Las burbujas que explican la app'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: widget.onRecorrido,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LiquidGlassCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              SwitchListTile(
                secondary: Icon(
                  musica.silenciada
                      ? Icons.music_off_rounded
                      : Icons.music_note_rounded,
                ),
                title: const Text('Música del menú'),
                value: !musica.silenciada,
                onChanged: (_) async {
                  await musica.alternarSilencio();
                  if (mounted) setState(() {});
                },
              ),
              SwitchListTile(
                secondary: Icon(
                  oscuro ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                ),
                title: const Text('Modo oscuro'),
                value: oscuro,
                onChanged: (valor) => ref
                    .read(modoTemaProvider.notifier)
                    .cambiar(valor ? ThemeMode.dark : ThemeMode.light),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (widget.onReiniciar case final reiniciar?) ...[
          LiquidGlassCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: Icon(
                Icons.restart_alt_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Reiniciar progreso',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              subtitle: const Text('Empezar el juego desde cero'),
              onTap: reiniciar,
            ),
          ),
          const SizedBox(height: 16),
        ],
        LiquidGlassCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: Icon(
              Icons.logout_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Cerrar sesión',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: widget.onCerrarSesion,
          ),
        ),
      ],
    );
  }
}

/// Progreso: arriba el general (niveles de las tres dificultades más las
/// intros adivinadas) y debajo cada dificultad y las intros por separado.
class _ProgresoGeneral extends StatelessWidget {
  const _ProgresoGeneral({
    required this.dificultades,
    required this.intros,
    required this.cargandoIntros,
  });

  // Niveles por dificultad y total de intros publicadas. shortcut: si cambian
  // en el servidor hay que actualizarlos aquí; las bloqueadas llegan con 0.
  static const _nivelesPorDificultad = 5;
  static const _totalIntros = 45;

  final List<ProgresoDificultadRemoto> dificultades;
  final EstadoIntros? intros;
  final bool cargandoIntros;

  /// Avance total del juego (niveles más intros adivinadas), de 0 a 1.
  static double porcentajeDe(
    List<ProgresoDificultadRemoto> dificultades,
    EstadoIntros? intros,
  ) {
    final totalNiveles = dificultades.length * _nivelesPorDificultad;
    final niveles = dificultades.fold<int>(
      0,
      (sum, item) => sum + item.completados,
    );
    final totalIntros = intros == null
        ? _totalIntros
        : intros.intros.length + intros.restantes;
    final adivinadas =
        intros?.intros
            .where((item) => item.estado == EstadoIntro.completada)
            .length ??
        0;
    final total = totalNiveles + totalIntros;
    return total == 0 ? 0.0 : (niveles + adivinadas) / total;
  }

  static Widget _fila(
    BuildContext context, {
    required String nombre,
    required int hechos,
    required int total,
    required Color color,
    String? detalle,
  }) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(nombre, style: text.titleSmall)),
              Text('$hechos/$total', style: text.bodySmall),
            ],
          ),
          if (detalle != null)
            Text(
              detalle,
              style: text.bodySmall?.copyWith(color: context.paleta.tintaSuave),
            ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : hechos / total,
              minHeight: 6,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final totalNiveles = dificultades.length * _nivelesPorDificultad;
    final niveles = dificultades.fold<int>(
      0,
      (sum, item) => sum + item.completados,
    );
    final intros = this.intros;
    final totalIntros = intros == null
        ? _totalIntros
        : intros.intros.length + intros.restantes;
    final adivinadas =
        intros?.intros
            .where((item) => item.estado == EstadoIntro.completada)
            .length ??
        0;
    final porcentaje = porcentajeDe(dificultades, intros);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${(porcentaje * 100).round()}%',
          textAlign: TextAlign.center,
          // Color del género, del tema de su menú.
          style: text.displaySmall,
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(value: porcentaje, minHeight: 12),
        ),
        const SizedBox(height: 8),
        Text(
          '$niveles de $totalNiveles niveles · $adivinadas de $totalIntros intros',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: context.paleta.tintaSuave),
        ),
        const SizedBox(height: 20),
        for (final item in dificultades)
          _fila(
            context,
            nombre: _nombreDificultad(item.dificultad),
            hechos: item.completados,
            total: max(item.total, _nivelesPorDificultad),
            color: colorDificultad(item.dificultad),
          ),
        cargandoIntros
            ? const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 6),
              )
            : _fila(
                context,
                nombre: 'Adivina la intro',
                hechos: adivinadas,
                total: totalIntros,
                color: paletaGenero(generoActivo).intro,
                detalle: intros == null
                    ? 'Se desbloquea al completar tu primer nivel.'
                    : '${intros.intros.length} cartas obtenidas',
              ),
      ],
    );
  }
}

/// Menú del género: carrusel de los dos modos y el progreso que gira solo de
/// izquierda a derecha (se pausa al tocarlo).
class _MenuPrincipal extends StatelessWidget {
  const _MenuPrincipal({
    super.key,
    required this.genero,
    required this.claveCarrusel,
    required this.onVisible,
    required this.introsDisponibles,
    required this.offlineMode,
    required this.infoCancion,
    required this.infoIntros,
    required this.onInstrumentos,
    required this.onIntros,
    required this.onProgreso,
    this.infoProgreso,
  });

  // Color e instrumentos de la tarjeta "Adivina la canción".
  final Genero genero;
  final GlobalKey claveCarrusel;
  // Una línea de datos del jugador en cada tarjeta (null si no hay).
  final String infoCancion;
  final String? infoIntros;
  // Avisa cuando el menú ya está en pantalla (para el recorrido inicial).
  final VoidCallback onVisible;
  final bool introsDisponibles;
  final bool offlineMode;
  final VoidCallback onInstrumentos;
  final VoidCallback onIntros;
  final VoidCallback onProgreso;
  final String? infoProgreso;

  List<Color> get _colores => [
    colorGenero(genero),
    paletaGenero(genero).intro,
    paletaGenero(genero).progreso,
  ];

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => onVisible());
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: CarruselGiratorio(
        key: claveCarrusel,
        itemCount: _colores.length,
        autoGiro: const Duration(seconds: 5),
        // Más pequeñas y con las otras dos asomando detrás.
        compacto: true,
        proporcion: 1.25,
        colorDe: (index) => _colores[index],
        itemBuilder: (context, index, alFrente) => ConReflejo(
          color: _colores[index],
          tarjeta: _cuadro(index, alFrente),
          // La copia del reflejo va sin desenfoque: es lo más caro de pintar.
          reflejo: _cuadro(index, false, animar: false),
        ),
      ),
    );
  }

  Widget _cuadro(int index, bool alFrente, {bool animar = true}) {
    final introsBloqueadas = !introsDisponibles;
    return switch (index) {
      0 => _CuadroModo(
        emoji: genero.instrumentos,
        animacion: _Animacion.tocar,
        titulo: 'Adivina la canción',
        detalle: 'Compra instrumentos y descubre la canción.',
        info: infoCancion,
        color: colorGenero(genero),
        alFrente: alFrente,
        // Solo la del frente se mueve; laterales y reflejo, quietas.
        animar: animar && alFrente,
        onTap: onInstrumentos,
      ),
      1 => _CuadroModo(
        emoji: '🎧',
        animacion: _Animacion.mecer,
        titulo: 'Adivina la intro',
        detalle: !introsDisponibles
            ? 'Se desbloquea al completar tu primer nivel.'
            : offlineMode
            ? 'Sin conexión: escucha las intros que adivinaste.'
            : 'Escucha 30 segundos y adivina la canción.',
        info: introsBloqueadas ? null : infoIntros,
        color: paletaGenero(genero).intro,
        alFrente: alFrente,
        // Solo la del frente se mueve; laterales y reflejo, quietas.
        animar: animar && alFrente,
        bloqueado: introsBloqueadas,
        onTap: introsBloqueadas ? null : onIntros,
      ),
      _ => _CuadroModo(
        emoji: '📈',
        animacion: _Animacion.saltar,
        titulo: 'Progreso',
        detalle: 'Tus niveles, intros e insignias.',
        info: infoProgreso,
        color: paletaGenero(genero).progreso,
        alFrente: alFrente,
        // Solo la del frente se mueve; laterales y reflejo, quietas.
        animar: animar && alFrente,
        onTap: onProgreso,
      ),
    };
  }
}

class _CuadroModo extends StatelessWidget {
  const _CuadroModo({
    required this.emoji,
    required this.animacion,
    required this.titulo,
    required this.detalle,
    required this.color,
    required this.onTap,
    this.info,
    this.alFrente = true,
    this.bloqueado = false,
    this.animar = true,
  });

  final String emoji;
  final _Animacion animacion;
  final String titulo;
  final String detalle;
  final Color color;
  final VoidCallback? onTap;
  // Dato del jugador (nivel, intros, salas ganadas) bajo la descripción.
  final String? info;
  final bool alFrente;
  final bool bloqueado;
  final bool animar;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LiquidGlassCard(
      borderRadius: 28,
      opacity: bloqueado ? 0.35 : 0.6,
      // Las laterales solo se ven al girar: sin desenfoque, que es caro.
      blur: alFrente ? LiquidGlass.glassBlur : 0,
      borderColor: alFrente && !bloqueado ? color : null,
      tintColor: bloqueado ? null : color,
      child: LiquidRippleEffect(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: bloqueado ? 0.4 : 1,
                      child: _EmojiAnimado(
                        emoji: emoji,
                        animacion: animacion,
                        // Bloqueado se queda quieto: no invita a tocarlo.
                        activo: !bloqueado && animar,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      style: text.headlineSmall?.copyWith(
                        color: bloqueado
                            ? context.paleta.tintaSuave
                            : context.paleta.tonoTexto(color),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (bloqueado) ...[
                          Icon(
                            Icons.lock_rounded,
                            size: 18,
                            color: context.paleta.tintaSuave,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            detalle,
                            textAlign: TextAlign.center,
                            style: text.bodyMedium?.copyWith(
                              color: context.paleta.tintaSuave,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (info case final dato?) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: color.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          dato,
                          textAlign: TextAlign.center,
                          style: text.labelLarge?.copyWith(
                            color: context.paleta.tonoTexto(color),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Animacion { tocar, saltar, mecer }

/// Emojis de las tarjetas del menú en movimiento: los instrumentos se mecen
/// por turnos como si tocaran, la copa salta y los audífonos se balancean.
class _EmojiAnimado extends StatefulWidget {
  const _EmojiAnimado({
    required this.emoji,
    required this.animacion,
    required this.activo,
  });

  final String emoji;
  final _Animacion animacion;
  final bool activo;

  @override
  State<_EmojiAnimado> createState() => _EmojiAnimadoState();
}

class _EmojiAnimadoState extends State<_EmojiAnimado> {
  final _ciclo = CicloLento(periodo: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _actualizar();
  }

  @override
  void didUpdateWidget(_EmojiAnimado oldWidget) {
    super.didUpdateWidget(oldWidget);
    _actualizar();
  }

  // Quieto si está bloqueado, con "reducir movimiento" o con la pantalla
  // tapada por otra.
  void _actualizar() => _ciclo.activo =
      widget.activo &&
      !MediaQuery.disableAnimationsOf(context) &&
      TickerMode.valuesOf(context).enabled;

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emojis = widget.emoji.characters.toList();
    // Capa propia: el rebote no repinta la tarjeta de vidrio ni su sombra.
    return RepaintBoundary(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _ciclo,
          builder: (context, _) {
            final t = _ciclo.value * 2 * pi;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, emoji) in emojis.indexed)
                  Transform.translate(
                    offset: Offset(0, switch (widget.animacion) {
                      // Cada instrumento rebota desfasado, como una banda.
                      _Animacion.tocar => -sin(t + i * 2).abs() * 6,
                      _Animacion.saltar => -sin(t).abs() * 10,
                      _Animacion.mecer => 0,
                    }),
                    child: Transform.rotate(
                      angle: switch (widget.animacion) {
                        _Animacion.tocar => sin(t + i * 2) * 0.15,
                        _Animacion.saltar => sin(t * 2) * 0.05,
                        _Animacion.mecer => sin(t) * 0.25,
                      },
                      child: Transform.scale(
                        scale: widget.animacion == _Animacion.saltar
                            ? 1 + sin(t).abs() * 0.08
                            : 1,
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 48),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PanelDificultades extends StatelessWidget {
  const _PanelDificultades({
    super.key,
    required this.estado,
    required this.seleccionada,
    required this.nivelesDe,
    required this.esInvitado,
    required this.offlineMode,
    required this.abierta,
    required this.direccion,
    required this.onCambio,
    required this.onAbrir,
    required this.onJugar,
    required this.onRefresh,
  });

  final EstadoJuegoRemoto estado;
  final bool abierta;
  // 1 al abrir los niveles, -1 al volver, 0 sin animación.
  final int direccion;
  final ValueChanged<Dificultad> onAbrir;
  final Dificultad seleccionada;
  final List<NivelAsignado> Function(Dificultad) nivelesDe;
  final bool esInvitado;
  final bool offlineMode;
  final ValueChanged<Dificultad> onCambio;
  final void Function(Dificultad dificultad, int index) onJugar;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final aviso = offlineMode
        ? 'Sin conexión: juegas con los niveles descargados; el progreso se '
              'sincronizará al reconectarte.'
        : null;
    final dificultades = estado.dificultades;
    return Column(
      children: [
        if (aviso != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              aviso,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.paleta.tintaSuave),
            ),
          ),
        Expanded(
          child: SafeArea(
            top: false,
            // Con el aviso de invitado debajo, el margen inferior lo pone él.
            bottom: !esInvitado,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              // Como al cambiar de pestaña: los niveles entran deslizándose y
              // creciendo; al volver se deshacen en polvo.
              child: TransicionMusical(
                pestana: abierta ? 1 : 0,
                direccion: direccion,
                color: colorDificultad(seleccionada),
                child: KeyedSubtree(
                  key: ValueKey(abierta),
                  child: abierta ? _niveles() : _carrusel(dificultades),
                ),
              ),
            ),
          ),
        ),
        // Solo los invitados ven el aviso; correo y Google no muestran nada.
        if (esInvitado)
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Modo invitado: el progreso se guarda en este dispositivo.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.paleta.tintaSuave,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

extension on _PanelDificultades {
  /// Carrusel de dificultades como el del menú: compactas y con reflejo.
  Widget _carrusel(List<ProgresoDificultadRemoto> dificultades) =>
      CarruselGiratorio(
        itemCount: dificultades.length,
        inicial: dificultades
            .indexWhere((item) => item.dificultad == seleccionada)
            .clamp(0, dificultades.length - 1),
        compacto: true,
        proporcion: 1.25,
        onCambio: (index) => onCambio(dificultades[index].dificultad),
        colorDe: (index) => colorDificultad(dificultades[index].dificultad),
        itemBuilder: (context, index, alFrente) {
          final progreso = dificultades[index];
          Widget tarjeta(bool alFrente) => _ResumenDificultad(
            progreso: progreso,
            anterior: index == 0 ? null : dificultades[index - 1],
            niveles: nivelesDe(progreso.dificultad),
            alFrente: alFrente,
            onTap: () => onAbrir(progreso.dificultad),
          );
          return ConReflejo(
            color: colorDificultad(progreso.dificultad),
            tarjeta: tarjeta(alFrente),
            // La copia del reflejo va sin desenfoque.
            reflejo: tarjeta(false),
          );
        },
      );

  /// Todos los niveles de la dificultad seleccionada.
  Widget _niveles() {
    final dificultades = estado.dificultades;
    final index = dificultades
        .indexWhere((item) => item.dificultad == seleccionada)
        .clamp(0, dificultades.length - 1);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _TarjetaDificultad(
            progreso: dificultades[index],
            anterior: index == 0 ? null : dificultades[index - 1],
            niveles: nivelesDe(dificultades[index].dificultad),
            alFrente: true,
            onJugar: (nivel) => onJugar(dificultades[index].dificultad, nivel),
            onRefresh: onRefresh,
          ),
        ),
      ),
    );
  }
}

/// Tarjeta compacta del carrusel de dificultades: avance y los niveles ya
/// completados; tocarla abre la tarjeta con todos los niveles.
class _ResumenDificultad extends StatelessWidget {
  const _ResumenDificultad({
    required this.progreso,
    required this.anterior,
    required this.niveles,
    required this.alFrente,
    required this.onTap,
  });

  final ProgresoDificultadRemoto progreso;
  final ProgresoDificultadRemoto? anterior;
  final List<NivelAsignado> niveles;
  final bool alFrente;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = colorDificultad(progreso.dificultad);
    final tono = context.paleta.tonoTexto(color);
    final bloqueada = !progreso.desbloqueada;
    final completados = [
      for (var i = 0; i < niveles.length; i++)
        if (niveles[i].completado) i + 1,
    ];
    return LiquidGlassCard(
      borderRadius: 28,
      tintColor: color,
      borderColor: alFrente ? color : null,
      // Las laterales solo se ven al girar: sin desenfoque, que es caro.
      blur: alFrente ? LiquidGlass.glassBlur : 0,
      child: LiquidRippleEffect(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            // Con letra grande se encoge en vez de desbordarse.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 280,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 76,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: progreso.total == 0
                                ? 0
                                : progreso.completados / progreso.total,
                            strokeWidth: 7,
                            color: color,
                            backgroundColor: color.withValues(alpha: 0.2),
                            strokeCap: StrokeCap.round,
                          ),
                          Center(
                            child: bloqueada
                                ? Icon(
                                    Icons.lock_rounded,
                                    color: context.paleta.tintaSuave,
                                  )
                                : Text(
                                    '${progreso.completados}/'
                                    '${max(progreso.total, 5)}',
                                    style: text.titleLarge,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _nombreDificultad(progreso.dificultad),
                      style: text.headlineMedium?.copyWith(color: tono),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bloqueada
                          ? 'Completa ${_nombreDificultad(anterior?.dificultad ?? progreso.dificultad)} para desbloquearla'
                          : completados.isEmpty
                          ? 'Aún no completas niveles'
                          : progreso.completados >= progreso.total
                          ? '¡Completada! 🎉'
                          : 'Niveles completados',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(
                        color: context.paleta.tintaSuave,
                      ),
                    ),
                    if (completados.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      // Solo los completados; los demás se ven al abrirla.
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final numero in completados)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.6),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Nivel $numero',
                                    style: text.labelMedium?.copyWith(
                                      color: tono,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 16,
                                    color: tono,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ver niveles',
                          style: text.labelLarge?.copyWith(color: tono),
                        ),
                        Icon(Icons.chevron_right_rounded, color: tono),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Una "pantalla" con todos los niveles de la dificultad.
class _TarjetaDificultad extends StatelessWidget {
  const _TarjetaDificultad({
    required this.progreso,
    required this.anterior,
    required this.niveles,
    required this.alFrente,
    required this.onJugar,
    required this.onRefresh,
  });

  final ProgresoDificultadRemoto progreso;
  final ProgresoDificultadRemoto? anterior;
  final List<NivelAsignado> niveles;
  final bool alFrente;
  final ValueChanged<int> onJugar;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = colorDificultad(progreso.dificultad);
    // La dificultad se puede ver siempre; sus niveles se abren al completar
    // la anterior.
    final bloqueada = !progreso.desbloqueada;
    final cantidadBloqueados = progreso.total == 0 ? 5 : progreso.total;
    return LiquidGlassCard(
      borderRadius: 28,
      tintColor: color,
      borderColor: alFrente ? color : null,
      // Las laterales solo se ven al girar y atenuadas: sin desenfoque, que es
      // lo más caro de pintar en cada cuadro.
      blur: alFrente ? LiquidGlass.glassBlur : 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Anillo de avance con "3/5" (o candado) en el centro.
                SizedBox.square(
                  dimension: 64,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progreso.total == 0
                            ? 0
                            : progreso.completados / progreso.total,
                        strokeWidth: 6,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.2),
                        strokeCap: StrokeCap.round,
                      ),
                      Center(
                        child: bloqueada
                            ? Icon(
                                Icons.lock_rounded,
                                color: context.paleta.tintaSuave,
                              )
                            : Text(
                                '${progreso.completados}/'
                                '${max(progreso.total, 5)}',
                                style: text.titleMedium,
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nombreDificultad(progreso.dificultad),
                        style: text.headlineMedium?.copyWith(
                          color: context.paleta.tonoTexto(color),
                        ),
                      ),
                      Text(
                        bloqueada
                            ? 'Completa ${_nombreDificultad(anterior?.dificultad ?? progreso.dificultad)} para desbloquearla'
                            : progreso.total == 0
                            ? 'Todavía no hay niveles publicados'
                            : progreso.completados >= progreso.total
                            ? '¡Completada! 🎉'
                            : 'Niveles completados',
                        style: text.bodyMedium?.copyWith(
                          color: context.paleta.tintaSuave,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: color.withValues(alpha: 0.35), height: 1),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                onRefresh: onRefresh,
                child: LayoutBuilder(
                  builder: (context, espacio) => ListView(
                    padding: EdgeInsets.zero,
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: _llenarEspacio(
                      espacio.maxHeight,
                      color,
                      bloqueada
                          ? [
                              for (var i = 0; i < cantidadBloqueados; i++)
                                LiquidLevelCard(
                                  numero: i + 1,
                                  estado: EstadoNivel.bloqueado,
                                  color: color,
                                ),
                            ]
                          : [
                              for (var i = 0; i < niveles.length; i++)
                                _tarjetaNivel(i, niveles[i], color),
                            ],
                      escalaTexto: MediaQuery.textScalerOf(context).scale(1),
                      vacio: Text(
                        progreso.total == 0
                            ? 'Todavía no hay niveles disponibles para esta dificultad.'
                            : 'No hay niveles completados para repetir.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Reparte el alto disponible: con pocos niveles las tarjetas crecen y, si
  /// aún sobra espacio, abajo toca la banda. Con muchos niveles se desplaza.
  List<Widget> _llenarEspacio(
    double alto,
    Color color,
    List<Widget> tarjetas, {
    required Widget vacio,
    required double escalaTexto,
  }) {
    const separacion = 10.0;
    // Alto natural de la casilla, mayor si el sistema usa letra grande.
    final altoMinimo = max(64.0, 24 + escalaTexto * 44);
    final altoMaximo = altoMinimo;
    const altoBanda = 90.0;
    if (tarjetas.isEmpty) {
      return [
        Padding(padding: const EdgeInsets.only(top: 24), child: vacio),
        SizedBox(
          height: max(altoBanda, alto - 120),
          child: BandaMusical(color: color),
        ),
      ];
    }
    final n = tarjetas.length;
    final altoTarjeta = ((alto - n * separacion) / n).clamp(
      altoMinimo,
      altoMaximo,
    );
    final sobrante = alto - n * (altoTarjeta + separacion);
    return [
      for (final tarjeta in tarjetas)
        Padding(
          padding: const EdgeInsets.only(bottom: separacion),
          child: SizedBox(height: altoTarjeta, child: tarjeta),
        ),
      if (sobrante >= altoBanda)
        SizedBox(
          height: sobrante - 1,
          child: BandaMusical(color: color),
        ),
    ];
  }

  Widget _tarjetaNivel(int index, NivelAsignado asignado, Color color) {
    final canStart = asignado.completado || asignado.puedeIniciar;
    return LiquidLevelCard(
      numero: index + 1,
      color: color,
      estado: asignado.completado
          ? EstadoNivel.completado
          : canStart
          ? EstadoNivel.disponible
          : EstadoNivel.bloqueado,
      onJugar: () => onJugar(index),
    );
  }
}

/// "Vas en el nivel 3 de Fácil" según la dificultad activa.
String _textoNivel(EstadoJuegoRemoto estado) {
  final terminado = estado.dificultades.any(
    (progreso) =>
        progreso.dificultad == Dificultad.avanzado &&
        progreso.total >= 5 &&
        progreso.completados >= progreso.total,
  );
  if (terminado) return '¡Completaste las tres dificultades!';
  final activa = estado.dificultades
      .where((item) => item.dificultad == estado.dificultadActiva)
      .firstOrNull;
  final nivel = min((activa?.completados ?? 0) + 1, 5);
  return 'Vas en el nivel $nivel de '
      '${_nombreDificultad(estado.dificultadActiva)}';
}

String _nombreDificultad(Dificultad dificultad) {
  switch (dificultad) {
    case Dificultad.facil:
      return 'Fácil';
    case Dificultad.medio:
      return 'Media';
    case Dificultad.avanzado:
      return 'Avanzada';
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('No se pudo cargar el progreso:\n$error'),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}

class FirebaseAuthScreen extends StatefulWidget {
  const FirebaseAuthScreen({super.key, this.savedUser, this.onSignedIn});

  final User? savedUser;
  final VoidCallback? onSignedIn;

  @override
  State<FirebaseAuthScreen> createState() => _FirebaseAuthScreenState();
}

class _FirebaseAuthScreenState extends State<FirebaseAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _registering = false;
  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (_registering) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        await credential.user?.updateDisplayName(_name.text.trim());
      } else {
        await auth.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      widget.onSignedIn?.call();
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = error.message ?? error.code);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await prepararGoogle();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google no devolvió un token de autenticación.');
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await FirebaseAuth.instance.signInWithCredential(credential);
      widget.onSignedIn?.call();
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = error.message ?? error.code);
    } on GoogleSignInException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.code == GoogleSignInExceptionCode.canceled
              ? 'Se canceló el inicio de sesión con Google.'
              : error.description ?? error.code.name;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInAnonymously();
      widget.onSignedIn?.call();
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = error.message ?? error.code);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Botones y enlaces con los azules del logo (celeste en modo oscuro).
    final tema = Theme.of(context);
    return Theme(
      data: tema.copyWith(
        colorScheme: tema.colorScheme.copyWith(
          primary: context.paleta.oscuro ? celesteLogin : azulLogin,
        ),
      ),
      child: Scaffold(
        body: ConCarga(
          cargando: _busy,
          texto: 'Iniciando sesión...',
          child: Stack(
            fit: StackFit.expand,
            children: [
              const FondoLogin(),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LiquidGlassCard(
                              // Más opaca y con borde azul del logo: resalta
                              // sobre el fondo y el texto se lee bien.
                              opacity: 0.6,
                              borderRadius: 28,
                              borderColor: azulLogin,
                              padding: const EdgeInsets.all(24),
                              // Campos con contorno cian y etiqueta arriba.
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  inputDecorationTheme: camposLogin(context),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Center(child: LogoCircular()),
                                        // Dentro de la tarjeta: arriba no
                                        // tapa su borde.
                                        Positioned(
                                          top: -12,
                                          right: -12,
                                          child: BotonTema(),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _registering
                                          ? 'Crea tu cuenta'
                                          : 'Bienvenido',
                                      textAlign: TextAlign.center,
                                      style: text.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Pon a prueba tu oído y descubre la melodía',
                                      textAlign: TextAlign.center,
                                      style: text.bodyMedium?.copyWith(
                                        color: context.paleta.tintaSuave,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    if (_registering) ...[
                                      TextFormField(
                                        controller: _name,
                                        textInputAction: TextInputAction.next,
                                        decoration: const InputDecoration(
                                          labelText: 'Nombre',
                                          prefixIcon: Icon(
                                            Icons.person_outline,
                                          ),
                                        ),
                                        validator: (value) =>
                                            value == null ||
                                                value.trim().isEmpty
                                            ? 'Escribe tu nombre'
                                            : null,
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    TextFormField(
                                      controller: _email,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      decoration: const InputDecoration(
                                        labelText: 'Correo',
                                        prefixIcon: Icon(Icons.mail_outline),
                                      ),
                                      validator: (value) =>
                                          value == null || !value.contains('@')
                                          ? 'Escribe un correo válido'
                                          : null,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _password,
                                      obscureText: !_showPassword,
                                      decoration: InputDecoration(
                                        labelText: 'Contraseña',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline,
                                        ),
                                        suffixIcon: IconButton(
                                          tooltip: _showPassword
                                              ? 'Ocultar contraseña'
                                              : 'Mostrar contraseña',
                                          onPressed: () => setState(
                                            () =>
                                                _showPassword = !_showPassword,
                                          ),
                                          icon: Icon(
                                            _showPassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                          ),
                                        ),
                                      ),
                                      validator: (value) =>
                                          value == null || value.length < 6
                                          ? 'Usa al menos 6 caracteres'
                                          : null,
                                    ),
                                    if (_error != null) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        _error!,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 20),
                                    BotonDegradado(
                                      onPressed: _busy ? null : _submit,
                                      label: _registering
                                          ? 'Crear cuenta'
                                          : 'Iniciar sesión',
                                    ),
                                    // El invitado ya tiene "Jugar sin registrarme",
                                    // que retoma la misma sesión anónima.
                                    if (!_registering &&
                                        widget.savedUser != null &&
                                        !widget.savedUser!.isAnonymous) ...[
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: _busy
                                            ? null
                                            : widget.onSignedIn,
                                        icon: const Icon(
                                          Icons.play_circle_outline,
                                        ),
                                        label: Text(
                                          'Continuar como ${_nombreSesion(widget.savedUser!)}',
                                        ),
                                      ),
                                    ],
                                    if (!_registering) ...[
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          const Expanded(child: Divider()),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            child: Text(
                                              'o',
                                              style: text.bodySmall,
                                            ),
                                          ),
                                          const Expanded(child: Divider()),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      OutlinedButton.icon(
                                        onPressed: _busy
                                            ? null
                                            : _signInWithGoogle,
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        icon: const _LogoGoogle(),
                                        label: const Text(
                                          'Continuar con Google',
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton.icon(
                                        onPressed: _busy
                                            ? null
                                            : _continueAsGuest,
                                        icon: const Icon(
                                          Icons.sports_esports_outlined,
                                        ),
                                        label: const Text(
                                          'Jugar sin registrarme',
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                      _registering = !_registering;
                                      _error = null;
                                    }),
                              child: Text(
                                _registering
                                    ? '¿Ya tienes cuenta? Inicia sesión'
                                    : '¿No tienes cuenta? Crea una nueva',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "G" de Google en sus cuatro colores, dibujada para no sumar una
/// dependencia de SVG.
class _LogoGoogle extends StatelessWidget {
  const _LogoGoogle();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: Size.square(20), painter: _GooglePainter());
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final centro = size.center(Offset.zero);
    final grosor = r * 0.38;
    final aro = Rect.fromCircle(center: centro, radius: r - grosor / 2);
    double grados(double g) => g * pi / 180;
    // Ángulos en sentido horario desde las 3 en punto; la abertura de la G
    // queda arriba a la derecha.
    for (final (inicio, barrido, color) in [
      (-40.0, -140.0, const Color(0xFFEA4335)), // rojo, arriba
      (180.0, -45.0, const Color(0xFFFBBC05)), // amarillo, izquierda
      (135.0, -95.0, const Color(0xFF34A853)), // verde, abajo
      (40.0, -40.0, const Color(0xFF4285F4)), // azul, derecha
    ]) {
      canvas.drawArc(
        aro,
        grados(inicio),
        grados(barrido),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = grosor
          ..color = color,
      );
    }
    // Barra horizontal de la G.
    canvas.drawRect(
      Rect.fromLTWH(centro.dx, centro.dy - grosor / 2, r, grosor),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(_GooglePainter oldDelegate) => false;
}

String _nombreSesion(User user) {
  final nombre = user.displayName;
  if (nombre != null && nombre.trim().isNotEmpty) return nombre;
  return user.email ?? 'usuario';
}
