/// Artistas del catálogo con las formas en que pueden aparecer escritos
/// (sin tildes y en minúsculas). Las colaboraciones ("X y Y", "X ft. Y") se
/// agrupan en el artista que aparece primero en el texto.
const _artistas = {
  'Martín Elías Díaz': ['martin elias'],
  'Diomedes Díaz': ['diomedes'],
  'Churo Díaz': ['churo'],
  'Silvestre Dangond': ['silvestre', 'dangond'],
  'Iván Villazón': ['ivan villazon', 'villazon'],
  'Peter Manjarrés': ['peter manjarres', 'peter mangarrez', 'manjarres'],
  'Jorge Oñate': ['jorge onate', 'onate'],
  'Jorge Celedón': ['celedon'],
  // Poncho Zuleta y Los Hermanos Zuleta son la misma agrupación.
  'Los Hermanos Zuleta': ['zuleta'],
  'Farid Ortiz': ['farid'],
  'Mono Zabaleta': ['zabaleta', 'zavaleta'],
  'Kvrass': ['kvrass'],
  'Kaleth Morales': ['kaleth'],
  'Binomio de Oro': ['binomio'],
};

String _normalizar(String texto) => texto
    .toLowerCase()
    .replaceAll(RegExp('[áàä]'), 'a')
    .replaceAll(RegExp('[éèë]'), 'e')
    .replaceAll(RegExp('[íìï]'), 'i')
    .replaceAll(RegExp('[óòö]'), 'o')
    .replaceAll(RegExp('[úùü]'), 'u')
    .replaceAll('ñ', 'n');

/// Nombre del artista del catálogo al que pertenece [artista] (el primero
/// que aparece en el texto), o null si no es ninguno de la lista.
String? artistaConocido(String artista) {
  final texto = _normalizar(artista);
  String? mejor;
  var posicion = texto.length;
  for (final MapEntry(key: nombre, value: formas) in _artistas.entries) {
    for (final forma in formas) {
      final indice = texto.indexOf(forma);
      if (indice >= 0 && indice < posicion) {
        posicion = indice;
        mejor = nombre;
      }
    }
  }
  return mejor;
}
