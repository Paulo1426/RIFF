import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'las fuentes van dentro de la app con los nombres de google_fonts',
    () async {
      // google_fonts busca "<Familia>-<Grosor>.ttf" entre los recursos; con la
      // descarga apagada (main.dart), si falta uno la letra sale por defecto.
      final recursos = (await AssetManifest.loadFromAssetBundle(
        rootBundle,
      )).listAssets();
      for (final nombre in [
        'Manrope-Regular',
        'Manrope-Medium',
        'Manrope-SemiBold',
        'Manrope-Bold',
        'Manrope-ExtraBold',
        'Jersey10-Regular',
      ]) {
        expect(
          recursos.any((ruta) => ruta.endsWith('$nombre.ttf')),
          isTrue,
          reason: 'Falta $nombre.ttf en lib/assets/fonts',
        );
      }
    },
  );
}
