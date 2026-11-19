import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'providers/providers.dart';
import 'animations/logo_animado.dart';
import 'screens/home_screen.dart';
import 'theme/liquid_glass_theme.dart';
import 'widgets/escala_pantalla.dart';
import 'services/logs_release.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  silenciarLogsEnRelease();
  WidgetsFlutterBinding.ensureInitialized();
  // Las fuentes van en lib/assets/fonts: sin descargas ni salto de letras al
  // abrir, y también sin conexión.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final (fuente, archivo) in [
      ('Manrope', 'OFL-Manrope.txt'),
      ('Jersey 10', 'OFL-Jersey10.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        fuente,
      ], await rootBundle.loadString('lib/assets/fonts/$archivo'));
    }
  });
  final firebaseSupported =
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  if (firebaseSupported) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    debugPrint(
      'Firebase solo esta configurado para Android e iOS; '
      'plataforma actual: $defaultTargetPlatform.',
    );
  }

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    await SupabaseService.initialize(url: supabaseUrl, anonKey: supabaseKey);
  }
  runApp(
    ProviderScope(child: SongGuessApp(firebaseSupported: firebaseSupported)),
  );
}

class SongGuessApp extends ConsumerWidget {
  const SongGuessApp({super.key, this.home, this.firebaseSupported = true});

  final Widget? home;
  final bool firebaseSupported;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    title: 'Riff',
    debugShowCheckedModeBanner: false,
    theme: buildLiquidGlassTheme(),
    darkTheme: buildLiquidGlassTheme(oscuro: true),
    themeMode: ref.watch(modoTemaProvider),
    // Las tarjetas de vidrio comparten una sola captura del fondo.
    builder: (context, child) {
      final app = BackdropGroup(child: child!);
      if (!kIsWeb) return EscalaPantalla(child: app);
      // Web en PC: columna de móvil centrada. MediaQuery también se acota
      // para que los widgets que miden la pantalla usen ese ancho.
      final media = MediaQuery.of(context);
      final ancho = media.size.width.clamp(0.0, 480.0);
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: SizedBox(
            width: ancho,
            child: MediaQuery(
              data: media.copyWith(size: Size(ancho, media.size.height)),
              child: app,
            ),
          ),
        ),
      );
    },
    home:
        home ??
        (firebaseSupported
            ? const IntroLogo(child: HomeScreen())
            : const Scaffold(
                body: Center(
                  child: Text(
                    'Firebase solo está configurado para Android e iOS.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )),
  );
}
