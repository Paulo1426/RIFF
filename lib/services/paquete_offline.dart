import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path_provider/path_provider.dart';

import '../models/genero.dart';
import '../models/nivel.dart';
import 'audio_service.dart';
import 'firebase_game_repository.dart';
import 'repositorio_offline.dart';

/// Igual que `normalizeAnswer` de game-progress: sin tildes, en minúsculas y
/// con cualquier signo convertido en un espacio.
String normalizarRespuesta(String valor) {
  const tildes = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a', //
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', //
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', //
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o', //
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', //
    'ñ': 'n', 'ç': 'c', 'ý': 'y', 'ÿ': 'y',
  };
  final sinTildes = valor
      .toLowerCase()
      .split('')
      .map((letra) => tildes[letra] ?? letra)
      .join();
  return sinTildes
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

/// SHA-256 de "id:respuesta normalizada": lo que el servidor manda en lugar
/// del texto de la respuesta (`huellaRespuesta` en game-progress).
String huellaRespuesta(String id, String respuesta) => sha256
    .convert(utf8.encode('$id:${normalizarRespuesta(respuesta)}'))
    .toString();

/// El nivel que se juega sin conexión en un género.
class PaqueteNivel {
  const PaqueteNivel({
    required this.nivel,
    required this.huella,
    required this.versiones,
    this.titulo,
    this.artista,
  });

  final Nivel nivel;
  final String huella;
  // Versión de cada archivo: 'instrumental' y el id de cada instrumento. Es
  // parte de la clave de la caché de audio, igual que en línea.
  final Map<String, String> versiones;
  final String? titulo;
  final String? artista;

  bool acierta(String respuesta) =>
      huellaRespuesta(nivel.id, respuesta) == huella;

  /// Lo que vería el jugador en línea con solo este nivel disponible.
  EstadoJuegoRemoto get estado => EstadoJuegoRemoto(
    dificultades: [
      for (final dificultad in Dificultad.values)
        ProgresoDificultadRemoto(
          dificultad: dificultad,
          desbloqueada: dificultad == nivel.dificultad,
          completados: 0,
          total: dificultad == nivel.dificultad ? 1 : 0,
        ),
    ],
    dificultadActiva: nivel.dificultad,
    niveles: [
      NivelAsignado(nivel: nivel, completado: false, puedeIniciar: true),
    ],
    nivelesRepetibles: const [],
  );

  factory PaqueteNivel.fromJson(Map<String, dynamic> json) => PaqueteNivel(
    nivel: Nivel.fromJson(json['nivel'] as Map<String, dynamic>),
    huella: json['huella'] as String,
    versiones: Map<String, String>.from(json['versiones'] as Map),
    titulo: json['titulo'] as String?,
    artista: json['artista'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'nivel': nivel.toJson(),
    'huella': huella,
    'versiones': versiones,
    'titulo': titulo,
    'artista': artista,
  };
}

/// La intro que se juega sin conexión en un género.
class PaqueteIntro {
  const PaqueteIntro({
    required this.id,
    required this.propia,
    required this.huella,
    this.titulo,
    this.artista,
  });

  final String id;
  // Si el jugador ya la tenía desbloqueada; si no, es solo práctica y no se
  // envía al servidor.
  final bool propia;
  final String huella;
  final String? titulo;
  final String? artista;

  bool acierta(String respuesta) => huellaRespuesta(id, respuesta) == huella;

  factory PaqueteIntro.fromJson(Map<String, dynamic> json) => PaqueteIntro(
    id: json['id'] as String,
    propia: json['propia'] as bool? ?? false,
    huella: json['huella'] as String,
    titulo: json['titulo'] as String?,
    artista: json['artista'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'propia': propia,
    'huella': huella,
    'titulo': titulo,
    'artista': artista,
  };
}

class PaqueteGenero {
  const PaqueteGenero({
    required this.genero,
    required this.fecha,
    this.nivel,
    this.intro,
  });

  final Genero genero;
  final DateTime fecha;
  final PaqueteNivel? nivel;
  final PaqueteIntro? intro;

  factory PaqueteGenero.fromJson(Map<String, dynamic> json) => PaqueteGenero(
    genero: Genero.deId(json['genero']),
    fecha: DateTime.parse(json['fecha'] as String),
    nivel: json['nivel'] == null
        ? null
        : PaqueteNivel.fromJson(json['nivel'] as Map<String, dynamic>),
    intro: json['intro'] == null
        ? null
        : PaqueteIntro.fromJson(json['intro'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'genero': genero.id,
    'fecha': fecha.toIso8601String(),
    'nivel': nivel?.toJson(),
    'intro': intro?.toJson(),
  };
}

/// Acierto sin conexión que falta por enviar al servidor.
class AciertoPendiente {
  const AciertoPendiente({
    required this.genero,
    required this.id,
    required this.respuesta,
    required this.esIntro,
  });

  final Genero genero;
  final String id;
  final String respuesta;
  final bool esIntro;

  factory AciertoPendiente.fromJson(Map<String, dynamic> json) =>
      AciertoPendiente(
        genero: Genero.deId(json['genero']),
        id: json['id'] as String,
        respuesta: json['respuesta'] as String,
        esIntro: json['esIntro'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
    'genero': genero.id,
    'id': id,
    'respuesta': respuesta,
    'esIntro': esIntro,
  };
}

/// Una canción de cada minijuego por género, guardada en el teléfono para
/// poder jugar sin conexión. Al iniciar sesión, con red, baja el audio a la
/// caché de [AudioService] (con las mismas claves que en línea) y guarda las
/// respuestas como huellas; cada jugador recibe canciones distintas porque el
/// servidor elige según su orden de niveles e intros.
class PaqueteOffline {
  PaqueteOffline(this._audio, {Future<Directory> Function()? carpeta})
    : _carpeta = carpeta ?? getApplicationSupportDirectory;

  final AudioService _audio;
  final Future<Directory> Function() _carpeta;

  /// Un paquete se renueva a los 3 días: el nivel elegido depende del
  /// progreso y los enlaces de audio se piden de nuevo.
  static const vigencia = Duration(days: 3);

  String? _uid;
  final Map<Genero, PaqueteGenero> _paquetes = {};
  final List<AciertoPendiente> _pendientes = [];
  Future<void>? _enCurso;

  Future<File> _archivo(String uid) async {
    final carpeta = Directory('${(await _carpeta()).path}/offline_pack');
    await carpeta.create(recursive: true);
    final seguro = base64Url.encode(utf8.encode(uid)).replaceAll('=', '');
    return File('${carpeta.path}/$seguro.json');
  }

  /// Lee lo guardado de [uid] (una sola vez por usuario).
  Future<void> cargar(String uid) async {
    if (kIsWeb || _uid == uid) return;
    _uid = uid;
    _paquetes.clear();
    _pendientes.clear();
    try {
      final archivo = await _archivo(uid);
      if (!await archivo.exists()) return;
      final json = jsonDecode(await archivo.readAsString());
      for (final item in json['paquetes'] as List<dynamic>) {
        final paquete = PaqueteGenero.fromJson(
          Map<String, dynamic>.from(item as Map),
        );
        _paquetes[paquete.genero] = paquete;
      }
      for (final item in json['pendientes'] as List<dynamic>) {
        _pendientes.add(
          AciertoPendiente.fromJson(Map<String, dynamic>.from(item as Map)),
        );
      }
    } catch (error) {
      debugPrint('No se pudo leer el paquete sin conexión: $error');
      _paquetes.clear();
      _pendientes.clear();
    }
  }

  Future<void> _guardar() async {
    final uid = _uid;
    if (kIsWeb || uid == null) return;
    final archivo = await _archivo(uid);
    final temporal = File('${archivo.path}.tmp');
    await temporal.writeAsString(
      jsonEncode({
        'paquetes': [for (final p in _paquetes.values) p.toJson()],
        'pendientes': [for (final p in _pendientes) p.toJson()],
      }),
    );
    if (await archivo.exists()) await archivo.delete();
    await temporal.rename(archivo.path);
  }

  PaqueteGenero? de(Genero genero) => _paquetes[genero];

  bool tienePendiente(String id) => _pendientes.any((item) => item.id == id);

  Future<void> agregarPendiente(AciertoPendiente acierto) async {
    if (tienePendiente(acierto.id)) return;
    _pendientes.add(acierto);
    await _guardar();
  }

  /// Envía los aciertos hechos sin conexión y baja los paquetes que faltan o
  /// vencieron. Una sola vez a la vez; los fallos se registran y no
  /// interrumpen al jugador.
  Future<void> actualizar(RepositorioConPaquete repo) {
    if (kIsWeb) return Future.value();
    return _enCurso ??= _actualizar(repo).whenComplete(() => _enCurso = null);
  }

  Future<void> _actualizar(RepositorioConPaquete repo) async {
    final uid = repo.uid;
    if (uid == null) return;
    await cargar(uid);
    try {
      await _enviarPendientes(repo);
      for (final genero in Genero.reales) {
        final actual = _paquetes[genero];
        if (actual != null &&
            DateTime.now().difference(actual.fecha) < vigencia) {
          continue;
        }
        try {
          await _descargar(repo, genero);
        } catch (error) {
          // Sin red se corta todo; otro fallo solo deja a este género sin
          // paquete hasta el próximo inicio.
          if (esErrorDeRed(error)) rethrow;
          debugPrint('Sin paquete sin conexión para ${genero.id}: $error');
        }
      }
    } catch (error) {
      // Sin red a mitad de camino: queda lo ya guardado.
      debugPrint('No se pudo preparar el modo sin conexión: $error');
    }
  }

  Future<void> _enviarPendientes(RepositorioConPaquete repo) async {
    for (final acierto in List.of(_pendientes)) {
      try {
        if (acierto.esIntro) {
          await repo.enviarRespuestaIntroRemota(
            introId: acierto.id,
            respuesta: acierto.respuesta,
          );
        } else {
          final partida = await repo.iniciarNivelRemoto(acierto.id);
          await repo.enviarRespuestaRemota(
            gameId: partida.gameId,
            respuesta: acierto.respuesta,
          );
        }
      } catch (error) {
        // Sin red se reintenta en el próximo inicio; cualquier otro rechazo
        // (nivel bloqueado, intro que nunca fue suya) descarta el acierto.
        if (esErrorDeRed(error)) rethrow;
        debugPrint('Acierto sin conexión descartado (${acierto.id}): $error');
      }
      _pendientes.remove(acierto);
      await _guardar();
    }
  }

  Future<void> _descargar(RepositorioConPaquete repo, Genero genero) async {
    final respuesta = await repo.paqueteOfflineRemoto(genero);
    PaqueteNivel? nivel;
    final datosNivel = respuesta['nivel'];
    if (datosNivel is Map) {
      nivel = await _descargarNivel(
        repo,
        genero,
        Map<String, dynamic>.from(datosNivel),
      );
    }
    PaqueteIntro? intro;
    final datosIntro = respuesta['intro'];
    if (datosIntro is Map) {
      intro = await _descargarIntro(
        genero,
        Map<String, dynamic>.from(datosIntro),
      );
    }
    _paquetes[genero] = PaqueteGenero(
      genero: genero,
      fecha: DateTime.now(),
      nivel: nivel,
      intro: intro,
    );
    await _guardar();
  }

  Future<PaqueteNivel> _descargarNivel(
    RepositorioConPaquete repo,
    Genero genero,
    Map<String, dynamic> datos,
  ) async {
    final nivel = Nivel.fromJson(datos['nivel'] as Map<String, dynamic>);
    final gameId = datos['gameId'] as String;
    final versiones = <String, String>{};
    // Mismas claves que usa game_screen al reproducir en línea.
    for (final instrumento in nivel.instrumentos) {
      final audio = await repo.obtenerAudioRemoto(
        gameId: gameId,
        tipo: 'stem',
        instrumento: instrumento.id,
      );
      await _audio.descargarYGuardar(
        audio.url,
        'level:${nivel.id}:stem:${instrumento.id}:${audio.version}',
        genero: genero,
      );
      versiones[instrumento.id] = audio.version;
    }
    final instrumental = await repo.obtenerAudioRemoto(
      gameId: gameId,
      tipo: 'instrumentalSong',
    );
    await _audio.descargarYGuardar(
      instrumental.url,
      'song:${nivel.cancionId}:instrumentalSong:${instrumental.version}',
      genero: genero,
    );
    versiones['instrumental'] = instrumental.version;
    // La original suena al acertar; sin ella, el nivel se juega igual.
    try {
      final original = await repo.obtenerAudioRemoto(
        gameId: gameId,
        tipo: 'fullSong',
      );
      await _audio.descargarYGuardar(
        original.url,
        claveOriginal(nivel.id),
        genero: genero,
      );
    } catch (error) {
      debugPrint('No se pudo guardar la canción original: $error');
    }
    return PaqueteNivel(
      nivel: nivel,
      huella: datos['huella'] as String,
      versiones: versiones,
      titulo: datos['titulo'] as String?,
      artista: datos['artista'] as String?,
    );
  }

  Future<PaqueteIntro> _descargarIntro(
    Genero genero,
    Map<String, dynamic> datos,
  ) async {
    final id = datos['id'] as String;
    final urls = Map<String, dynamic>.from(datos['urls'] as Map);
    // Mismas claves que usa intros_screen al reproducir en línea.
    final claves = {
      'intro': 'intro:v3:$id',
      'fullSong': 'intro:$id:full',
      'cover': 'intro:$id:cover',
    };
    for (final MapEntry(key: tipo, value: clave) in claves.entries) {
      final url = urls[tipo];
      if (url is! String || url.isEmpty) continue;
      try {
        await _audio.descargarYGuardar(url, clave, genero: genero);
      } catch (error) {
        // Solo la intro es imprescindible.
        if (tipo == 'intro') rethrow;
        debugPrint('No se pudo guardar $tipo de $id: $error');
      }
    }
    return PaqueteIntro(
      id: id,
      propia: datos['propia'] as bool? ?? false,
      huella: datos['huella'] as String,
      titulo: datos['titulo'] as String?,
      artista: datos['artista'] as String?,
    );
  }

  /// Clave de caché de la canción original de un nivel guardado para jugar
  /// sin conexión (en línea no se guarda: se pide un enlace cada vez).
  static String claveOriginal(String nivelId) => 'offline:full:$nivelId';

  /// Archivo de la canción original guardada, si la hay.
  Future<File?> originalDe(Genero genero, String nivelId) =>
      _audio.cachedFile(claveOriginal(nivelId), genero: genero);
}
