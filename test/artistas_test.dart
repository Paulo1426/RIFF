import 'package:flutter_test/flutter_test.dart';
import 'package:riff/models/artistas.dart';

void main() {
  test('agrupa por el artista del catálogo sin importar tildes', () {
    expect(
      artistaConocido('Martín Elías y Rolando Ochoa'),
      'Martín Elías Díaz',
    );
    expect(artistaConocido('Martin Elias Diaz'), 'Martín Elías Díaz');
    expect(artistaConocido('DIOMEDES DÍAZ & Juancho Rois'), 'Diomedes Díaz');
    expect(artistaConocido('Silvestre Dangond'), 'Silvestre Dangond');
    expect(artistaConocido('Peter Manjarrés'), 'Peter Manjarrés');
    expect(artistaConocido('Mono Zabaleta'), 'Mono Zabaleta');
    expect(artistaConocido('Jorge Oñate'), 'Jorge Oñate');
  });

  test('Poncho Zuleta y Los Hermanos Zuleta son el mismo grupo', () {
    expect(artistaConocido('Poncho Zuleta'), 'Los Hermanos Zuleta');
    expect(artistaConocido('Los Hermanos Zuleta'), 'Los Hermanos Zuleta');
  });

  test('en una colaboración gana el que aparece primero', () {
    expect(
      artistaConocido('Jorge Celedón y Jimmy Zambrano ft. Silvestre Dangond'),
      'Jorge Celedón',
    );
    // "Díaz" solo no basta: Churo, Diomedes y Martín Elías la comparten.
    expect(artistaConocido('Churo Díaz y Elías Mendoza'), 'Churo Díaz');
  });

  test('un artista fuera de la lista no se agrupa', () {
    expect(artistaConocido('Carlos Vives'), isNull);
  });
}
