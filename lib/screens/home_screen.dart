import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/nivel.dart';
import '../models/sala.dart';
import '../providers/providers.dart';
import '../services/firebase_game_repository.dart';
import '../services/offline_game_store.dart';
import '../animations/liquid_ripple_effect.dart';
import '../widgets/boton_tema.dart';
import '../widgets/liquid_glass/liquid_background.dart';
import '../theme.dart';
import '../theme/liquid_glass_theme.dart';
import '../widgets/liquid_glass/liquid_glass_appbar.dart';
import '../widgets/liquid_glass/liquid_glass_bottom_nav.dart';
import '../widgets/liquid_glass/liquid_glass_button.dart';
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
          return FirebaseAuthScreen(
            savedUser: user,
            onSignedIn: () => setState(() => _entered = true),
          );
        }
        return _AuthenticatedHome(key: ValueKey(user.uid), user: user);
      },
    );
  }
}

// Una vez por apertura de la app; cerrar sesión y volver a entrar no lo repite.
var _avisoAuricularesMostrado = false;

class _AuthenticatedHome extends ConsumerStatefulWidget {
  const _AuthenticatedHome({super.key, required this.user});

  final User user;

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
  // Barra inferior: 0 menú, 1 Adivina la canción, 2 Adivina la intro,
  // 3 salas, 4 progreso, 5 configuración.
  int _pestana = 0;
  static const _pCancion = 1, _pIntro = 2, _pSalas = 3, _pProgreso = 4;
  Future<EstadoIntros?>? _introsFuturo;
  // Para las tarjetas del menú: cuántas intros tiene y salas ganadas.
  EstadoIntros? _resumenIntros;
  SaldoSalas _saldo = const SaldoSalas();
  StreamSubscription<SaldoSalas>? _suscripcionSaldo;
  // Monedas de Adivina la intro para la barra (null hasta saberlas).
  int? _monedas;
  TipoSala _tipoSala = TipoSala.instrumentos;
  // Elementos que resalta el recorrido guiado.
  final _claveMenu = GlobalKey();
  final _clavesPestanas = List.generate(6, (_) => GlobalKey());
  bool _recorridoRevisado = false;
  // Se completa al cerrar el aviso de auriculares; el recorrido espera.
  final _avisoCerrado = Completer<void>();

  Future<void> _verRecorrido() => mostrarRecorrido(context, _pasosMenu());

  List<PasoRecorrido> _pasosMenu() => [
    PasoRecorrido(
      clave: _claveMenu,
      titulo: '🎮 Menú principal',
      texto:
          'Las tarjetas giran solas; también puedes deslizarlas. 🥁 Adivina '
          'la canción: compra instrumentos con \$1.000.000 y adivina. '
          '🏆 Desafía a tus amigos. 🎧 Adivina la intro: se desbloquea al '
          'completar tu primer nivel.',
    ),
    PasoRecorrido(
      clave: _clavesPestanas[_pCancion],
      titulo: '🥁 Canción',
      texto: 'Las dificultades y niveles de Adivina la canción.',
    ),
    PasoRecorrido(
      clave: _clavesPestanas[_pIntro],
      titulo: '🎧 Intro',
      texto: 'Tu colección de Adivina la intro y el botón para sacar cartas.',
    ),
    PasoRecorrido(
      clave: _clavesPestanas[_pSalas],
      titulo: '👥 Salas',
      texto:
          'Juega con hasta 5 amigos: salas de Adivina la canción y de '
          'Adivina la intro, por tiempo o por eliminación.',
    ),
    PasoRecorrido(
      clave: _clavesPestanas[_pProgreso],
      titulo: '📈 Progreso',
      texto:
          'Tus niveles, tus monedas 🪙, tus fichas 🎟️ y las canciones que '
          'ya adivinaste.',
    ),
    PasoRecorrido(
      clave: _clavesPestanas[5],
      titulo: '⚙️ Ajustes',
      texto: 'Instrucciones, música del menú, modo oscuro y cerrar sesión.',
    ),
  ];

  /// La primera vez que se abre la app, al ver el menú, empieza el recorrido.
  Future<void> _recorridoSiEsNuevo() async {
    if (_recorridoRevisado) return;
    _recorridoRevisado = true;
    await _avisoCerrado.future;
    if (!mounted) return;
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
              'Desliza para ver Fácil, Media y Avanzada. Completa sus 5 '
              'niveles para desbloquear la siguiente. Cada nivel que ganas '
              'por primera vez te da monedas 🪙 para Adivina la intro: '
              'Fácil 2, Media 3 y Avanzada 4.',
        ),
      ],
    );
  }

  // "Adivina la intro" se abre al completar el primer nivel.
  bool get _introsDisponibles =>
      _estado?.dificultades.any((item) => item.completados > 0) ?? false;

  /// Una vez por apertura de la app, antes del menú: usar auriculares.
  Future<void> _avisoAuriculares() async {
    if (!_avisoAuricularesMostrado && mounted) {
      _avisoAuricularesMostrado = true;
      await showDialog<void>(
        context: context,
        builder: (context) => LiquidGlassDialog(
          icon: const Icon(Icons.headphones_rounded, size: 64),
          title: const Text('Usa auriculares', textAlign: TextAlign.center),
          content: const Text(
            'Se recomienda usar cascos (audífonos o auriculares) para '
            'distinguir bien cada instrumento.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
    if (!_avisoCerrado.isCompleted) _avisoCerrado.complete();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _avisoAuriculares());
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
      if (_introsDisponibles) {
        unawaited(
          _estadoIntros().then((intros) {
            if (mounted) {
              setState(() {
                _resumenIntros = intros;
                _monedas = intros?.monedas ?? _monedas;
              });
            }
          }),
        );
      }
      // Deja listas las intros obtenidas por si luego se pierde la conexión.
      if (_introsDisponibles) {
        unawaited(
          ref
              .read(offlineIntroStoreProvider)
              .actualizar(widget.user.uid)
              .then(
                (_) {},
                onError: (Object error) =>
                    debugPrint('No se pudieron descargar las intros: $error'),
              ),
        );
      }
      try {
        final bundle = await repository.descargarPaqueteOffline();
        final refreshed = await _cacheOfflineBundle(
          bundle,
          widget.user.uid,
          widget.user.isAnonymous,
        );
        if (!mounted) return;
        setState(() => _offlineSnapshot = refreshed);
      } catch (error) {
        debugPrint('No se pudo actualizar el paquete offline: $error');
        if (snapshot == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudieron descargar todos los niveles para usarlos sin conexión.',
              ),
            ),
          );
        }
      }
    } catch (error) {
      if (!mounted) return;
      await _loadOfflineSnapshot(error);
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
    final levels = await Future.wait(
      rawLevels.map((rawLevel) async {
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
          final file = await audioService.descargarYGuardar(url, key);
          paths[instrument.id] = file.path;
        }
        final instrumentalUrl = data['instrumentalAudioUrl'];
        if (instrumentalUrl is! String || instrumentalUrl.isEmpty) {
          throw FormatException(
            'Falta el enlace offline de la pista instrumental de ${nivel.id}',
          );
        }
        final instrumentalFile = await audioService.descargarYGuardar(
          instrumentalUrl,
          'song:${nivel.cancionId}:instrumentalSong:'
          '${versiones['instrumental'] ?? ''}',
        );
        return OfflineLevelData(
          nivel: nivel,
          completado: entry['completado'] as bool? ?? false,
          puedeIniciar: entry['puede_iniciar'] as bool? ?? false,
          respuesta: data['respuesta'] as String,
          audioPaths: paths,
          instrumentalAudioPath: instrumentalFile.path,
        );
      }),
    );
    final snapshot = OfflineGameSnapshot(
      uid: uid,
      guest: guest,
      stateJson: state,
      levels: levels,
      pendingCompletions: _offlineSnapshot?.uid == uid
          ? _offlineSnapshot!.pendingCompletions
          : const [],
    );
    await _offlineStore.save(snapshot);
    return snapshot;
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
      await repository.sincronizarNivelOffline(
        levelId: levelId,
        respuesta: answer,
      );
      current = current.withoutPendingCompletion(levelId);
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
      if (_offlineMode) {
        if (offlineLevel == null) {
          throw StateError('Este nivel no está descargado para jugar offline');
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
        if (offlineLevel == null) rethrow;
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
    if (resultado != null) {
      final antes = _desbloqueadas();
      final terminadoAntes = _juegoTerminado();
      final introsAntes = _introsDisponibles;
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

  Future<void> _cerrarSesion() async {
    try {
      if (widget.user.isAnonymous) {
        await ref
            .read(firebaseGameRepositoryProvider)
            .finalizarSesionInvitado();
        await widget.user.delete();
      }
      await FirebaseAuth.instance.signOut();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cerrar sesión: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = _estado;
    // El fondo cubre también la barra para que el vidrio tenga qué mostrar.
    return LiquidBackground(
      acento: switch (_pestana) {
        _pCancion when estado != null => colorDificultad(
          _seleccionada ?? estado.dificultadActiva,
        ),
        _pIntro => AppColors.signalOrange,
        _ => null,
      },
      // Atrás desde cualquier pestaña vuelve al menú.
      child: PopScope(
        canPop: _pestana == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _cambiarPestana(0);
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: LiquidGlassAppBar(
            centerTitle: false,
            title: _tituloBarra(estado),
            actions: [..._accionesBarra(), const SizedBox(width: 8)],
          ),
          bottomNavigationBar: LiquidGlassBottomNav(
            claves: _clavesPestanas,
            currentIndex: _pestana,
            onTap: _cambiarPestana,
            items: const [
              (icon: Icons.home_rounded, label: 'Menú'),
              (icon: Icons.music_note_rounded, label: 'Canción'),
              (icon: Icons.headphones_rounded, label: 'Intro'),
              (icon: Icons.groups_rounded, label: 'Salas'),
              (icon: Icons.insights_rounded, label: 'Progreso'),
              (icon: Icons.settings_rounded, label: 'Ajustes'),
            ],
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: switch (_pestana) {
              _pCancion => _pestanaCancion(estado),
              _pIntro => _pestanaIntro(),
              _pSalas => _pestanaSalas(),
              _pProgreso => _PestanaProgreso(
                key: const ValueKey('progreso'),
                dificultades: estado?.dificultades ?? const [],
                intros: _introsFuturo,
              ),
              5 => _PestanaConfiguracion(
                key: const ValueKey('configuracion'),
                onRecorrido: _verRecorrido,
                onCerrarSesion: _cerrarSesion,
              ),
              _ => _pestanaMenu(estado),
            },
          ),
        ),
      ),
    );
  }

  /// Título de la barra de arriba según la pestaña: el logo en el menú y el
  /// nombre de la sección en las demás.
  Widget _tituloBarra(EstadoJuegoRemoto? estado) => switch (_pestana) {
    _pCancion when estado != null => Text(
      'Dificultad · '
      '${_nombreDificultad(_seleccionada ?? estado.dificultadActiva)}',
    ),
    _pCancion => const Text('Adivina la canción'),
    _pIntro => const Text('Adivina la intro'),
    _pSalas => Text(
      _tipoSala == TipoSala.intros ? 'Adivina la intro' : 'Adivina la canción',
    ),
    _pProgreso => const Text('Progreso'),
    5 => const Text('Ajustes'),
    _ => Image.asset(
      'lib/assets/images/logo/riff_logo.png',
      height: 48,
      semanticLabel: 'Riff',
    ),
  };

  /// Monedas 🪙 en Intro y Progreso; fichas 🎟️ en Salas y Progreso.
  List<Widget> _accionesBarra() => [
    if ((_pestana == _pIntro || _pestana == _pProgreso) && _monedas != null)
      _Saldo('🪙', _monedas!, 'monedas'),
    if ((_pestana == _pSalas || _pestana == _pProgreso) &&
        !widget.user.isAnonymous)
      _Saldo('🎟️', _saldo.fichas, 'fichas'),
  ];

  void _cambiarPestana(int pestana) {
    setState(() {
      _pestana = pestana;
      // Progreso se vuelve a pedir al abrir la pestaña, para que esté al día.
      if (pestana == _pProgreso) {
        _introsFuturo = _estadoIntros()
          ..then((intros) {
            if (mounted && intros != null) {
              setState(() => _monedas = intros.monedas);
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
      claveCarrusel: _claveMenu,
      onVisible: _recorridoSiEsNuevo,
      introsDisponibles: _introsDisponibles,
      offlineMode: _offlineMode,
      esInvitado: widget.user.isAnonymous,
      infoCancion: _infoCancion(estado!),
      infoIntros: _resumenIntros == null
          ? null
          : '${_resumenIntros!.intros.length} intros desbloqueadas',
      infoSalas: widget.user.isAnonymous
          ? null
          : _saldo.ganadas == 0
          ? 'Aún no ganas salas'
          : 'Ganaste ${_saldo.ganadas} '
                '${_saldo.ganadas == 1 ? 'sala' : 'salas'} · '
                '🥁 ${_saldo.ganadasCancion} · 🎧 ${_saldo.ganadasIntros}',
      onInstrumentos: () => _cambiarPestana(_pCancion),
      onSalas: () => _cambiarPestana(_pSalas),
      onIntros: () => _cambiarPestana(_pIntro),
    );
  }

  /// "Vas en el nivel 3 de Fácil" según la dificultad activa.
  String _infoCancion(EstadoJuegoRemoto estado) {
    if (_juegoTerminado()) return '¡Completaste las tres dificultades!';
    final activa = estado.dificultades
        .where((item) => item.dificultad == estado.dificultadActiva)
        .firstOrNull;
    final nivel = min((activa?.completados ?? 0) + 1, 5);
    return 'Vas en el nivel $nivel de '
        '${_nombreDificultad(estado.dificultadActiva)}';
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
      onMonedas: (monedas) => setState(() => _monedas = monedas),
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

  Widget _pestanaCancion(EstadoJuegoRemoto? estado) {
    if (_esperandoProgreso() case final espera?) return espera;
    return _PanelDificultades(
      key: _claveDificultades,
      estado: estado!,
      seleccionada: _seleccionada ?? estado.dificultadActiva,
      esInvitado: widget.user.isAnonymous,
      offlineMode: _offlineMode,
      nivelesDe: _nivelesDe,
      onCambio: (dificultad) => setState(() => _seleccionada = dificultad),
      onJugar: _jugar,
      onRefresh: _cargar,
    );
  }

  Widget _pestanaSalas() {
    final motivo = widget.user.isAnonymous
        ? 'Crea una cuenta para jugar en salas con tus amigos.'
        : _offlineMode
        ? 'Necesitas conexión a internet para jugar en salas.'
        : null;
    if (motivo == null) {
      return SalasPanel(
        key: const ValueKey('salas'),
        onTipo: (tipo) => setState(() => _tipoSala = tipo),
      );
    }
    return _bloqueada('salas-bloqueadas', motivo);
  }
}

/// Pestaña Progreso: avance de niveles e intros, monedas 🪙, fichas 🎟️ y las
/// canciones de Adivina la intro ya adivinadas (insignias).
class _PestanaProgreso extends StatelessWidget {
  const _PestanaProgreso({
    super.key,
    required this.dificultades,
    required this.intros,
  });

  final List<ProgresoDificultadRemoto> dificultades;
  final Future<EstadoIntros?>? intros;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return FutureBuilder<EstadoIntros?>(
      future: intros,
      builder: (context, snapshot) {
        final estadoIntros = snapshot.data;
        final cargando = snapshot.connectionState != ConnectionState.done;
        final adivinadas = [
          for (final intro in estadoIntros?.intros ?? const <IntroAsignada>[])
            if (intro.estado == EstadoIntro.completada) intro,
        ];
        return ListView(
          padding: EdgeInsets.symmetric(
            horizontal: max(16, (MediaQuery.sizeOf(context).width - 680) / 2),
            vertical: 16,
          ),
          children: [
            LiquidGlassCard(
              padding: const EdgeInsets.all(20),
              child: _ProgresoGeneral(
                dificultades: dificultades,
                intros: estadoIntros,
                cargandoIntros: cargando,
              ),
            ),
            const SizedBox(height: 16),
            LiquidGlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('🏅 Insignias', style: text.titleMedium),
                  Text(
                    'Canciones que adivinaste en Adivina la intro',
                    style: text.bodySmall?.copyWith(
                      color: context.paleta.tintaSuave,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (cargando)
                    const LinearProgressIndicator()
                  else if (adivinadas.isEmpty)
                    Text(
                      estadoIntros == null
                          ? 'Se desbloquea al completar tu primer nivel.'
                          : 'Aún no adivinas ninguna intro. ¡Saca una carta!',
                      textAlign: TextAlign.center,
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final intro in adivinadas)
                          Chip(
                            avatar: const Text('🎵'),
                            label: Text(
                              [
                                intro.titulo ?? 'Intro #${intro.numero}',
                                ?intro.artista,
                              ].join(' · '),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
      },
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
    required this.onRecorrido,
    required this.onCerrarSesion,
  });

  final VoidCallback onRecorrido;
  final VoidCallback onCerrarSesion;

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

  Widget _fila(
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
    final total = totalNiveles + totalIntros;
    final porcentaje = total == 0 ? 0.0 : (niveles + adivinadas) / total;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${(porcentaje * 100).round()}%',
          textAlign: TextAlign.center,
          style: text.displaySmall?.copyWith(color: AppColors.signalOrange),
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
                color: AppColors.signalOrange,
                detalle: intros == null
                    ? 'Se desbloquea al completar tu primer nivel.'
                    : '${intros.intros.length} cartas obtenidas',
              ),
      ],
    );
  }
}

/// Menú principal: carrusel de los tres modos que gira solo de izquierda a
/// derecha (se pausa al tocarlo).
class _MenuPrincipal extends StatelessWidget {
  const _MenuPrincipal({
    super.key,
    required this.claveCarrusel,
    required this.onVisible,
    required this.introsDisponibles,
    required this.offlineMode,
    required this.esInvitado,
    required this.infoCancion,
    required this.infoIntros,
    required this.infoSalas,
    required this.onInstrumentos,
    required this.onSalas,
    required this.onIntros,
  });

  final GlobalKey claveCarrusel;
  // Una línea de datos del jugador en cada tarjeta (null si no hay).
  final String infoCancion;
  final String? infoIntros;
  final String? infoSalas;
  // Avisa cuando el menú ya está en pantalla (para el recorrido inicial).
  final VoidCallback onVisible;
  final bool introsDisponibles;
  final bool offlineMode;
  final bool esInvitado;
  final VoidCallback onInstrumentos;
  final VoidCallback onSalas;
  final VoidCallback onIntros;

  static const _colores = [
    AppColors.verde,
    AppColors.medio,
    AppColors.signalOrange,
  ];

  @override
  Widget build(BuildContext context) {
    final introsBloqueadas = !introsDisponibles;
    final salasBloqueadas = esInvitado || offlineMode;
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
        itemBuilder: (context, index, alFrente) => switch (index) {
          0 => _CuadroModo(
            emoji: '🥁🪗🎸',
            animacion: _Animacion.tocar,
            titulo: 'Adivina la canción',
            detalle: 'Compra instrumentos y descubre la canción.',
            info: infoCancion,
            color: AppColors.verde,
            alFrente: alFrente,
            onTap: onInstrumentos,
          ),
          1 => _CuadroModo(
            emoji: '🏆',
            animacion: _Animacion.saltar,
            titulo: 'Desafía a tus amigos',
            detalle: esInvitado
                ? 'Crea una cuenta para jugar en salas.'
                : offlineMode
                ? 'Necesitas conexión para jugar en salas.'
                : 'Crea o únete a una sala de hasta 5 jugadores.',
            info: salasBloqueadas ? null : infoSalas,
            color: AppColors.medio,
            alFrente: alFrente,
            bloqueado: salasBloqueadas,
            onTap: salasBloqueadas ? null : onSalas,
          ),
          _ => _CuadroModo(
            emoji: '🎧',
            animacion: _Animacion.mecer,
            titulo: 'Adivina la intro',
            detalle: !introsDisponibles
                ? 'Se desbloquea al completar tu primer nivel.'
                : offlineMode
                ? 'Sin conexión: juega las intros descargadas.'
                : 'Escucha 20 segundos y adivina la canción.',
            info: introsBloqueadas ? null : infoIntros,
            color: AppColors.signalOrange,
            alFrente: alFrente,
            bloqueado: introsBloqueadas,
            onTap: introsBloqueadas ? null : onIntros,
          ),
        },
      ),
    );
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
                        activo: !bloqueado,
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

class _EmojiAnimadoState extends State<_EmojiAnimado>
    with SingleTickerProviderStateMixin {
  late final _ciclo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

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

  // Con "reducir movimiento" del sistema o bloqueado, quieto.
  void _actualizar() {
    if (!widget.activo || MediaQuery.disableAnimationsOf(context)) {
      _ciclo
        ..stop()
        ..value = 0;
    } else if (!_ciclo.isAnimating) {
      _ciclo.repeat();
    }
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emojis = widget.emoji.characters.toList();
    return ExcludeSemantics(
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
                      child: Text(emoji, style: const TextStyle(fontSize: 48)),
                    ),
                  ),
                ),
            ],
          );
        },
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
    required this.onCambio,
    required this.onJugar,
    required this.onRefresh,
  });

  final EstadoJuegoRemoto estado;
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
              child: CarruselGiratorio(
                itemCount: dificultades.length,
                inicial: dificultades
                    .indexWhere((item) => item.dificultad == seleccionada)
                    .clamp(0, dificultades.length - 1),
                onCambio: (index) => onCambio(dificultades[index].dificultad),
                colorDe: (index) =>
                    colorDificultad(dificultades[index].dificultad),
                itemBuilder: (context, index, alFrente) => _TarjetaDificultad(
                  progreso: dificultades[index],
                  anterior: index == 0 ? null : dificultades[index - 1],
                  niveles: nivelesDe(dificultades[index].dificultad),
                  alFrente: alFrente,
                  onJugar: (nivel) =>
                      onJugar(dificultades[index].dificultad, nivel),
                  onRefresh: onRefresh,
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

/// Una "pantalla" del carrusel: la dificultad con su lista de niveles.
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
  Future<void>? _googleSignInReady;

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
      await (_googleSignInReady ??= GoogleSignIn.instance.initialize());
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
    return Scaffold(
      body: ConCarga(
        cargando: _busy,
        texto: 'Iniciando sesión...',
        child: Stack(
          fit: StackFit.expand,
          children: [
            const LiquidBackground(child: SizedBox.expand()),
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
                          Center(
                            child: Image.asset(
                              'lib/assets/images/logo/riff_logo.png',
                              height: 180,
                              semanticLabel: 'Riff',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Adivina la canción: pon a prueba tu oído y descubre la melodía',
                            textAlign: TextAlign.center,
                            style: text.bodyLarge?.copyWith(
                              color: context.paleta.tintaSuave,
                            ),
                          ),
                          const SizedBox(height: 24),
                          LiquidGlassCard(
                            tintColor: AppColors.verde,
                            // Algo más opaco que el estándar: es un formulario
                            // y el texto debe leerse bien.
                            opacity: 0.4,
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _registering
                                      ? 'Crea tu cuenta'
                                      : 'Bienvenido',
                                  style: text.headlineMedium,
                                ),
                                const SizedBox(height: 16),
                                if (_registering) ...[
                                  TextFormField(
                                    controller: _name,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Nombre',
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
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
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      tooltip: _showPassword
                                          ? 'Ocultar contraseña'
                                          : 'Mostrar contraseña',
                                      onPressed: () => setState(
                                        () => _showPassword = !_showPassword,
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
                                LiquidGlassButton(
                                  variant: LiquidGlassButtonVariant.secondary,
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
                                    onPressed: _busy ? null : widget.onSignedIn,
                                    icon: const Icon(Icons.play_circle_outline),
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
                                        child: Text('o', style: text.bodySmall),
                                      ),
                                      const Expanded(child: Divider()),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                    onPressed: _busy ? null : _signInWithGoogle,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    icon: const _LogoGoogle(),
                                    label: const Text('Continuar con Google'),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: _busy ? null : _continueAsGuest,
                                    icon: const Icon(
                                      Icons.sports_esports_outlined,
                                    ),
                                    label: const Text('Jugar sin registrarme'),
                                  ),
                                ],
                              ],
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
            // Al final del Stack: encima del formulario, que ocupa toda la
            // pantalla y si no se quedaría con los toques.
            const SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(padding: EdgeInsets.all(8), child: BotonTema()),
              ),
            ),
          ],
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
