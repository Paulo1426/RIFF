import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/genero.dart';

class AudioService {
  // [carpeta] y [cliente] se cambian solo en los tests.
  AudioService({Future<Directory> Function()? carpeta, http.Client? cliente})
    : _carpeta = carpeta ?? getApplicationSupportDirectory,
      _httpClient = cliente ?? http.Client();

  final Future<Directory> Function() _carpeta;
  final http.Client _httpClient;
  final List<AudioPlayer> _players = [];
  bool _reproduciendo = false;
  Completer<void>? _cancelPlayback;
  int _playbackGeneration = 0;

  bool get reproduciendo => _reproduciendo;

  // Todos los reproductores van sincronizados: el primero marca el tiempo.
  Duration get posicion =>
      _players.isEmpty ? Duration.zero : _players.first.position;
  Duration? get duracion => _players.isEmpty ? null : _players.first.duration;

  Future<void> buscar(Duration posicion) =>
      Future.wait(_players.map((player) => player.seek(posicion)));

  // Cada género guarda aparte: "intro:cancion-01" existe en todos. Se aplica
  // al entrar, antes de cualquier await.
  static String _conGenero(String key) => '${generoActivo.prefijo}$key';

  Future<File?> cachedFile(String key) async {
    final file = await _cacheFile(_conGenero(key));
    return await file.exists() ? file : null;
  }

  Future<File> descargarYGuardar(String url, String key) =>
      _ensureCached(url, _conGenero(key));

  Future<void> reproducir({
    required List<String> urls,
    List<String?>? cacheKeys,
    Duration inicio = Duration.zero,
    Duration? duracion = const Duration(seconds: 5),
  }) async {
    if (urls.isEmpty) {
      throw ArgumentError('No hay audios para reproducir');
    }
    if (cacheKeys != null && cacheKeys.length != urls.length) {
      throw ArgumentError('Debe existir una clave de caché por cada audio');
    }
    final claves = cacheKeys
        ?.map((key) => key == null ? null : _conGenero(key))
        .toList(growable: false);
    final playbackGeneration = ++_playbackGeneration;
    await _detenerPlayers();
    if (playbackGeneration != _playbackGeneration) return;
    final cancellation = Completer<void>();
    _cancelPlayback = cancellation;
    AudioSession? audioSession;
    var audioSessionActive = false;
    try {
      for (final url in urls) {
        if (!identical(_cancelPlayback, cancellation)) return;
        final player = AudioPlayer();
        _players.add(player);
        final index = _players.length - 1;
        final cacheKey = claves == null ? null : claves[index];
        if (cacheKey == null) {
          final uri = Uri.parse(url);
          if (uri.scheme == 'file') {
            await player.setFilePath(uri.toFilePath());
          } else {
            await player.setUrl(url);
          }
        } else {
          final file = await _ensureCached(url, cacheKey);
          await player.setFilePath(file.path);
        }
        if (!identical(_cancelPlayback, cancellation)) return;
        if (duracion == null) {
          await player.seek(inicio);
        } else {
          // El clip marca el fin del fragmento, así pausar no consume su duración.
          await player.setClip(start: inicio, end: inicio + duracion);
        }
      }
      if (!identical(_cancelPlayback, cancellation)) return;
      audioSession = await AudioSession.instance;
      await audioSession.configure(const AudioSessionConfiguration.music());
      audioSessionActive = await audioSession.setActive(true);
      if (!audioSessionActive) {
        throw StateError('El sistema no permitió activar la sesión de audio');
      }
      if (!identical(_cancelPlayback, cancellation)) return;
      _reproduciendo = true;
      final players = List<AudioPlayer>.from(_players);
      // play() también termina al pausar; solo se usa para propagar errores.
      final playErrors = Future.wait(
        players.map((player) => player.play()),
      ).then<void>((_) => Completer<void>().future);
      final completed = Future.wait(
        players.map(
          (player) => player.processingStateStream.firstWhere(
            (state) => state == ProcessingState.completed,
          ),
        ),
      ).then<void>((_) {});
      await Future.any<void>([completed, playErrors, cancellation.future]);
    } catch (error) {
      if (identical(_cancelPlayback, cancellation)) rethrow;
    } finally {
      if (identical(_cancelPlayback, cancellation)) {
        await detener();
      }
      if (audioSessionActive) {
        await audioSession!.setActive(false);
      }
    }
  }

  Future<void> pausar() =>
      Future.wait(_players.map((player) => player.pause()));

  void reanudar() {
    for (final player in _players) {
      unawaited(player.play());
    }
  }

  Future<void> detener() async {
    _playbackGeneration++;
    await _detenerPlayers();
  }

  Future<File> _cacheFile(String key) async {
    final directory = await _carpeta();
    final cacheDirectory = Directory('${directory.path}/audio_cache');
    await cacheDirectory.create(recursive: true);
    final fileName = sha256.convert(utf8.encode(key)).toString();
    return File('${cacheDirectory.path}/$fileName.mp3');
  }

  // Descargas en curso por clave: si dos niveles piden el mismo archivo a la
  // vez (misma canción), comparten una descarga en vez de escribir los dos el
  // mismo .download y dañarlo.
  final Map<String, Future<File>> _enCurso = {};

  Future<File> _ensureCached(String url, String key) {
    final enCurso = _enCurso[key];
    if (enCurso != null) return enCurso;
    final descarga = _descargar(url, key);
    _enCurso[key] = descarga;
    // Con llaves: una flecha devolvería el Future quitado del mapa y
    // whenComplete lo esperaría, colgando la descarga para siempre.
    descarga.whenComplete(() {
      _enCurso.remove(key);
    }).ignore();
    return descarga;
  }

  Future<File> _descargar(String url, String key) async {
    final file = await _cacheFile(key);
    if (await file.exists() && await file.length() > 0) return file;

    final partialFile = File('${file.path}.download');
    if (await partialFile.exists()) await partialFile.delete();
    final response = await _httpClient.send(
      http.Request('GET', Uri.parse(url)),
    );
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'No se pudo descargar el audio (${response.statusCode})',
        uri: Uri.parse(url),
      );
    }
    try {
      await response.stream.pipe(partialFile.openWrite());
      if (!await partialFile.exists() || await partialFile.length() == 0) {
        throw const FileSystemException('El audio descargado está vacío');
      }
      return await partialFile.rename(file.path);
    } catch (_) {
      if (await partialFile.exists()) await partialFile.delete();
      rethrow;
    }
  }

  Future<void> _detenerPlayers() async {
    _reproduciendo = false;
    final cancellation = _cancelPlayback;
    _cancelPlayback = null;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.complete();
    }
    final players = List<AudioPlayer>.from(_players);
    _players.clear();
    await Future.wait(
      players.map((player) async {
        try {
          await player.stop();
        } finally {
          await player.dispose();
        }
      }),
    );
  }
}
