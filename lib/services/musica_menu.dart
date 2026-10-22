import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'audio_service.dart';

/// Música de fondo del menú: varias canciones en orden aleatorio. Cada una
/// empieza subiendo el volumen y termina bajándolo antes de pasar a la
/// siguiente, sin cortes de golpe.
class MusicaMenu with WidgetsBindingObserver {
  MusicaMenu(this._cache);

  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const _ruta =
      '/storage/v1/object/public/music_menu/music_menu/intro.mp3';
  // Incluidas en la app: suenan también sin conexión.
  static const _pistasIncluidas = [
    'lib/assets/audio/menu/intro2.mp3',
    'lib/assets/audio/menu/intro3.mp3',
  ];
  static const _volumen = 0.05;
  // Fundido entre canciones (pausar y reanudar usan uno más corto).
  static const _cruce = Duration(milliseconds: 2500);
  static const _rapido = Duration(milliseconds: 800);

  final AudioService _cache;
  final _azar = Random();
  AudioPlayer? _player;
  final List<AudioSource> _pistas = [];
  int _actual = 0;
  bool _silenciada = false;
  bool _enSegundoPlano = false;
  int _nivelesAbiertos = 0;
  // Pasando a la siguiente canción (bajando el volumen de la actual).
  bool _cambiando = false;
  Timer? _fundido;
  StreamSubscription<Duration>? _avance;
  StreamSubscription<ProcessingState>? _fin;

  bool get silenciada => _silenciada;

  bool get _debeSonar =>
      !_silenciada && !_enSegundoPlano && _nivelesAbiertos == 0;

  Future<void> iniciar() async {
    if (_player != null) return;
    final player = AudioPlayer();
    _player = player;
    WidgetsBinding.instance.addObserver(this);
    try {
      _silenciada = await (await _archivoSilencio()).exists();
      _pistas.addAll(_pistasIncluidas.map(AudioSource.asset));
      // La original se descarga una vez; sin conexión se juega con las demás.
      if (_supabaseUrl.isNotEmpty) {
        try {
          final file = await _cache.descargarYGuardar(
            '$_supabaseUrl$_ruta',
            'menu:intro',
          );
          _pistas.add(AudioSource.file(file.path));
        } catch (error) {
          debugPrint('No se pudo descargar la música del menú: $error');
        }
      }
      _actual = _azar.nextInt(_pistas.length);
      await player.setAudioSource(_pistas[_actual]);
      await player.setLoopMode(LoopMode.off);
      await player.setVolume(0);
      // Cerca del final de cada canción empieza el fundido a la siguiente.
      _avance = player.positionStream.listen((posicion) {
        final duracion = player.duration;
        if (duracion != null &&
            !_cambiando &&
            player.playing &&
            posicion >= duracion - _cruce) {
          _siguiente();
        }
      });
      // Si una canción terminó sin fundido (p. ej. se pausó a mitad del
      // cambio), pasa igual a la siguiente.
      _fin = player.processingStateStream.listen((estado) {
        if (estado == ProcessingState.completed && !_cambiando) _siguiente();
      });
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
    unawaited(_avance?.cancel());
    unawaited(_fin?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_player?.dispose());
    _player = null;
  }

  void _actualizar() {
    final player = _player;
    if (player == null || player.audioSource == null) return;
    if (!_debeSonar) {
      if (player.playing) {
        _fundir(
          player,
          0,
          _rapido,
          alTerminar: () => unawaited(player.pause()),
        );
      }
    } else {
      if (!player.playing) {
        unawaited(player.setVolume(0));
        unawaited(player.play());
      }
      _fundir(player, _volumen, _rapido);
    }
  }

  /// Baja la canción actual y empieza otra al azar (distinta si hay más de
  /// una) subiendo el volumen.
  void _siguiente() {
    final player = _player;
    if (player == null) return;
    _fundir(
      player,
      0,
      _cruce,
      alTerminar: () async {
        if (_pistas.length > 1) {
          final otra = _azar.nextInt(_pistas.length - 1);
          _actual = otra >= _actual ? otra + 1 : otra;
        }
        try {
          await player.setAudioSource(_pistas[_actual]);
          if (_debeSonar) {
            unawaited(player.play());
            _fundir(player, _volumen, _cruce);
          }
        } catch (error) {
          debugPrint('No se pudo pasar a la siguiente canción: $error');
        } finally {
          _cambiando = false;
        }
      },
    );
    _cambiando = true;
  }

  /// Lleva el volumen a [destino] de a poco durante [duracion]. Un fundido
  /// nuevo cancela el anterior, así que pausar y reanudar rápido no deja la
  /// música muda ni pausada por error.
  void _fundir(
    AudioPlayer player,
    double destino,
    Duration duracion, {
    VoidCallback? alTerminar,
  }) {
    _fundido?.cancel();
    // Si se cancela un cambio de canción a medias, vuelve a intentarse cuando
    // la música siga sonando cerca del final.
    _cambiando = false;
    const intervalo = Duration(milliseconds: 40);
    final pasos = max(1, duracion.inMilliseconds ~/ intervalo.inMilliseconds);
    final inicio = player.volume;
    var paso = 0;
    _fundido = Timer.periodic(intervalo, (timer) {
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
