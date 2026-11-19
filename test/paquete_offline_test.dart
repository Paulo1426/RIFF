import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:riff/models/genero.dart';
import 'package:riff/models/nivel.dart';
import 'package:riff/models/pista.dart';
import 'package:riff/services/audio_service.dart';
import 'package:riff/services/firebase_game_repository.dart';
import 'package:riff/services/paquete_offline.dart';
import 'package:riff/services/repositorio_offline.dart';

class _Usuario extends Fake implements User {
  @override
  String get uid => 'uid-prueba';

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'token';
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _Usuario();
}

void main() {
  test('la huella coincide con la que calcula el servidor', () {
    // Valor calculado con la misma fórmula de game-progress
    // (sha256 de "id:respuesta normalizada").
    expect(
      huellaRespuesta('nivel-01', 'Mi Canción'),
      'ea402b7ae5ec3888a9813306ecb1b652d76c99f7438be07db5f49da61e95c925',
    );
    expect(normalizarRespuesta('  ¡Mi   CANCIÓN!  '), 'mi cancion');
    expect(
      huellaRespuesta('nivel-01', 'mi cancion'),
      huellaRespuesta('nivel-01', 'MÍ, canción'),
    );
    expect(
      huellaRespuesta('nivel-01', 'otra'),
      isNot(huellaRespuesta('nivel-01', 'mi cancion')),
    );
  });

  group('sin conexión', () {
    late Directory carpeta;
    late RepositorioConPaquete repo;
    late PaqueteOffline paquetes;
    late Nivel nivel;

    setUp(() async {
      carpeta = await Directory.systemTemp.createTemp('offline');
      addTearDown(() => carpeta.delete(recursive: true));
      nivel = Nivel.generar(
        id: 'nivel-01',
        numero: 1,
        dificultad: Dificultad.facil,
        cancionId: 'cancion-01',
        cancionTitulo: '',
        audios: const {},
      );
      final audio = AudioService(carpeta: () async => carpeta);
      paquetes = PaqueteOffline(audio, carpeta: () async => carpeta);
      // Lo que dejaría una descarga anterior.
      final archivo = File(
        '${carpeta.path}/offline_pack/'
        '${base64Url.encode(utf8.encode('uid-prueba')).replaceAll('=', '')}.json',
      );
      await archivo.create(recursive: true);
      await archivo.writeAsString(
        jsonEncode({
          'pendientes': [],
          'paquetes': [
            PaqueteGenero(
              genero: Genero.salsa,
              fecha: DateTime.now(),
              nivel: PaqueteNivel(
                nivel: nivel,
                huella: huellaRespuesta('nivel-01', 'Mi Canción'),
                versiones: const {'bateria': 'v1', 'instrumental': 'v2'},
                titulo: 'Mi Canción',
                artista: 'Yo',
              ),
              intro: PaqueteIntro(
                id: 'intro-07',
                propia: true,
                huella: huellaRespuesta('intro-07', 'Otra Canción'),
                titulo: 'Otra Canción',
                artista: 'Tú',
              ),
            ).toJson(),
          ],
        }),
      );
      repo = RepositorioConPaquete(
        paquetes: paquetes,
        audio: audio,
        auth: _Auth(),
        // Sin red: cualquier petición falla como un teléfono desconectado.
        client: MockClient((_) async => throw const SocketException('sin red')),
        supabaseUrl: 'https://x.supabase.co',
        supabaseAnonKey: 'anon',
      );
      generoActivo = Genero.salsa;
    });

    tearDown(() => generoActivo = Genero.vallenato);

    test('el nivel guardado se ofrece y se juega como en línea', () async {
      final estado = await repo.cargarEstado(genero: Genero.salsa);
      expect(estado.niveles.single.nivel.id, 'nivel-01');
      expect(estado.niveles.single.puedeIniciar, isTrue);

      final partida = await repo.iniciarNivel('nivel-01');
      expect(partida.gameId, startsWith('offline:'));

      final audio = await repo.obtenerAudio(
        gameId: partida.gameId,
        tipo: 'stem',
        instrumento: 'bateria',
      );
      expect(audio.version, 'v1');

      final mala = await repo.enviarRespuesta(
        gameId: partida.gameId,
        respuesta: 'nada que ver',
      );
      expect(mala.correcta, isFalse);

      final buena = await repo.enviarRespuesta(
        gameId: partida.gameId,
        respuesta: 'mi cancion',
      );
      expect(buena.correcta, isTrue);
      expect(buena.titulo, 'Mi Canción');
      expect(buena.artista, 'Yo');
      // El acierto queda pendiente para cuando vuelva la red.
      expect(paquetes.tienePendiente('nivel-01'), isTrue);
    });

    test(
      'un nivel que no está en el paquete sigue pidiendo conexión',
      () async {
        await expectLater(
          repo.iniciarNivel('nivel-99'),
          throwsA(isA<SocketException>()),
        );
        await expectLater(
          repo.cargarEstado(genero: Genero.reggaeton),
          throwsA(isA<SocketException>()),
        );
      },
    );

    test('las compras sin conexión respetan el tope de tres', () async {
      final partida = await repo.iniciarNivel('nivel-01');
      final tipos = nivel.instrumentos.map((i) => i.id).toList();
      for (final id in tipos.take(3)) {
        final compra = await repo.comprarInstrumento(
          gameId: partida.gameId,
          instrumento: id,
        );
        expect(compra.compraRealizada, isTrue);
        expect([300000, 400000], contains(compra.precioInstrumento));
      }
      // Repetir una compra no cobra de nuevo.
      final repetida = await repo.comprarInstrumento(
        gameId: partida.gameId,
        instrumento: tipos.first,
      );
      expect(repetida.compraRealizada, isFalse);
      expect(repetida.presupuestoRestante, 0);
      await expectLater(
        repo.comprarInstrumento(
          gameId: partida.gameId,
          instrumento: tipos.last,
        ),
        throwsA(isA<GameRepositoryException>()),
      );
    });

    test('las pistas piden conexión', () async {
      final partida = await repo.iniciarNivel('nivel-01');
      await expectLater(
        Future.sync(
          () =>
              repo.pedirPista(gameId: partida.gameId, tipo: TipoPista.artista),
        ),
        throwsA(isA<GameRepositoryException>()),
      );
    });

    test('la intro guardada se muestra y se responde sin red', () async {
      final estado = await repo.cargarIntros(genero: Genero.salsa);
      expect(estado.intros.single.id, 'intro-07');
      expect(estado.intros.single.estado, EstadoIntro.desbloqueada);
      expect(estado.intros.single.titulo, isNull);

      final mala = await repo.enviarRespuestaIntro(
        introId: 'intro-07',
        respuesta: 'x',
      );
      expect(mala.correcta, isFalse);
      final buena = await repo.enviarRespuestaIntro(
        introId: 'intro-07',
        respuesta: 'otra cancion',
      );
      expect(buena.correcta, isTrue);
      expect(buena.titulo, 'Otra Canción');

      final despues = await repo.cargarIntros(genero: Genero.salsa);
      expect(despues.intros.single.estado, EstadoIntro.completada);
      expect(despues.intros.single.titulo, 'Otra Canción');
    });
  });
}
