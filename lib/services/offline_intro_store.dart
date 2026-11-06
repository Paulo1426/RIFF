import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import '../models/genero.dart';

import 'firebase_game_repository.dart';
import 'offline_game_store.dart';

/// Una intro obtenida, descargada para jugarla sin conexión.
class OfflineIntroData {
  const OfflineIntroData({
    required this.id,
    required this.titulo,
    required this.artista,
    required this.respuestaHash,
    required this.introPath,
    this.fullPath,
    this.coverPath,
  });

  final String id;
  // Título, artista, original y portada solo llegan de intros ya adivinadas.
  final String? titulo;
  final String? artista;
  final String respuestaHash;
  final String introPath;
  final String? fullPath;
  final String? coverPath;

  bool acierta(String answer) =>
      OfflineGameStore.huella(id, answer) == respuestaHash;

  factory OfflineIntroData.fromJson(Map<String, dynamic> json) =>
      OfflineIntroData(
        id: json['id'] as String,
        titulo: json['titulo'] as String?,
        artista: json['artista'] as String?,
        // Copias guardadas antes de la huella traen la respuesta en texto.
        respuestaHash:
            json['respuestaHash'] as String? ??
            OfflineGameStore.huella(
              json['id'] as String,
              json['respuesta'] as String,
            ),
        introPath: json['introPath'] as String,
        fullPath: json['fullPath'] as String?,
        coverPath: json['coverPath'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': titulo,
    'artista': artista,
    'respuestaHash': respuestaHash,
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
  OfflineIntroStore(this._repository);

  final FirebaseGameRepository _repository;
  // Una sola descarga a la vez por género aunque la pidan el inicio y la
  // pantalla.
  static final _enCurso = <Genero, Future<OfflineIntroSnapshot?>>{};

  /// Borra las copias de [uid] en todos los géneros (al reiniciar el progreso).
  Future<void> borrar(String uid) async {
    if (kIsWeb) return; // web: sin copia offline
    for (final genero in Genero.values) {
      final archivo = await _file(uid, genero);
      if (await archivo.exists()) await archivo.delete();
    }
  }

  Future<File> _file(String uid, [Genero? genero]) async {
    // Una copia por género; se lee antes del await.
    final prefijo = (genero ?? generoActivo).prefijo.replaceAll(':', '_');
    final directory = await getApplicationSupportDirectory();
    final store = Directory('${directory.path}/offline_intros');
    await store.create(recursive: true);
    final safeUid = base64Url.encode(utf8.encode(uid)).replaceAll('=', '');
    return File('${store.path}/$prefijo$safeUid.json');
  }

  Future<void> save(OfflineIntroSnapshot snapshot) async {
    if (kIsWeb) return;
    final file = await _file(snapshot.uid);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(snapshot.toJson()));
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  Future<OfflineIntroSnapshot?> load(String uid) async {
    if (kIsWeb) return null;
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

  /// Envía los aciertos hechos sin conexión. Los audios no se bajan aquí: se
  /// guardan en la caché al sonar (ver IntroGameScreen).
  Future<OfflineIntroSnapshot?> actualizar(String uid) {
    final genero = generoActivo;
    return _enCurso[genero] ??= _actualizar(
      uid,
      genero,
    ).whenComplete(() => _enCurso.remove(genero));
  }

  Future<OfflineIntroSnapshot?> _actualizar(String uid, Genero genero) async {
    // Cada llamada al servidor o al disco lee el género activo:
    // si el jugador cambió de género, se para antes de mezclar los dos.
    void seguir() {
      if (generoActivo != genero) throw StateError('Cambió el género');
    }

    var actual = await load(uid);
    for (final pendiente
        in actual?.pendientes ?? const <Map<String, String>>[]) {
      seguir();
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
      seguir();
      await save(actual);
    }
    return actual;
  }
}
