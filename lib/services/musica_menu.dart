import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'audio_service.dart';

class MusicaMenu with WidgetsBindingObserver {
  MusicaMenu(this._cache);

  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const _ruta =
      '/storage/v1/object/public/music_menu/music_menu/intro.mp3';
  static const _volumen = 0.10;

  final AudioService _cache;
  AudioPlayer? _player;
  bool _silenciada = false;
  bool _enSegundoPlano = false;
  int _nivelesAbiertos = 0;
  Timer? _fundido;

  bool get silenciada => _silenciada;

  Future<void> iniciar() async {
    if (_supabaseUrl.isEmpty || _player != null) return;
    final player = AudioPlayer();
    _player = player;
    WidgetsBinding.instance.addObserver(this);
    try {
      _silenciada = await (await _archivoSilencio()).exists();
      // shortcut: se descarga una vez y queda en caché; si cambias intro.mp3,
      // borra los datos de la app o cambia la clave para volver a bajarla.
      final file = await _cache.descargarYGuardar(
        '$_supabaseUrl$_ruta',
        'menu:intro',
      );
      await player.setFilePath(file.path);
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(_volumen);
      _actualizar();
    } catch (error) {
      debugPrint('No se pudo cargar la música del menú: $error');
    }
  }

  void entrarNivel() {
    _nivelesAbiertos++;
    _actualizar();
  }

  void salirNivel() {
    if (_nivelesAbiertos > 0) _nivelesAbiertos--;
    _actualizar();
  }

  Future<void> alternarSilencio() async {
    _silenciada = !_silenciada;
    _actualizar();
    try {
      final archivo = await _archivoSilencio();
      if (_silenciada) {
        await archivo.create(recursive: true);
      } else if (await archivo.exists()) {
        await archivo.delete();
      }
    } catch (error) {
      debugPrint('No se pudo guardar la preferencia de música: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _enSegundoPlano = state != AppLifecycleState.resumed;
    _actualizar();
  }

  void dispose() {
    _fundido?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_player?.dispose());
    _player = null;
  }

  void _actualizar() {
    final player = _player;
    if (player == null || player.audioSource == null) return;
    if (_silenciada || _enSegundoPlano || _nivelesAbiertos > 0) {
      if (player.playing) {
        _fundir(player, 0, alTerminar: () => unawaited(player.pause()));
      }
    } else {
      if (!player.playing) {
        unawaited(player.setVolume(0));
        // play() termina recién al pausar; no se espera.
        unawaited(player.play());
      }
      _fundir(player, _volumen);
    }
  }

  /// Sube o baja el volumen de a poco (~0,8 s) en vez de cortar de golpe. Un
  /// fundido nuevo cancela el anterior, así que pausar y reanudar rápido no
  /// deja la música muda ni pausada por error.
  void _fundir(AudioPlayer player, double destino, {VoidCallback? alTerminar}) {
    _fundido?.cancel();
    const pasos = 20;
    final inicio = player.volume;
    var paso = 0;
    _fundido = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      paso++;
      unawaited(player.setVolume(inicio + (destino - inicio) * paso / pasos));
      if (paso >= pasos) {
        timer.cancel();
        _fundido = null;
        alTerminar?.call();
      }
    });
  }

  Future<File> _archivoSilencio() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/musica_menu_silenciada');
  }
}
