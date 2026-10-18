import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/nivel.dart';
import '../models/sala.dart';

class GameRepositoryException implements Exception {
  const GameRepositoryException({
    required this.statusCode,
    required this.message,
  });

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class NivelAsignado {
  const NivelAsignado({
    required this.nivel,
    required this.completado,
    required this.puedeIniciar,
  });

  final Nivel nivel;
  final bool completado;
  final bool puedeIniciar;

  factory NivelAsignado.fromJson(Map<String, dynamic> json) {
    return NivelAsignado(
      nivel: Nivel.fromJson(json['nivel'] as Map<String, dynamic>),
      completado: json['completado'] as bool? ?? false,
      puedeIniciar: json['puede_iniciar'] as bool? ?? false,
    );
  }
}

class PartidaIniciada {
  const PartidaIniciada({required this.gameId, required this.nivel});

  final String gameId;
  final Nivel nivel;
}

class ProgresoDificultadRemoto {
  const ProgresoDificultadRemoto({
    required this.dificultad,
    required this.desbloqueada,
    required this.completados,
    required this.total,
  });

  final Dificultad dificultad;
  final bool desbloqueada;
  final int completados;
  final int total;

  factory ProgresoDificultadRemoto.fromJson(Map<String, dynamic> json) {
    return ProgresoDificultadRemoto(
      dificultad: DificultadExtension.fromId(json['dificultad'] as String),
      desbloqueada: json['desbloqueada'] as bool,
      completados: (json['completados'] as num).toInt(),
      total: (json['total'] as num).toInt(),
    );
  }
}

class EstadoJuegoRemoto {
  const EstadoJuegoRemoto({
    required this.dificultades,
    required this.dificultadActiva,
    required this.niveles,
    required this.nivelesRepetibles,
  });

  final List<ProgresoDificultadRemoto> dificultades;
  final Dificultad dificultadActiva;
  final List<NivelAsignado> niveles;
  final List<NivelAsignado> nivelesRepetibles;

  factory EstadoJuegoRemoto.fromJson(Map<String, dynamic> json) {
    return EstadoJuegoRemoto(
      dificultades: (json['dificultades'] as List<dynamic>)
          .map(
            (item) =>
                ProgresoDificultadRemoto.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      dificultadActiva: DificultadExtension.fromId(
        json['dificultad_activa'] as String,
      ),
      niveles: (json['niveles'] as List<dynamic>)
          .map((item) => NivelAsignado.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      nivelesRepetibles: (json['niveles_repetibles'] as List<dynamic>? ?? [])
          .map((item) => NivelAsignado.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class ResultadoCompraInstrumento {
  const ResultadoCompraInstrumento({
    required this.presupuestoRestante,
    required this.instrumentosComprados,
    required this.melodiaDescubierta,
    required this.compraRealizada,
    required this.precioInstrumento,
  });

  final int presupuestoRestante;
  final List<String> instrumentosComprados;
  final bool melodiaDescubierta;
  final bool compraRealizada;
  final int precioInstrumento;

  factory ResultadoCompraInstrumento.fromJson(Map<String, dynamic> json) =>
      ResultadoCompraInstrumento(
        presupuestoRestante: (json['presupuestoRestante'] as num).toInt(),
        instrumentosComprados: (json['instrumentosComprados'] as List<dynamic>)
            .cast<String>(),
        melodiaDescubierta: json['melodiaDescubierta'] as bool,
        compraRealizada: json['compraRealizada'] as bool,
        precioInstrumento: (json['precioInstrumento'] as num).toInt(),
      );
}

class FirebaseGameRepository {
  FirebaseGameRepository({
    FirebaseAuth? auth,
    http.Client? client,
    String? supabaseUrl,
    String? supabaseAnonKey,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _client = client ?? http.Client(),
       _supabaseUrl =
           supabaseUrl ?? const String.fromEnvironment('SUPABASE_URL'),
       _supabaseAnonKey =
           supabaseAnonKey ?? const String.fromEnvironment('SUPABASE_ANON_KEY');

  final FirebaseAuth _auth;
  final http.Client _client;
  final String _supabaseUrl;
  final String _supabaseAnonKey;

  // Usuario con sesión; null si no hay.
  String? get uid => _auth.currentUser?.uid;

  Future<EstadoJuegoRemoto> cargarEstado() async {
    final response = await _post({'action': 'progress'});
    return EstadoJuegoRemoto.fromJson(
      response['estado'] as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> descargarPaqueteOffline() async {
    final response = await _post({'action': 'offlineBundle'});
    final bundle = response['bundle'];
    if (bundle is! Map<String, dynamic>) {
      throw const FormatException('El servicio no devolvió el paquete offline');
    }
    return bundle;
  }

  Future<void> sincronizarNivelOffline({
    required String levelId,
    required String respuesta,
  }) async {
    await _post({
      'action': 'completeOfflineLevel',
      'levelId': levelId,
      'answer': respuesta,
    });
  }

  Future<PartidaIniciada> iniciarNivel(String nivelId) async {
    final response = await _post({'action': 'startLevel', 'levelId': nivelId});
    return PartidaIniciada(
      gameId: response['gameId'] as String,
      nivel: Nivel.fromJson(response['nivel'] as Map<String, dynamic>),
    );
  }

  Future<void> finalizarSesionInvitado() async {
    await _post({'action': 'endGuestSession'});
  }

  Future<void> iniciarSesionInvitado() async {
    await _post({'action': 'startGuestSession'});
  }

  Future<ResultadoRespuesta> enviarRespuesta({
    required String gameId,
    required String respuesta,
  }) async {
    final response = await _post({
      'action': 'submitAnswer',
      'gameId': gameId,
      'answer': respuesta,
    });
    return ResultadoRespuesta(
      correcta: response['correct'] as bool,
      titulo: response['titulo'] as String?,
      artista: response['artista'] as String?,
      monedas: (response['monedas'] as num?)?.toInt() ?? 0,
      puntos: (response['puntos'] as num?)?.toInt() ?? 0,
    );
  }

  // --- Salas de "Desafía a tus amigos" ---

  Future<String> crearSala({
    required TipoSala tipo,
    required ModoSala modo,
    required Dificultad dificultad,
    required bool publica,
  }) async {
    final response = await _post({
      'action': 'crearSala',
      'tipo': tipo.name,
      'modo': modo.name,
      'dificultad': dificultad.id,
      'publica': publica,
    });
    return response['codigo'] as String;
  }

  Future<void> unirseSala(String codigo) =>
      _post({'action': 'unirseSala', 'codigo': codigo});

  Future<void> salirSala(String codigo) =>
      _post({'action': 'salirSala', 'codigo': codigo});

  Future<void> iniciarSala(String codigo) =>
      _post({'action': 'iniciarSala', 'codigo': codigo});

  Future<void> saltarCancionSala(String codigo) =>
      _post({'action': 'saltarCancionSala', 'codigo': codigo});

  /// Cierra la sala si ya se acabó el tiempo de contrarreloj.
  Future<void> revisarSala(String codigo) =>
      _post({'action': 'revisarSala', 'codigo': codigo});

  /// [tipo]: 'intro', o 'fullSong' y 'cover' cuando ya se adivinó.
  Future<String> audioIntroSala({
    required String codigo,
    required String introId,
    required String tipo,
  }) async {
    final response = await _post({
      'action': 'audioIntroSala',
      'codigo': codigo,
      'introId': introId,
      'type': tipo,
    });
    final url = response['url'];
    if (url is! String || url.isEmpty) {
      throw const FormatException('El servicio no devolvió una URL de audio');
    }
    return url;
  }

  Future<ResultadoRespuesta> responderIntroSala({
    required String codigo,
    required String respuesta,
  }) async {
    final response = await _post({
      'action': 'responderIntroSala',
      'codigo': codigo,
      'answer': respuesta,
    });
    return ResultadoRespuesta(
      correcta: response['correct'] as bool,
      titulo: response['titulo'] as String?,
      artista: response['artista'] as String?,
      puntos: (response['puntos'] as num?)?.toInt() ?? 0,
    );
  }

  /// Fichas del jugador en tiempo real (0 si aún no ha ganado ninguna).
  Stream<int> fichas() {
    final uid = this.uid;
    if (uid == null) return Stream.value(0);
    return FirebaseFirestore.instance
        .doc('users/$uid/fichas/saldo')
        .snapshots()
        .map((doc) => (doc.data()?['fichas'] as num?)?.toInt() ?? 0);
  }

  Future<PartidaSala> partidaSala(String codigo) async => PartidaSala.fromJson(
    await _post({'action': 'partidaSala', 'codigo': codigo}),
  );

  /// La sala en tiempo real; null si se borró (todos salieron antes de jugar).
  Stream<Sala?> escucharSala(String codigo) => FirebaseFirestore.instance
      .collection('salas')
      .doc(codigo)
      .snapshots()
      .map((doc) => doc.exists ? Sala.fromMap(doc.data()!) : null);

  /// Salas públicas que aún esperan jugadores.
  Stream<List<Sala>> salasPublicas() => FirebaseFirestore.instance
      .collection('salas')
      .where('publica', isEqualTo: true)
      .where('estado', isEqualTo: 'esperando')
      .limit(20)
      .snapshots()
      .map(
        (query) => [
          for (final doc in query.docs) Sala.fromMap(doc.data()),
        ].where((sala) => !sala.llena).toList(),
      );

  Future<ResultadoCompraInstrumento> comprarInstrumento({
    required String gameId,
    required String instrumento,
  }) async {
    final response = await _post({
      'action': 'purchaseInstrument',
      'gameId': gameId,
      'instrument': instrumento,
    });
    return ResultadoCompraInstrumento.fromJson(response);
  }

  /// URL firmada y versión del archivo (cambia si se reemplaza en Storage).
  Future<({String url, String version})> obtenerAudio({
    required String gameId,
    required String tipo,
    String? instrumento,
  }) async {
    final response = await _post({
      'gameId': gameId,
      'type': tipo,
      'instrument': instrumento,
    }, functionName: 'audio-link');
    final url = response['url'];
    if (url is! String || url.isEmpty) {
      throw const FormatException('El servicio no devolvió una URL de audio');
    }
    return (url: url, version: response['version'] as String? ?? '');
  }

  Future<EstadoIntros> cargarIntros() async =>
      EstadoIntros.fromJson(await _post({'action': 'introState'}));

  /// Gasta una moneda y saca una intro al azar; `nueva` trae su id.
  Future<EstadoIntros> sacarIntro() async =>
      EstadoIntros.fromJson(await _post({'action': 'drawIntro'}));

  Future<ResultadoRespuesta> enviarRespuestaIntro({
    required String introId,
    required String respuesta,
  }) async {
    final response = await _post({
      'action': 'submitIntroAnswer',
      'introId': introId,
      'answer': respuesta,
    });
    return ResultadoRespuesta(
      correcta: response['correct'] as bool,
      titulo: response['titulo'] as String?,
      artista: response['artista'] as String?,
    );
  }

  Future<Map<String, dynamic>> descargarPaqueteIntros() =>
      _post({'action': 'introOfflineBundle'});

  Future<void> sincronizarIntroOffline({
    required String introId,
    required String respuesta,
  }) async {
    await _post({
      'action': 'completeOfflineIntro',
      'introId': introId,
      'answer': respuesta,
    });
  }

  /// [tipo]: 'intro', 'fullSong' o 'cover'.
  Future<String> obtenerUrlIntro({
    required String introId,
    required String tipo,
  }) async {
    final response = await _post({
      'action': 'introAudio',
      'introId': introId,
      'type': tipo,
    });
    final url = response['url'];
    if (url is! String || url.isEmpty) {
      throw const FormatException('El servicio no devolvió una URL de audio');
    }
    return url;
  }

  Future<Map<String, dynamic>> _post(
    Map<String, dynamic> body, {
    String functionName = 'game-progress',
  }) async {
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      throw StateError(
        'Configura SUPABASE_URL y SUPABASE_ANON_KEY con --dart-define.',
      );
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Inicia sesión con Firebase para continuar.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Firebase no entregó un token de sesión válido.');
    }

    final response = await _client.post(
      Uri.parse(
        '${_supabaseUrl.replaceAll(RegExp(r'/+$'), '')}'
        '/functions/v1/$functionName',
      ),
      headers: {
        'Content-Type': 'application/json',
        'apikey': _supabaseAnonKey,
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Respuesta no válida del servicio de juego');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GameRepositoryException(
        statusCode: response.statusCode,
        message:
            decoded['error'] as String? ??
            'El servicio de juego respondió ${response.statusCode}.',
      );
    }
    return decoded;
  }
}

/// Resultado de enviar una respuesta; al acertar trae la canción revelada.
class ResultadoRespuesta {
  const ResultadoRespuesta({
    required this.correcta,
    this.titulo,
    this.artista,
    this.monedas = 0,
    this.puntos = 0,
  });

  final bool correcta;
  final String? titulo;
  final String? artista;
  // Monedas ganadas para "Adivina la intro" (0 al repetir un nivel).
  final int monedas;
  // Puntos ganados en una sala contrarreloj.
  final int puntos;
}

enum EstadoIntro { desbloqueada, completada }

/// Una intro ya obtenida, numerada en el orden en que salió.
class IntroAsignada {
  const IntroAsignada({
    required this.id,
    required this.numero,
    required this.estado,
    this.titulo,
    this.artista,
  });

  final String id;
  final int numero;
  final EstadoIntro estado;
  // Solo llegan cuando la intro ya fue adivinada.
  final String? titulo;
  final String? artista;

  factory IntroAsignada.fromJson(Map<String, dynamic> json) => IntroAsignada(
    id: json['id'] as String,
    numero: (json['numero'] as num).toInt(),
    estado: EstadoIntro.values.byName(json['estado'] as String),
    titulo: json['titulo'] as String?,
    artista: json['artista'] as String?,
  );
}

class EstadoIntros {
  const EstadoIntros({
    required this.monedas,
    required this.monedasGanadas,
    required this.restantes,
    required this.intros,
    this.nueva,
  });

  final int monedas;
  final int monedasGanadas;
  // Intros que aún no salen.
  final int restantes;
  final List<IntroAsignada> intros;
  // Id de la intro recién sacada.
  final String? nueva;

  factory EstadoIntros.fromJson(Map<String, dynamic> json) => EstadoIntros(
    monedas: (json['monedas'] as num).toInt(),
    monedasGanadas: (json['monedas_ganadas'] as num).toInt(),
    restantes: (json['restantes'] as num).toInt(),
    nueva: json['nueva'] as String?,
    intros: (json['intros'] as List<dynamic>)
        .map((item) => IntroAsignada.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
  );
}
