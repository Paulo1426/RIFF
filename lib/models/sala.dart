import 'nivel.dart';

/// Contrarreloj: 5 minutos, gana quien sume más puntos. Eliminación: sin
/// tiempo, en cada ronda sale el último en adivinar.
enum ModoSala { contrarreloj, eliminacion }

enum EstadoSala { esperando, jugando, terminada }

/// Instrumentos: juego principal (gratis, reparte fichas). Intros: cuesta
/// [precioSalaIntros] fichas crearla o entrar.
enum TipoSala { instrumentos, intros }

const precioSalaIntros = 5;

class JugadorSala {
  const JugadorSala({
    required this.uid,
    required this.nombre,
    required this.puntos,
    required this.aciertos,
    required this.eliminado,
    required this.abandono,
    this.eliminadoEnRonda,
  });

  final String uid;
  final String nombre;
  final int puntos;
  final int aciertos;
  final bool eliminado;
  final bool abandono;
  final int? eliminadoEnRonda;

  factory JugadorSala.fromMap(String uid, Map<String, dynamic> map) =>
      JugadorSala(
        uid: uid,
        nombre: map['nombre'] as String? ?? 'Jugador',
        puntos: (map['puntos'] as num?)?.toInt() ?? 0,
        aciertos: (map['aciertos'] as num?)?.toInt() ?? 0,
        eliminado: map['eliminado'] as bool? ?? false,
        abandono: map['abandono'] as bool? ?? false,
        eliminadoEnRonda: (map['eliminadoEnRonda'] as num?)?.toInt(),
      );
}

/// Documento `salas/{codigo}` de Firestore; solo el servidor lo modifica.
class Sala {
  const Sala({
    required this.codigo,
    required this.creadorUid,
    required this.publica,
    required this.tipo,
    required this.modo,
    required this.dificultad,
    required this.maxJugadores,
    required this.estado,
    required this.jugadores,
    required this.ronda,
    required this.acertaronRonda,
    this.finEn,
    this.ganadorUid,
    this.premios = const {},
  });

  final String codigo;
  final String creadorUid;
  final bool publica;
  final TipoSala tipo;
  final ModoSala modo;
  final Dificultad dificultad;
  final int maxJugadores;
  final EstadoSala estado;
  // En orden de llegada.
  final List<JugadorSala> jugadores;
  final int ronda;
  final List<String> acertaronRonda;
  final DateTime? finEn;
  final String? ganadorUid;
  // Fichas repartidas al terminar una sala de instrumentos, por uid.
  final Map<String, int> premios;

  bool get llena => jugadores.length >= maxJugadores;

  JugadorSala? jugador(String uid) =>
      jugadores.where((j) => j.uid == uid).firstOrNull;

  /// Tabla de posiciones: por puntos en contrarreloj; en eliminación, los
  /// que siguen en juego primero y luego quien cayó más tarde.
  List<JugadorSala> get clasificacion {
    final lista = [...jugadores];
    if (modo == ModoSala.contrarreloj) {
      lista.sort(
        (a, b) => b.puntos != a.puntos
            ? b.puntos - a.puntos
            : b.aciertos - a.aciertos,
      );
    } else {
      int caida(JugadorSala j) =>
          j.eliminado ? j.eliminadoEnRonda ?? 0 : 1 << 30;
      lista.sort((a, b) => caida(b) - caida(a));
    }
    return lista;
  }

  factory Sala.fromMap(Map<String, dynamic> map) {
    final jugadores = Map<String, dynamic>.from(map['jugadores'] as Map? ?? {});
    final orden = (map['orden'] as List<dynamic>? ?? []).cast<String>();
    return Sala(
      codigo: map['codigo'] as String,
      creadorUid: map['creadorUid'] as String,
      publica: map['publica'] as bool? ?? false,
      tipo: TipoSala.values.byName(map['tipo'] as String? ?? 'instrumentos'),
      modo: ModoSala.values.byName(map['modo'] as String),
      dificultad: DificultadExtension.fromId(map['dificultad'] as String),
      maxJugadores: (map['maxJugadores'] as num?)?.toInt() ?? 5,
      estado: EstadoSala.values.byName(map['estado'] as String),
      jugadores: [
        for (final uid in orden)
          if (jugadores[uid] case final Map<dynamic, dynamic> datos)
            JugadorSala.fromMap(uid, Map<String, dynamic>.from(datos)),
      ],
      ronda: (map['ronda'] as num?)?.toInt() ?? 0,
      acertaronRonda: (map['acertaronRonda'] as List<dynamic>? ?? [])
          .cast<String>(),
      finEn: DateTime.tryParse(map['finEn'] as String? ?? ''),
      ganadorUid: map['ganadorUid'] as String?,
      premios: (map['premios'] as Map? ?? {}).map(
        (uid, fichas) => MapEntry(uid as String, (fichas as num).toInt()),
      ),
    );
  }
}

/// Canción que le toca al jugador en la sala, o por qué no tiene ninguna.
class PartidaSala {
  const PartidaSala({
    required this.estado,
    this.gameId,
    this.nivel,
    this.introId,
    this.indice = 0,
    this.compras = const {},
    this.melodiaDescubierta = false,
    this.esperando = false,
    this.eliminado = false,
  });

  final EstadoSala estado;
  final String? gameId;
  final Nivel? nivel;
  // Salas de intros: la intro que toca en lugar de un nivel.
  final String? introId;
  final int indice;
  // Instrumentos ya comprados y su precio, al retomar la canción.
  final Map<String, int> compras;
  final bool melodiaDescubierta;
  // Eliminación: ya adivinó y espera a que termine la ronda.
  final bool esperando;
  final bool eliminado;

  factory PartidaSala.fromJson(Map<String, dynamic> json) => PartidaSala(
    estado: EstadoSala.values.byName(json['estado'] as String),
    gameId: json['gameId'] as String?,
    nivel: json['nivel'] == null
        ? null
        : Nivel.fromJson(json['nivel'] as Map<String, dynamic>),
    introId: json['introId'] as String?,
    indice: (json['indice'] as num?)?.toInt() ?? 0,
    compras: (json['compras'] as Map<String, dynamic>? ?? {}).map(
      (tipo, precio) => MapEntry(tipo, (precio as num).toInt()),
    ),
    melodiaDescubierta: json['melodiaDescubierta'] as bool? ?? false,
    esperando: json['esperando'] as bool? ?? false,
    eliminado: json['eliminado'] as bool? ?? false,
  );
}
