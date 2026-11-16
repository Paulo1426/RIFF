import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riff/data/creditos.dart';
import 'package:riff/data/terminos.dart';
import 'package:riff/screens/informacion_dialog.dart';
import 'package:riff/theme.dart';

void main() {
  test('los términos cierran con el nombre del autor y el año', () {
    expect(cierreTerminos, contains('Joannes Gutierrez'));
    expect(cierreTerminos, contains('2026'));
  });

  test('créditos: los cinco géneros tienen artistas sin repetir', () {
    expect(creditosPorGenero.length, 5);
    for (final artistas in creditosPorGenero.values) {
      expect(artistas, isNotEmpty);
      expect(artistas.toSet().length, artistas.length);
      expect(artistas.every((a) => a.trim().isNotEmpty), isTrue);
    }
  });

  testWidgets('información: términos y créditos no se desbordan en teléfono', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const InformacionDialog()),
    );
    expect(find.text('Términos y condiciones'), findsOneWidget);
    await tester.tap(find.text('Créditos'));
    await tester.pumpAndSettle();
    expect(find.text('Vallenato'), findsOneWidget);
    await tester.tap(find.text('Vallenato'));
    await tester.pumpAndSettle();
    expect(find.text('Martín Elías'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
