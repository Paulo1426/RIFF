import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'audio_service.dart';
import 'firebase_game_repository.dart';
import 'offline_game_store.dart';

/// Una intro obtenida, descargada para jugarla sin conexión.
class OfflineIntroData {
  const OfflineIntroData({
    required this.id,
    required this.titulo,
    required this.artista,
    required this.respuesta,
    required this.introPath,
    required this.fullPath,
    this.coverPath,
  });

  final String id;
  final String? titulo;
  final String? artista;
  // Respuesta normalizada por el servidor.
  final String respuesta;
  final String introPath;
  final String fullPath;
  final String? coverPath;

  bool acierta(String answer) =>
      OfflineGameStore.normalizeAnswer(answer) ==
      OfflineGameStore.normalizeAnswer(respuesta);

  factory OfflineIntroData.fromJson(Map<String, dynamic> json) =>
      OfflineIntroData(
        id: json['id'] as String,
        titulo: json['titulo'] as String?,
        artista: json['artista'] as String?,
        respuesta: json['respuesta'] as String,
        introPath: json['introPath'] as String,
        fullPath: json['fullPath'] as String,
        coverPath: json['coverPath'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': titulo,
    'artista': artista,
    'respuesta': respuesta,
    'introPath': introPath,
    'fullPath': fullPath,
    'coverPath': coverPath,
  };
}

class OfflineIntroSnapshot {
  const OfflineIntroSnapshot({
    required this.uid,
    required this.estadoJson,
    required this.intros,
    required this.pendientes,
  });

  final String uid;
  final Map<String, dynamic> estadoJson;
  final Map<String, OfflineIntroData> intros;
  // Aciertos sin conexión que faltan por enviar: {introId, answer}.
  final List<Map<String, String>> pendientes;

  EstadoIntros get estado => EstadoIntros.fromJson(estadoJson);

  factory OfflineIntroSnapshot.fromJson(Map<String, dynamic> json) =>
      OfflineIntroSnapshot(
        uid: json['uid'] as String,
        estadoJson: Map<String, dynamic>.from(json['estado'] as Map),
        intros: {
          for (final item in json['intros'] as List<dynamic>)
            (item as Map)['id'] as String: OfflineIntroData.fromJson(
              Map<String, dynamic>.from(item),
            ),
        },
        pendientes: (json['pendientes'] as List<dynamic>)
            .map((item) => Map<String, String>.from(item as Map))
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'estado': estadoJson,
    'intros': [for (final intro in intros.values) intro.toJson()],
    'pendientes': pendientes,
  };

  /// Marca la intro como adivinada y deja el acierto pendiente de sincronizar.
  OfflineIntroSnapshot completadaLocalmente(String introId, String answer) {
    final data = intros[introId];
    if (data == null) {
      throw StateError('La intro no está descargada en este dispositivo');
    }
    final estado = Map<String, dynamic>.from(estadoJson);
    estado['intros'] = [
      for (final item in estadoJson['intros'] as List<dynamic>)
        (item as Map)['id'] == introId
            ? {
                ...Map<String, dynamic>.from(item),
                'estado': 'completada',
                'titulo': data.titulo,
                'artista': data.artista,
              }
            : item,
    ];
    return OfflineIntroSnapshot(
      uid: uid,
      estadoJson: estado,
      intros: intros,
      pendientes: [
        ...pendientes.where((item) => item['introId'] != introId),
        {'introId': introId, 'answer': answer},
      ],
    );
  }

  OfflineIntroSnapshot sinPendiente(String introId) => OfflineIntroSnapshot(
    uid: uid,
    estadoJson: estadoJson,
    intros: intros,
    pendientes: pendientes
        .where((item) => item['introId'] != introId)
        .toList(growable: false),
  );
}

class OfflineIntroStore {
  OfflineIntroStore(this._repository, this._audio);

  final FirebaseGameRepository _repository;
  final AudioService _audio;
  // Una sola descarga a la vez aunque la pidan el inicio y la pantalla.
  static Future<OfflineIntroSnapshot?>? _enCurso;

  /// Borra la copia guardada de [uid] (al reiniciar el progreso).
  Future<void> borrar(String uid) async {
    final archivo = await _file(uid);
    if (await archivo.exists()) await archivo.delete();
  }

  Future<File> _file(String uid) async {
    final directory = await getApplicationSupportDirectory();
    final store = Directory('${directory.path}/offline_intros');
    await store.create(recursive: true);
    final safeUid = base64Url.encode(utf8.encode(uid)).replaceAll('=', '');
    return File('${store.path}/$safeUid.json');
  }

  Future<void> save(OfflineIntroSnapshot snapshot) async {
    final file = await _file(snapshot.uid);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(snapshot.toJson()));
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  Future<OfflineIntroSnapshot?> load(String uid) async {
    final file = await _file(uid);
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic> || json['uid'] != uid) return null;
      return OfflineIntroSnapshot.fromJson(json);
    } on FormatException {
      return null;
    } on TypeError {
      // Copia dañada: se vuelve a descargar con conexión.
      return null;
    }
  }

  /// Envía los aciertos pendientes y descarga intro, original y portada de
  /// cada intro obtenida. Ya descargadas no se bajan otra vez (caché por id).
  Future<OfflineIntroSnapshot?> actualizar(String uid) =>
      _enCurso ??= _actualizar(uid).whenComplete(() => _enCurso = null);

  Future<OfflineIntroSnapshot?> _actualizar(String uid) async {
    var actual = await load(uid);
    for (final pendiente
        in actual?.pendientes ?? const <Map<String, String>>[]) {
      try {
        await _repository.sincronizarIntroOffline(
          introId: pendiente['introId']!,
          respuesta: pendiente['answer']!,
        );
      } on GameRepositoryException catch (error) {
        // Rechazo definitivo (respuesta o intro inválida): se descarta para
        // no bloquear la sincronización; los fallos temporales se reintentan.
        if (error.statusCode == 429 || error.statusCode >= 500) rethrow;
      }
      actual = actual!.sinPendiente(pendiente['introId']!);
      await save(actual);
    }
    final paquete = await _repository.descargarPaqueteIntros();
    final intros = <String, OfflineIntroData>{};
    for (final raw in paquete['intros'] as List<dynamic>) {
      final item = Map<String, dynamic>.from(raw as Map);
      final id = item['id'] as String;
      final urls = Map<String, dynamic>.from(item['urls'] as Map);
      final cover = urls['cover'] as String?;
      final archivos = await Future.wait([
        _audio.descargarYGuardar(urls['intro'] as String, 'intro:$id'),
        _audio.descargarYGuardar(urls['fullSong'] as String, 'intro:$id:full'),
        if (cover != null)
          _audio
              .descargarYGuardar(cover, 'intro:$id:cover')
              .then<File?>((file) => file, onError: (_) => null),
      ]);
      intros[id] = OfflineIntroData(
        id: id,
        titulo: item['titulo'] as String?,
        artista: item['artista'] as String?,
        respuesta: item['respuesta'] as String,
        introPath: archivos[0]!.path,
        fullPath: archivos[1]!.path,
        coverPath: archivos.length > 2 ? archivos[2]?.path : null,
      );
    }
    final snapshot = OfflineIntroSnapshot(
      uid: uid,
      estadoJson: Map<String, dynamic>.from(paquete['estado'] as Map),
      intros: intros,
      pendientes: const [],
    );
    await save(snapshot);
    return snapshot;
  }
}
