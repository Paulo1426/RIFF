import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../animations/liquid_ripple_effect.dart';
import '../models/nivel.dart';
import '../models/sala.dart';
import '../providers/providers.dart';
import '../services/firebase_game_repository.dart';
import '../theme.dart';
import '../widgets/liquid_glass/liquid_background.dart';
import '../widgets/liquid_glass/liquid_glass_appbar.dart';
import '../widgets/liquid_glass/liquid_glass_button.dart';
import '../widgets/liquid_glass/liquid_glass_card.dart';
import '../widgets/liquid_glass/liquid_glass_dialog.dart';
import '../widgets/recorrido.dart';
import 'game_screen.dart';
import 'intros_screen.dart';

const _colorSalas = AppColors.medio;

String _nombreModo(ModoSala modo) => switch (modo) {
  ModoSala.contrarreloj => 'Contrarreloj · 5 min',
  ModoSala.eliminacion => 'Eliminación',
};

String _nombreDificultad(Dificultad dificultad) => switch (dificultad) {
  Dificultad.facil => 'Fácil',
  Dificultad.medio => 'Media',
  Dificultad.avanzado => 'Avanzada',
};

// Contenido del QR de una sala; el prefijo evita unirse con cualquier QR.
String _qrDeSala(String codigo) => 'riff:sala:$codigo';
final _patronQr = RegExp(r'^riff:sala:([A-Z0-9]{6})$');

Color _colorDe(Sala sala) => sala.tipo == TipoSala.intros
    ? AppColors.signalOrange
    : colorDificultad(sala.dificultad);

String _descripcion(Sala sala) => sala.tipo == TipoSala.intros
    ? '🎧 Intros · ${_nombreModo(sala.modo)}'
    : '🥁 Instrumentos · ${_nombreModo(sala.modo)} · '
          '${_nombreDificultad(sala.dificultad)}';

String _mensajeError(Object error) =>
    error is GameRepositoryException ? error.message : '$error';

/// Ancho cómodo en tablets: el contenido queda centrado.
EdgeInsets _margenLista(BuildContext context) => EdgeInsets.symmetric(
  horizontal: max(16, (MediaQuery.sizeOf(context).width - 680) / 2),
  vertical: 16,
);

/// "Desafía a tus amigos": crear una sala, unirse con código o entrar a una
/// sala pública.
class SalasScreen extends ConsumerStatefulWidget {
  const SalasScreen({super.key});

  @override
  ConsumerState<SalasScreen> createState() => _SalasScreenState();
}

class _SalasScreenState extends ConsumerState<SalasScreen> {
  final _codigo = TextEditingController();
  bool _ocupado = false;
  int _fichas = 0;
  StreamSubscription<int>? _suscripcionFichas;
  final _claveFichas = GlobalKey();
  final _claveCrear = GlobalKey();
  final _claveUnirse = GlobalKey();
  final _claveAbiertas = GlobalKey();

  List<PasoRecorrido> _pasos() => [
    PasoRecorrido(
      clave: _claveFichas,
      titulo: '🎟️ Tus fichas',
      texto:
          'Moneda de las salas, distinta de las monedas 🪙. Al terminar una '
          'sala de instrumentos el 1.º gana 10, el 2.º 7 y el 3.º 3 (si '
          'acertaron al menos una canción y no abandonaron).',
    ),
    PasoRecorrido(
      clave: _claveCrear,
      titulo: '➕ Crear sala',
      texto:
          'Elige qué se juega (🥁 instrumentos gratis o 🎧 intros por '
          '$precioSalaIntros fichas), el reto, la dificultad y si es pública '
          'o cerrada. Hasta 5 jugadores; tú la inicias con 2 o más.',
    ),
    PasoRecorrido(
      clave: _claveUnirse,
      titulo: '🔑 Unirse',
      texto:
          'Escribe el código de 6 letras o escanea el QR que muestra la '
          'sala de tu amigo.',
    ),
    PasoRecorrido(
      clave: _claveAbiertas,
      titulo: '🌍 Salas abiertas',
      texto:
          'Salas públicas esperando jugadores. Toca una para entrar. '
          'Contrarreloj: 5 minutos, gana quien sume más puntos. '
          'Eliminación: sale el último en adivinar cada canción.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => const RecorridoInicial('salas').mostrarSiEsNuevo(context, _pasos),
    );
    _suscripcionFichas = _repo.fichas().listen(
      (fichas) => setState(() => _fichas = fichas),
      onError: (Object error) => debugPrint('No se pudo leer fichas: $error'),
    );
  }

  FirebaseGameRepository get _repo => ref.read(firebaseGameRepositoryProvider);

  @override
  void dispose() {
    _suscripcionFichas?.cancel();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _ejecutar(Future<String> Function() accion) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      final codigo = await accion();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => SalaScreen(codigo: codigo)),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_mensajeError(error))));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _crear() async {
    final opciones = await showDialog<(TipoSala, ModoSala, Dificultad, bool)>(
      context: context,
      builder: (_) => _DialogoCrearSala(fichas: _fichas),
    );
    if (opciones == null) return;
    final (tipo, modo, dificultad, publica) = opciones;
    await _ejecutar(
      () => _repo.crearSala(
        tipo: tipo,
        modo: modo,
        dificultad: dificultad,
        publica: publica,
      ),
    );
  }

  Future<void> _unirse(String codigo) => _ejecutar(() async {
    await _repo.unirseSala(codigo);
    return codigo;
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LiquidBackground(
      acento: _colorSalas,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: LiquidGlassAppBar(
          title: const Text('Sala RIFF'),
          actions: [
            IconButton(
              tooltip: 'Ver ayuda',
              icon: const Icon(Icons.help_outline_rounded),
              onPressed: () => mostrarRecorrido(context, _pasos()),
            ),
          ],
        ),
        body: ConCarga(
          cargando: _ocupado,
          texto: 'Entrando a la sala...',
          child: ListView(
            padding: _margenLista(context),
            children: [
              LiquidGlassCard(
                key: _claveFichas,
                borderRadius: 18,
                tintColor: AppColors.signalOrange,
                child: ListTile(
                  leading: const Text('🎟️', style: TextStyle(fontSize: 28)),
                  title: Text(
                    '$_fichas ${_fichas == 1 ? 'ficha' : 'fichas'}',
                    style: text.titleMedium,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              LiquidGlassButton(
                key: _claveCrear,
                onPressed: _crear,
                icon: Icons.add_rounded,
                label: 'Crear sala',
              ),
              const SizedBox(height: 16),
              LiquidGlassCard(
                key: _claveUnirse,
                tintColor: _colorSalas,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Unirse con código', style: text.titleMedium),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _codigo,
                      maxLength: 6,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp('[A-Za-z0-9]'),
                        ),
                        TextInputFormatter.withFunction(
                          (_, nuevo) =>
                              nuevo.copyWith(text: nuevo.text.toUpperCase()),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Código de invitación',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _unirseConCodigo(),
                    ),
                    const SizedBox(height: 12),
                    LiquidGlassButton(
                      variant: LiquidGlassButtonVariant.secondary,
                      onPressed: _unirseConCodigo,
                      icon: Icons.login_rounded,
                      label: 'Unirse',
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _escanear,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Escanear código QR'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Salas abiertas',
                key: _claveAbiertas,
                style: text.titleMedium,
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<Sala>>(
                stream: _repo.salasPublicas(),
                builder: (context, snapshot) {
                  // Un error al listar no le sirve al jugador: se registra y
                  // se muestra igual que "no hay salas".
                  if (snapshot.hasError) {
                    debugPrint(
                      'No se pudieron listar salas: ${snapshot.error}',
                    );
                  }
                  final salas = snapshot.data;
                  if (salas == null && !snapshot.hasError) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (salas == null || salas.isEmpty) {
                    return Column(
                      children: [
                        const SizedBox(
                          height: 140,
                          child: BandaMusical(color: _colorSalas),
                        ),
                        Text(
                          'No hay salas abiertas ahora. ¡Crea una!',
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(
                            color: context.paleta.tintaSuave,
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      for (final sala in salas)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TarjetaSalaPublica(
                            sala: sala,
                            onUnirse: () => _unirse(sala.codigo),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _escanear() async {
    final codigo = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const _EscanerQr()));
    if (codigo != null) await _unirse(codigo);
  }

  void _unirseConCodigo() {
    final codigo = _codigo.text.trim();
    if (codigo.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El código tiene 6 caracteres.')),
      );
      return;
    }
    _unirse(codigo);
  }
}

/// Cámara a pantalla completa; devuelve el código del primer QR de sala.
class _EscanerQr extends StatefulWidget {
  const _EscanerQr();

  @override
  State<_EscanerQr> createState() => _EscanerQrState();
}

class _EscanerQrState extends State<_EscanerQr> {
  bool _leido = false;

  void _alDetectar(BarcodeCapture captura) {
    if (_leido) return;
    for (final codigo in captura.barcodes) {
      final coincidencia = _patronQr.firstMatch(codigo.rawValue ?? '');
      if (coincidencia != null) {
        _leido = true;
        Navigator.of(context).pop(coincidencia.group(1));
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: const Text('Escanear sala'),
    ),
    body: Stack(
      children: [
        MobileScanner(
          onDetect: _alDetectar,
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                error.errorCode == MobileScannerErrorCode.permissionDenied
                    ? 'Permite el acceso a la cámara para escanear el código.'
                    : 'No se pudo abrir la cámara: ${error.errorCode.name}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        const Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Apunta al código QR que muestra la sala.',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );
}

class _TarjetaSalaPublica extends StatelessWidget {
  const _TarjetaSalaPublica({required this.sala, required this.onUnirse});

  final Sala sala;
  final VoidCallback onUnirse;

  @override
  Widget build(BuildContext context) {
    final creador = sala.jugador(sala.creadorUid)?.nombre ?? 'Alguien';
    return LiquidGlassCard(
      borderRadius: 18,
      tintColor: _colorDe(sala),
      child: ListTile(
        onTap: onUnirse,
        leading: const Text('🏆', style: TextStyle(fontSize: 28)),
        title: Text('Sala de $creador'),
        subtitle: Text(_descripcion(sala)),
        trailing: Text(
          '${sala.jugadores.length}/${sala.maxJugadores}'
          '${sala.tipo == TipoSala.intros ? '\n🎟️ $precioSalaIntros' : ''}',
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

class _DialogoCrearSala extends StatefulWidget {
  const _DialogoCrearSala({required this.fichas});

  final int fichas;

  @override
  State<_DialogoCrearSala> createState() => _DialogoCrearSalaState();
}

class _DialogoCrearSalaState extends State<_DialogoCrearSala> {
  var _tipo = TipoSala.instrumentos;
  var _modo = ModoSala.contrarreloj;
  var _dificultad = Dificultad.facil;
  var _publica = true;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final intros = _tipo == TipoSala.intros;
    final sinFichas = intros && widget.fichas < precioSalaIntros;
    final acento = intros
        ? AppColors.signalOrange
        : colorDificultad(_dificultad);
    Widget titulo(String texto) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(texto, style: text.titleMedium),
    );
    return LiquidGlassDialog(
      child: ConstrainedBox(
        // Desplazable en teléfonos bajos o con letra grande.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '🏆',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 40),
              ),
              Text(
                'Nueva sala',
                textAlign: TextAlign.center,
                style: text.headlineMedium,
              ),
              Text(
                'Hasta 5 jugadores · todos escuchan las mismas canciones',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(
                  color: context.paleta.tintaSuave,
                ),
              ),
              titulo('¿Qué se juega?'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Opcion(
                      emoji: '🥁',
                      titulo: 'Instrumentos',
                      detalle: 'Gratis. Los 3 primeros ganan fichas.',
                      color: acento,
                      elegida: !intros,
                      onTap: () =>
                          setState(() => _tipo = TipoSala.instrumentos),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Opcion(
                      emoji: '🎧',
                      titulo: 'Intros',
                      detalle:
                          'Cuesta 🎟️ $precioSalaIntros. Tienes ${widget.fichas}.',
                      color: acento,
                      elegida: intros,
                      onTap: () => setState(() => _tipo = TipoSala.intros),
                    ),
                  ),
                ],
              ),
              titulo('Elige el reto'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Opcion(
                      emoji: '⏱️',
                      titulo: 'Contrarreloj',
                      detalle: '5 minutos. Gana quien sume más puntos.',
                      color: acento,
                      elegida: _modo == ModoSala.contrarreloj,
                      onTap: () =>
                          setState(() => _modo = ModoSala.contrarreloj),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Opcion(
                      emoji: '🥊',
                      titulo: 'Eliminación',
                      detalle: 'Sin tiempo. Sale el último en adivinar.',
                      color: acento,
                      elegida: _modo == ModoSala.eliminacion,
                      onTap: () => setState(() => _modo = ModoSala.eliminacion),
                    ),
                  ),
                ],
              ),
              if (!intros) titulo('Dificultad'),
              if (!intros)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final dificultad in Dificultad.values)
                      ChoiceChip(
                        label: Text(_nombreDificultad(dificultad)),
                        selected: _dificultad == dificultad,
                        showCheckmark: false,
                        avatar: CircleAvatar(
                          backgroundColor: colorDificultad(dificultad),
                          radius: 6,
                        ),
                        selectedColor: colorDificultad(
                          dificultad,
                        ).withValues(alpha: 0.3),
                        side: BorderSide(
                          color: _dificultad == dificultad
                              ? colorDificultad(dificultad)
                              : context.paleta.borde,
                        ),
                        onSelected: (_) =>
                            setState(() => _dificultad = dificultad),
                      ),
                  ],
                ),
              if (sinFichas)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'Te faltan fichas: gana en salas de instrumentos para '
                    'jugar intros con tus amigos.',
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              titulo('¿Quién puede entrar?'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Opcion(
                      emoji: '🌍',
                      titulo: 'Pública',
                      detalle: 'Aparece en salas abiertas.',
                      color: acento,
                      elegida: _publica,
                      onTap: () => setState(() => _publica = true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Opcion(
                      emoji: '🔒',
                      titulo: 'Cerrada',
                      detalle: 'Solo con código o QR.',
                      color: acento,
                      elegida: !_publica,
                      onTap: () => setState(() => _publica = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LiquidGlassButton(
                onPressed: sinFichas
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pop((_tipo, _modo, _dificultad, _publica)),
                icon: Icons.add_rounded,
                label: intros
                    ? 'Crear sala · 🎟️ $precioSalaIntros'
                    : 'Crear sala',
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta seleccionable del diálogo de nueva sala; la elegida se tiñe y
/// lleva borde del color de acento.
class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.emoji,
    required this.titulo,
    required this.detalle,
    required this.color,
    required this.elegida,
    required this.onTap,
  });

  final String emoji;
  final String titulo;
  final String detalle;
  final Color color;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      selected: elegida,
      button: true,
      child: AnimatedScale(
        scale: elegida ? 1 : 0.96,
        duration: const Duration(milliseconds: 150),
        child: LiquidGlassCard(
          borderRadius: 18,
          blur: 0,
          opacity: elegida ? 0.7 : 0.35,
          tintColor: elegida ? color : null,
          borderColor: elegida ? color : null,
          child: LiquidRippleEffect(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(height: 4),
                  Text(
                    titulo,
                    style: text.titleSmall?.copyWith(
                      color: elegida ? context.paleta.tonoTexto(color) : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detalle,
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(
                      color: context.paleta.tintaSuave,
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

/// Una sala: espera de jugadores, partida en curso y resultados. Escucha la
/// sala en tiempo real; todas las acciones pasan por el servidor.
class SalaScreen extends ConsumerStatefulWidget {
  const SalaScreen({super.key, required this.codigo});

  final String codigo;

  @override
  ConsumerState<SalaScreen> createState() => _SalaScreenState();
}

class _SalaScreenState extends ConsumerState<SalaScreen> {
  StreamSubscription<Sala?>? _suscripcion;
  Sala? _sala;
  bool _cargada = false;
  Object? _error;
  bool _ocupado = false;
  // Hay una canción abierta encima de esta pantalla.
  bool _jugando = false;
  ModalRoute<dynamic>? _ruta;

  FirebaseGameRepository get _repo => ref.read(firebaseGameRepositoryProvider);
  String get _uid => _repo.uid ?? '';

  @override
  void initState() {
    super.initState();
    _suscripcion = _repo
        .escucharSala(widget.codigo)
        .listen(
          _alCambiar,
          onError: (Object error) => setState(() => _error = error),
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ruta ??= ModalRoute.of(context);
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }

  void _alCambiar(Sala? sala) {
    if (!mounted) return;
    setState(() {
      _sala = sala;
      _cargada = true;
    });
    // Si la sala termina o me eliminan, se cierra la canción abierta.
    final yo = sala?.jugador(_uid);
    if (_jugando &&
        (sala == null ||
            sala.estado == EstadoSala.terminada ||
            (yo?.eliminado ?? true))) {
      Navigator.of(context).popUntil((ruta) => ruta == _ruta);
    }
  }

  Future<void> _accion(Future<void> Function() accion) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      await accion();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_mensajeError(error))));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _salir() async {
    final sala = _sala;
    if (sala != null && sala.estado != EstadoSala.terminada) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => LiquidGlassDialog(
          title: const Text('¿Salir de la sala?'),
          content: Text(
            sala.estado == EstadoSala.jugando
                ? 'Dejarás de competir en esta partida.'
                : 'Podrás volver a entrar con el código mientras no empiece.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Quedarme'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Salir'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
      try {
        await _repo.salirSala(widget.codigo);
      } catch (error) {
        debugPrint('No se pudo salir de la sala: $error');
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// Abre la canción que me toca; en contrarreloj encadena la siguiente.
  Future<void> _jugar() async {
    final sala = _sala;
    if (sala == null || _jugando) return;
    PartidaSala? partida;
    await _accion(() async => partida = await _repo.partidaSala(widget.codigo));
    final actual = partida;
    if (!mounted || actual == null) return;
    final contrarreloj = sala.modo == ModoSala.contrarreloj;
    final titulo = contrarreloj
        ? 'Canción ${actual.indice + 1}'
        : 'Ronda ${sala.ronda}';
    var siguiente = false;
    Future<void> saltar(BuildContext context) async {
      try {
        await _repo.saltarCancionSala(widget.codigo);
        siguiente = true;
      } catch (error) {
        debugPrint('No se pudo saltar la canción: $error');
      }
      if (context.mounted) Navigator.of(context).pop();
    }

    void pasar(BuildContext context) {
      siguiente = true;
      Navigator.of(context).pop();
    }

    final Widget Function(BuildContext) pantalla;
    if (actual.introId case final introId?) {
      pantalla = (context) => IntroGameScreen(
        intro: IntroAsignada(
          id: introId,
          numero: actual.indice + 1,
          estado: EstadoIntro.desbloqueada,
        ),
        sala: IntroEnSala(
          codigo: widget.codigo,
          titulo: titulo,
          cabecera: _CabeceraPartida(sala: sala),
          onSaltar: contrarreloj ? () => saltar(context) : null,
          onSiguiente: contrarreloj ? () => pasar(context) : null,
        ),
      );
    } else if (actual.gameId != null && actual.nivel != null) {
      pantalla = (context) => GameScreen(
        nivel: actual.nivel!,
        gameId: actual.gameId!,
        titulo: titulo,
        cabecera: _CabeceraPartida(sala: sala),
        comprasPrevias: actual.compras,
        melodiaDescubierta: actual.melodiaDescubierta,
        onSiguiente: contrarreloj ? () => pasar(context) : null,
        onSaltar: contrarreloj ? () => saltar(context) : null,
      );
    } else {
      return;
    }
    _jugando = true;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: pantalla));
    _jugando = false;
    if (siguiente && mounted && _sala?.estado == EstadoSala.jugando) {
      await _jugar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sala = _sala;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _salir();
      },
      child: LiquidBackground(
        acento: sala == null ? _colorSalas : _colorDe(sala),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: LiquidGlassAppBar(
            leading: IconButton(
              tooltip: 'Salir de la sala',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _salir,
            ),
            title: Text('Sala ${widget.codigo}'),
          ),
          body: ConCarga(
            cargando: _ocupado,
            texto: 'Un momento...',
            child: _error != null
                ? Center(child: Text('No se pudo abrir la sala: $_error'))
                : !_cargada
                ? const Cargando(texto: 'Abriendo la sala...')
                : sala == null
                ? const Center(child: Text('Esta sala ya no existe.'))
                : ListView(
                    padding: _margenLista(context),
                    children: [
                      _Resumen(sala: sala, uid: _uid),
                      const SizedBox(height: 16),
                      ..._contenido(sala),
                      const SizedBox(height: 16),
                      _Clasificacion(sala: sala, uid: _uid),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  List<Widget> _contenido(Sala sala) {
    final text = Theme.of(context).textTheme;
    final yo = sala.jugador(_uid);
    switch (sala.estado) {
      case EstadoSala.esperando:
        final soyCreador = sala.creadorUid == _uid;
        return [
          if (soyCreador)
            LiquidGlassButton(
              onPressed: sala.jugadores.length < 2
                  ? null
                  : () => _accion(() => _repo.iniciarSala(widget.codigo)),
              icon: Icons.play_arrow_rounded,
              label: sala.jugadores.length < 2
                  ? 'Esperando a otro jugador...'
                  : 'Iniciar partida',
            )
          else
            Text(
              'Esperando a que el creador inicie la partida...',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(
                color: context.paleta.tintaSuave,
              ),
            ),
        ];
      case EstadoSala.jugando:
        if (yo == null || yo.eliminado) {
          return [
            Text(
              yo?.abandono ?? false
                  ? 'Saliste de esta partida.'
                  : 'Quedaste eliminado. Mira cómo termina.',
              textAlign: TextAlign.center,
              style: text.titleMedium,
            ),
          ];
        }
        final yaAdivine =
            sala.modo == ModoSala.eliminacion &&
            sala.acertaronRonda.contains(_uid);
        return [
          if (sala.finEn case final fin?)
            _Reloj(
              fin: fin,
              onFin: () => _repo
                  .revisarSala(widget.codigo)
                  .catchError(
                    (Object error) => debugPrint('No se pudo cerrar: $error'),
                  ),
            ),
          const SizedBox(height: 12),
          LiquidGlassButton(
            onPressed: yaAdivine ? null : _jugar,
            icon: Icons.music_note_rounded,
            label: yaAdivine
                ? 'Esperando a que los demás adivinen...'
                : 'Jugar canción',
          ),
        ];
      case EstadoSala.terminada:
        final ganador = sala.ganadorUid == null
            ? null
            : sala.jugador(sala.ganadorUid!);
        return [
          LiquidGlassCard(
            tintColor: _colorSalas,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 8),
                Text(
                  ganador == null
                      ? 'Partida terminada'
                      : sala.ganadorUid == _uid
                      ? '¡Ganaste!'
                      : 'Ganó ${ganador.nombre}',
                  textAlign: TextAlign.center,
                  style: text.headlineMedium,
                ),
                if (sala.premios[_uid] case final fichas?)
                  Text(
                    '+$fichas fichas 🎟️ para salas de intros',
                    textAlign: TextAlign.center,
                    style: text.titleMedium,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LiquidGlassButton(
            variant: LiquidGlassButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
            label: 'Volver',
          ),
        ];
    }
  }
}

/// Código para compartir y reglas de la sala.
class _Resumen extends StatelessWidget {
  const _Resumen({required this.sala, required this.uid});

  final Sala sala;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LiquidGlassCard(
      tintColor: _colorDe(sala),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            sala.estado == EstadoSala.esperando
                ? 'Comparte este código'
                : 'Código de la sala',
            style: text.bodyMedium?.copyWith(color: context.paleta.tintaSuave),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SelectableText(sala.codigo, style: text.displaySmall),
              IconButton(
                tooltip: 'Copiar código',
                icon: const Icon(Icons.copy_rounded),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: sala.codigo));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código copiado')),
                  );
                },
              ),
            ],
          ),
          if (sala.estado == EstadoSala.esperando) ...[
            const SizedBox(height: 8),
            // Fondo blanco fijo: el QR necesita contraste también en oscuro.
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.paperWhite,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: QrImageView(
                  data: _qrDeSala(sala.codigo),
                  size: 160,
                  semanticsLabel: 'Código QR de la sala ${sala.codigo}',
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            '${_descripcion(sala)} · ${sala.publica ? 'Pública' : 'Cerrada'}',
            textAlign: TextAlign.center,
          ),
          if (sala.estado == EstadoSala.jugando &&
              sala.modo == ModoSala.eliminacion)
            Text(
              'Ronda ${sala.ronda} · quedan '
              '${sala.jugadores.where((j) => !j.eliminado).length}',
              style: text.titleMedium,
            ),
        ],
      ),
    );
  }
}

/// Jugadores y su posición: puntos en contrarreloj, vivos o eliminados en
/// eliminación.
class _Clasificacion extends StatelessWidget {
  const _Clasificacion({required this.sala, required this.uid});

  final Sala sala;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final lista = sala.estado == EstadoSala.esperando
        ? sala.jugadores
        : sala.clasificacion;
    return LiquidGlassCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Jugadores ${sala.jugadores.length}/${sala.maxJugadores}',
              style: text.titleMedium,
            ),
          ),
          for (final (posicion, jugador) in lista.indexed)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: _colorDe(sala).withValues(alpha: 0.25),
                child: Text(
                  sala.estado == EstadoSala.esperando
                      ? jugador.nombre.characters.first.toUpperCase()
                      : '${posicion + 1}',
                ),
              ),
              title: Text(
                '${jugador.nombre}${jugador.uid == uid ? ' (tú)' : ''}',
                style: jugador.eliminado
                    ? TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: context.paleta.tintaSuave,
                      )
                    : null,
              ),
              subtitle: _detalle(jugador),
              trailing: sala.premios[jugador.uid] != null
                  ? Text(
                      '+${sala.premios[jugador.uid]} 🎟️',
                      style: text.titleMedium,
                    )
                  : jugador.uid == sala.creadorUid
                  ? const Tooltip(
                      message: 'Creador de la sala',
                      child: Text('👑', style: TextStyle(fontSize: 20)),
                    )
                  : null,
            ),
        ],
      ),
    );
  }

  Widget? _detalle(JugadorSala jugador) {
    if (sala.estado == EstadoSala.esperando) return null;
    if (sala.modo == ModoSala.contrarreloj) {
      return Text(
        '${jugador.puntos} puntos · ${jugador.aciertos} aciertos'
        '${jugador.abandono ? ' · salió' : ''}',
      );
    }
    if (jugador.eliminado) {
      return Text(
        jugador.abandono
            ? 'Salió en la ronda ${jugador.eliminadoEnRonda}'
            : 'Eliminado en la ronda ${jugador.eliminadoEnRonda}',
      );
    }
    return Text(
      sala.acertaronRonda.contains(jugador.uid)
          ? 'Ya adivinó esta ronda ✅'
          : 'Adivinando...',
    );
  }
}

/// Aviso sobre la canción de sala: tiempo restante o ronda.
class _CabeceraPartida extends StatelessWidget {
  const _CabeceraPartida({required this.sala});

  final Sala sala;

  @override
  Widget build(BuildContext context) => LiquidGlassCard(
    borderRadius: 18,
    tintColor: _colorSalas,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: sala.finEn != null
        ? _Reloj(fin: sala.finEn!)
        : Text(
            'Ronda ${sala.ronda} · el último en adivinar queda eliminado',
            textAlign: TextAlign.center,
          ),
  );
}

/// Cuenta regresiva mm:ss hasta [fin]; llama a [onFin] una vez al llegar a 0.
class _Reloj extends StatefulWidget {
  const _Reloj({required this.fin, this.onFin});

  final DateTime fin;
  final VoidCallback? onFin;

  @override
  State<_Reloj> createState() => _RelojState();
}

class _RelojState extends State<_Reloj> {
  late final Timer _timer;
  bool _avisado = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restante = widget.fin.difference(DateTime.now());
    final segundos = max(0, restante.inSeconds);
    if (segundos == 0 && !_avisado && widget.onFin != null) {
      _avisado = true;
      // Tras el frame: avisar no debe ocurrir durante build.
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onFin!());
    }
    final texto =
        '${segundos ~/ 60}:${(segundos % 60).toString().padLeft(2, '0')}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.timer_outlined,
          color: segundos <= 30 ? AppColors.avanzado : null,
        ),
        const SizedBox(width: 8),
        Text(
          segundos == 0 ? '¡Tiempo!' : texto,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: segundos <= 30 ? AppColors.avanzado : null,
          ),
        ),
      ],
    );
  }
}
