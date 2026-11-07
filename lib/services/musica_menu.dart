import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/genero.dart';

class MusicaMenu with WidgetsBindingObserver {
  // Incluidas en la app: suenan también sin conexión. El valor ajusta el
  // volumen de cada una para que todas suenen parejo (intro.mp3 está grabada
  // más fuerte).
  static const _general = {
    'lib/assets/audio/menu/general/pista1.mp3': 1.71,
    'lib/assets/audio/menu/general/pista2.mp3': 1.34,
    'lib/assets/audio/menu/general/pista3.mp3': 1.54,
    'lib/assets/audio/menu/general/pista4.mp3': 1.37,
  };
  static const _porGenero = {
    Genero.vallenato: {
      'lib/assets/audio/menu/vallenato/intro2.mp3': 0.81,
      'lib/assets/audio/menu/vallenato/intro3.mp3': 1.02,
      'lib/assets/audio/menu/vallenato/intro.mp3': 1.31,
    },
    Genero.salsa: {
      'lib/assets/audio/menu/salsa/pista1.mp3': 1.02,
      'lib/assets/audio/menu/salsa/pista2.mp3': 0.86,
    },
    Genero.rockPop: {
      'lib/assets/audio/menu/rock_pop/pista1.mp3': 0.7,
      'lib/assets/audio/menu/rock_pop/pista2.mp3': 1.31,
    },
    Genero.reggaeton: {
      'lib/assets/audio/menu/reggaeton/pista1.mp3': 0.9,
      'lib/assets/audio/menu/reggaeton/pista2.mp3': 0.95,
    },
    Genero.popular: {
      'lib/assets/audio/menu/popular/pista1.mp3': 1.09,
      'lib/assets/audio/menu/popular/pista2.mp3': 1.49,
    },
  };
  static const _volumen = 0.0054;

  static const _cruce = Duration(milliseconds: 2500);
  static const _rapido = Duration(milliseconds: 800);

  // Pistas del género en pantalla; el selector, Medley y las salas usan las
  // generales.
  Map<String, double> _pistas = _general;

  final _azar = Random();
  AudioPlayer? _player;
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

  double get _volumenPista => _volumen * _pistas.values.elementAt(_actual);

  bool get _debeSonar =>
      !_silenciada && !_enSegundoPlano && _nivelesAbiertos == 0;

  Future<void> iniciar() async {
    // En el navegador no suena la música del menú.
    if (kIsWeb || _player != null) return;
    final player = AudioPlayer();
    _player = player;
    WidgetsBinding.instance.addObserver(this);
    try {
      _silenciada = await (await _archivoSilencio()).exists();
      _actual = _azar.nextInt(_pistas.length);
      await player.setAsset(_pistas.keys.elementAt(_actual));
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

  /// Cambia a la música del género (null, Medley y salas: la general) con el
  /// mismo fundido que entre canciones.
  void usarGenero(Genero? genero) {
    final pistas = _porGenero[genero] ?? _general;
    if (identical(pistas, _pistas)) return;
    _pistas = pistas;
    final player = _player;
    if (player == null || player.audioSource == null) {
      _actual = _azar.nextInt(pistas.length);
      return;
    }
    _siguiente(distinta: false);
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
      _fundir(player, _volumenPista, _rapido);
    }
  }

  /// Baja la canción actual y empieza otra al azar (distinta si hay más de
  /// una) subiendo el volumen.
  void _siguiente({bool distinta = true}) {
    final player = _player;
    if (player == null) return;
    _fundir(
      player,
      0,
      _cruce,
      alTerminar: () async {
        if (!distinta) {
          _actual = _azar.nextInt(_pistas.length);
        } else if (_pistas.length > 1) {
          final otra = _azar.nextInt(_pistas.length - 1);
          _actual = otra >= _actual ? otra + 1 : otra;
        }
        try {
          await player.setAsset(_pistas.keys.elementAt(_actual));
          if (_debeSonar) {
            unawaited(player.play());
            _fundir(player, _volumenPista, _cruce);
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
