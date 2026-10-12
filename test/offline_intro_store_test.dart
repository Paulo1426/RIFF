import 'package:flutter_test/flutter_test.dart';
import 'package:song_guess_game/services/firebase_game_repository.dart';
import 'package:song_guess_game/services/offline_intro_store.dart';

void main() {
  const data = OfflineIntroData(
    id: 'cancion-26',
    titulo: 'La Suerte Está Echada',
    artista: 'Diomedes Díaz',
    respuesta: 'la suerte esta echada',
    introPath: 'intro.mp3',
    fullPath: 'original.mp3',
  );
  final snapshot = OfflineIntroSnapshot(
    uid: 'u1',
    estadoJson: const {
      'monedas': 1,
      'monedas_ganadas': 2,
      'restantes': 44,
      'intros': [
        {'id': 'cancion-26', 'numero': 1, 'estado': 'desbloqueada'},
      ],
    },
    intros: const {'cancion-26': data},
    pendientes: const [],
  );

  test('acepta la respuesta sin tildes ni mayúsculas', () {
    expect(data.acierta('La suerte está ECHADA!'), isTrue);
    expect(data.acierta('La suerte'), isFalse);
  });

  test('el acierto offline revela la canción y queda pendiente', () {
    final actualizado = snapshot.completadaLocalmente('cancion-26', 'x');
    final intro = actualizado.estado.intros.single;
    expect(intro.estado, EstadoIntro.completada);
    expect(intro.titulo, 'La Suerte Está Echada');
    expect(actualizado.pendientes, [
      {'introId': 'cancion-26', 'answer': 'x'},
    ]);
    expect(actualizado.sinPendiente('cancion-26').pendientes, isEmpty);
  });

  test('sobrevive a guardar y leer como JSON', () {
    final copia = OfflineIntroSnapshot.fromJson(
      snapshot.completadaLocalmente('cancion-26', 'x').toJson(),
    );
    expect(copia.intros['cancion-26']!.fullPath, 'original.mp3');
    expect(copia.pendientes.single['introId'], 'cancion-26');
  });
}
