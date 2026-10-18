import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riff/main.dart';
import 'package:riff/screens/home_screen.dart';

void main() {
  testWidgets('muestra la pantalla inicial', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: SongGuessApp(
          home: HomeScreen(authStateChanges: Stream<User?>.value(null)),
        ),
      ),
    );
    // El fondo líquido se anima sin fin; pumpAndSettle nunca terminaría.
    await tester.pump(const Duration(seconds: 1));
    expect(find.bySemanticsLabel('Riff'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Jugar sin registrarme'), findsOneWidget);
  });

  testWidgets('informa que Firebase no esta configurado para Web', (
    tester,
  ) async {
    await tester.pumpWidget(const SongGuessApp(firebaseSupported: false));

    expect(
      find.text('Firebase solo está configurado para Android e iOS.'),
      findsOneWidget,
    );
  });
}
