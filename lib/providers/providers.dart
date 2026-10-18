import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/nivel.dart';
import '../models/partida.dart';
import '../models/usuario.dart';
import '../services/audio_service.dart';
import '../services/firebase_game_repository.dart';
import '../services/game_service.dart';
import '../services/musica_menu.dart';
import '../services/nivel_repository.dart';
import '../services/offline_intro_store.dart';
import '../services/validation_service.dart';

final gameServiceProvider = Provider((ref) => GameService());
final audioServiceProvider = Provider((ref) => AudioService());
final musicaMenuProvider = Provider((ref) {
  final musica = MusicaMenu(ref.read(audioServiceProvider));
  ref.onDispose(musica.dispose);
  return musica;
});
final modoTemaProvider = StateNotifierProvider<ModoTema, ThemeMode>(
  (ref) => ModoTema()..cargar(),
);
final firebaseGameRepositoryProvider = Provider(
  (ref) => FirebaseGameRepository(),
);

final offlineIntroStoreProvider = Provider(
  (ref) => OfflineIntroStore(
    ref.read(firebaseGameRepositoryProvider),
    ref.read(audioServiceProvider),
  ),
);

final nivelRepositoryProvider = Provider<NivelRepository>(
  (ref) => SupabaseNivelRepositoryAdapter(),
);

final validationServiceProvider = Provider<ValidationService>(
  (ref) => LocalValidationService(
    (nivelId) async =>
        (await ref.read(nivelRepositoryProvider).obtener(nivelId))
            .cancionTitulo,
  ),
);

final usuarioProvider = StateProvider<Usuario>((ref) => Usuario(id: 'local'));

final nivelesProvider = FutureProvider.family<List<Nivel>, Dificultad>(
  (ref, d) => ref.watch(nivelRepositoryProvider).nivelesDe(d),
);

final partidaProvider = StateNotifierProvider<PartidaNotifier, Partida?>(
  (ref) => PartidaNotifier(),
);

/// Claro u oscuro elegido en el menú; sin elección sigue al sistema. Se
/// guarda en un archivo, igual que el silencio de la música del menú.
class ModoTema extends StateNotifier<ThemeMode> {
  ModoTema() : super(ThemeMode.system);

  static Future<File> _archivo() async =>
      File('${(await getApplicationSupportDirectory()).path}/modo_tema');

  Future<void> cargar() async {
    try {
      final archivo = await _archivo();
      if (!await archivo.exists()) return;
      final guardado = await archivo.readAsString();
      state = ThemeMode.values.firstWhere(
        (modo) => modo.name == guardado,
        orElse: () => ThemeMode.system,
      );
    } catch (error) {
      debugPrint('No se pudo leer el modo de tema: $error');
    }
  }

  Future<void> cambiar(ThemeMode modo) async {
    state = modo;
    try {
      await (await _archivo()).writeAsString(modo.name);
    } catch (error) {
      debugPrint('No se pudo guardar el modo de tema: $error');
    }
  }
}

class PartidaNotifier extends StateNotifier<Partida?> {
  PartidaNotifier() : super(null);

  void iniciar(Nivel nivel) =>
      state = Partida(instrumentos: nivel.instrumentos);

  bool comprar(String tipo) {
    if (state == null) return false;
    final ok = state!.comprar(tipo);
    if (ok) state = state!.copy();
    return ok;
  }

  void acertar() {
    final partida = state;
    if (partida == null) return;
    partida.acertar();
    state = partida.copy();
  }
}
