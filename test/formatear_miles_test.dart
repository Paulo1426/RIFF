import 'package:flutter_test/flutter_test.dart';
import 'package:song_guess_game/screens/game_screen.dart';

void main() {
  test('agrega puntos de miles', () {
    expect(formatearMiles(0), '0');
    expect(formatearMiles(300), '300');
    expect(formatearMiles(300000), '300.000');
    expect(formatearMiles(1000000), '1.000.000');
    expect(formatearMiles(-400000), '-400.000');
  });
}
