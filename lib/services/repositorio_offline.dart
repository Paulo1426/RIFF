import 'dart:async';
import 'dart:math';

import '../models/genero.dart';
import '../models/instrumento.dart';
import '../models/nivel.dart';
import '../models/pista.dart';
import 'audio_service.dart';
import 'firebase_game_repository.dart';
import 'paquete_offline.dart';

/// Partida de un nivel jugado sin conexión (vive solo en memoria).
class _PartidaLocal {
  _PartidaLocal(this.genero, this.paquete);

  final Genero genero;
  final PaqueteNivel paquete;
  final comprados = <String>[];
  final precios = <int>[];

  int get presupuesto =>
      Nivel.presupuestoTotal -
      precios.fold<int>(0, (suma, precio) => suma + precio);
}

/// El repositorio de siempre, pero que sin conexión juega con el
/// [PaqueteOffline] guardado: una canción por género en cada minijuego. En
/// línea no cambia nada.
///
/// Sin conexión solo se puede jugar lo del paquete: las pistas, las monedas y
/// las salas siguen pidiendo internet. Los aciertos quedan pendientes y se
/// envían al volver a abrir la app con red.
class RepositorioConPaquete extends FirebaseGameRepository {
  RepositorioConPaquete({
    required this.paquetes,
    required this.audio,
    super.auth,
    super.client,
    super.supabaseUrl,
    super.supabaseAnonKey,
  });

  final PaqueteOffline paquetes;
  final AudioService audio;
  final Map<String, _PartidaLocal> _partidas = {};

  // Sin esto, una red mala dejaría la pantalla esperando sin caer al paquete.
  static const _espera = Duration(seconds: 8);
  static const _prefijoLocal = 'offline:';

  static bool _esLocal(String gameId) => gameId.startsWith(_prefijoLocal);

  Future<PaqueteGenero?> _paquete(Genero? genero) async {
    final uid = this.uid;
    if (uid == null) return null;
    await paquetes.cargar(uid);
    return paquetes.de(genero ?? generoActivo);
  }

  _PartidaLocal _partida(String gameId) =>
      _partidas[gameId] ??
      (throw const GameRepositoryException(
        statusCode: 404,
        message: 'Esa partida sin conexión ya no está disponible.',
      ));

  /// Llamar al iniciar sesión: sube los aciertos pendientes y baja los
  /// paquetes de cada género. No lanza: sin red queda lo ya guardado.
  @override
  Future<void> prepararOffline() => paquetes.actualizar(this);

  // --- Accesos al servidor sin caer al paquete (los usa PaqueteOffline) ---

  Future<Map<String, dynamic>> paqueteOfflineRemoto(Genero genero) =>
      super.paqueteOffline(genero);

  Future<({String url, String version})> obtenerAudioRemoto({
    required String gameId,
    required String tipo,
    String? instrumento,
  }) =>
      super.obtenerAudio(gameId: gameId, tipo: tipo, instrumento: instrumento);

  Future<PartidaIniciada> iniciarNivelRemoto(String nivelId) =>
      super.iniciarNivel(nivelId);

  Future<ResultadoRespuesta> enviarRespuestaRemota({
    required String gameId,
    required String respuesta,
  }) => super.enviarRespuesta(gameId: gameId, respuesta: respuesta);

  Future<ResultadoRespuesta> enviarRespuestaIntroRemota({
    required String introId,
    required String respuesta,
  }) => super.enviarRespuestaIntro(introId: introId, respuesta: respuesta);

  // --- Niveles ---

  @override
  Future<EstadoJuegoRemoto> cargarEstado({Genero? genero}) async {
    try {
      return await super.cargarEstado(genero: genero).timeout(_espera);
    } catch (error) {
      final nivel = (await _paquete(genero))?.nivel;
      if (!esErrorDeRed(error) || nivel == null) rethrow;
      return nivel.estado;
    }
  }

  @override
  Future<PartidaIniciada> iniciarNivel(String nivelId) async {
    try {
      return await super.iniciarNivel(nivelId).timeout(_espera);
    } catch (error) {
      final paquete = await _paquete(null);
      final nivel = paquete?.nivel;
      if (!esErrorDeRed(error) || nivel == null || nivel.nivel.id != nivelId) {
        rethrow;
      }
      final gameId = '$_prefijoLocal$nivelId';
      _partidas[gameId] = _PartidaLocal(paquete!.genero, nivel);
      return PartidaIniciada(gameId: gameId, nivel: nivel.nivel);
    }
  }

  @override
  Future<({String url, String version})> obtenerAudio({
    required String gameId,
    required String tipo,
    String? instrumento,
  }) async {
    if (!_esLocal(gameId)) {
      return super.obtenerAudio(
        gameId: gameId,
        tipo: tipo,
        instrumento: instrumento,
      );
    }
    final partida = _partida(gameId);
    final versiones = partida.paquete.versiones;
    switch (tipo) {
      case 'stem':
        // La clave de caché lleva la versión; el archivo ya está guardado.
        return (url: 'offline://stem', version: versiones[instrumento] ?? '');
      case 'instrumentalSong':
        return (
          url: 'offline://instrumental',
          version: versiones['instrumental'] ?? '',
        );
      case 'fullSong':
        final archivo = await paquetes.originalDe(
          partida.genero,
          partida.paquete.nivel.id,
        );
        if (archivo == null) break;
        return (url: Uri.file(archivo.path).toString(), version: '');
    }
    throw const GameRepositoryException(
      statusCode: 404,
      message: 'Ese audio no está guardado para jugar sin conexión.',
    );
  }

  @override
  Future<ResultadoCompraInstrumento> comprarInstrumento({
    required String gameId,
    required String instrumento,
  }) async {
    if (!_esLocal(gameId)) {
      return super.comprarInstrumento(gameId: gameId, instrumento: instrumento);
    }
    final partida = _partida(gameId);
    final nivel = partida.paquete.nivel;
    ResultadoCompraInstrumento resultado({
      required bool realizada,
      required int precio,
    }) => ResultadoCompraInstrumento(
      presupuestoRestante: partida.presupuesto,
      instrumentosComprados: List.of(partida.comprados),
      // Sin conexión la melodía solo se descubre si se compró; la pista que
      // la revela necesita internet.
      melodiaDescubierta:
          nivel.instrumentoMelodia != null &&
          partida.comprados.contains(nivel.instrumentoMelodia!.id),
      compraRealizada: realizada,
      precioInstrumento: precio,
    );

    final indice = partida.comprados.indexOf(instrumento);
    if (indice >= 0) {
      return resultado(realizada: false, precio: partida.precios[indice]);
    }
    if (partida.comprados.length >= 3) {
      throw const GameRepositoryException(
        statusCode: 409,
        message:
            'Ya compraste el máximo de tres instrumentos para esta partida',
      );
    }
    final precio = _siguientePrecio(partida.precios);
    partida.comprados.add(instrumento);
    partida.precios.add(precio);
    return resultado(realizada: true, precio: precio);
  }

  /// Igual que `selectNextInstrumentPrice` en game-progress: 300 000 o
  /// 400 000 al azar, y el tercero es lo que reste del presupuesto.
  static int _siguientePrecio(List<int> comprados) {
    final restante =
        Nivel.presupuestoTotal -
        comprados.fold<int>(0, (suma, precio) => suma + precio);
    return switch (comprados) {
      [] || [300000] => [300000, 400000][Random().nextInt(2)],
      [400000] => 300000,
      _ => restante,
    };
  }

  @override
  Future<ResultadoPista> pedirPista({
    required String gameId,
    required TipoPista tipo,
  }) {
    if (!_esLocal(gameId)) return super.pedirPista(gameId: gameId, tipo: tipo);
    throw const GameRepositoryException(
      statusCode: 503,
      message: 'Las pistas necesitan conexión a internet.',
    );
  }

  @override
  Future<ResultadoRespuesta> enviarRespuesta({
    required String gameId,
    required String respuesta,
  }) async {
    if (!_esLocal(gameId)) {
      return super.enviarRespuesta(gameId: gameId, respuesta: respuesta);
    }
    final partida = _partida(gameId);
    final paquete = partida.paquete;
    if (!paquete.acierta(respuesta)) {
      return const ResultadoRespuesta(correcta: false);
    }
    await paquetes.agregarPendiente(
      AciertoPendiente(
        genero: partida.genero,
        id: paquete.nivel.id,
        respuesta: respuesta,
        esIntro: false,
      ),
    );
    return ResultadoRespuesta(
      correcta: true,
      titulo: paquete.titulo,
      artista: paquete.artista,
    );
  }

  // --- Intros ---

  @override
  Future<EstadoIntros> cargarIntros({Genero? genero}) async {
    try {
      return await super.cargarIntros(genero: genero).timeout(_espera);
    } catch (error) {
      final intro = (await _paquete(genero))?.intro;
      if (!esErrorDeRed(error) || intro == null) rethrow;
      final hecha = paquetes.tienePendiente(intro.id);
      return EstadoIntros(
        monedas: 0,
        monedasGanadas: 0,
        restantes: 0,
        puedeSacar: false,
        intros: [
          IntroAsignada(
            id: intro.id,
            numero: 1,
            estado: hecha ? EstadoIntro.completada : EstadoIntro.desbloqueada,
            titulo: hecha ? intro.titulo : null,
            artista: hecha ? intro.artista : null,
          ),
        ],
      );
    }
  }

  @override
  Future<ResultadoRespuesta> enviarRespuestaIntro({
    required String introId,
    required String respuesta,
  }) async {
    try {
      return await super
          .enviarRespuestaIntro(introId: introId, respuesta: respuesta)
          .timeout(_espera);
    } catch (error) {
      final paquete = await _paquete(null);
      final intro = paquete?.intro;
      if (!esErrorDeRed(error) || intro == null || intro.id != introId) {
        rethrow;
      }
      if (!intro.acierta(respuesta)) {
        return const ResultadoRespuesta(correcta: false);
      }
      // Una intro que no era suya es solo práctica: no se envía.
      if (intro.propia) {
        await paquetes.agregarPendiente(
          AciertoPendiente(
            genero: paquete!.genero,
            id: introId,
            respuesta: respuesta,
            esIntro: true,
          ),
        );
      }
      return ResultadoRespuesta(
        correcta: true,
        titulo: intro.titulo,
        artista: intro.artista,
      );
    }
  }
}
