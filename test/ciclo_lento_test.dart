import 'package:flutter_test/flutter_test.dart';
import 'package:riff/animations/ciclo_lento.dart';

void main() {
  testWidgets('avisa a 30 cuadros por segundo solo mientras está activo', (
    tester,
  ) async {
    final a = CicloLento(periodo: const Duration(seconds: 4));
    final b = CicloLento(periodo: const Duration(seconds: 24));
    var avisosA = 0;
    var avisosB = 0;
    a.addListener(() => avisosA++);
    b.addListener(() => avisosB++);

    // Inactivos: ni un cuadro.
    await tester.pump(const Duration(seconds: 1));
    expect(avisosA + avisosB, 0);

    a.activo = true;
    b.activo = true;
    await tester.pump(const Duration(seconds: 1));
    // Un solo reloj compartido: los dos avisan en los mismos cuadros.
    expect(avisosA, inInclusiveRange(29, 30));
    expect(avisosB, avisosA);

    // Pausado no avisa y la fase queda quieta; al volver sigue desde ahí.
    a.activo = false;
    final fase = a.value;
    final antes = avisosA;
    await tester.pump(const Duration(seconds: 1));
    expect(avisosA, antes);
    expect(a.value, fase);
    a.activo = true;
    expect(a.value, closeTo(fase, 0.01));

    // Al liberarlos se apaga el reloj compartido.
    a.dispose();
    b.dispose();
  });
}
