import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riff/widgets/escala_pantalla.dart';

void main() {
  test('escalaPantalla: no reduce, acota y respeta tablets', () {
    expect(escalaPantalla(360), 1.0);
    expect(escalaPantalla(480), closeTo(1.2, 1e-9));
    expect(escalaPantalla(590), closeTo(1.475, 1e-9));
    expect(escalaPantalla(800), 1.0);
  });

  testWidgets('EscalaPantalla da al hijo un MediaQuery dividido por la escala', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Size? visto;
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, hijo) => EscalaPantalla(child: hijo!),
        home: Builder(
          builder: (context) {
            visto = MediaQuery.sizeOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(visto, const Size(400, 800));
  });
}
