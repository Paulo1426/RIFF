import 'dart:math';

import '../models/genero.dart';

/// Curiosidades de la pantalla de carga. Fuente: docs/curiosidades.md.
const _curiosidades = <Genero, List<String>>{
  Genero.vallenato: [
    'El vallenato mezcla tres culturas en tres instrumentos: el acordeón (europeo), la caja (africana) y la guacharaca (indígena).',
    'El nombre viene de "vallenato", que significa nacido en el valle, por Valledupar.',
    'El Festival de la Leyenda Vallenata se celebra en Valledupar desde 1968. Lo fundaron Consuelo Araújo Noguera, Alfonso López Michelsen y Rafael Escalona.',
    'Alejo Durán fue el primer Rey Vallenato de la historia, en 1968.',
    'El vallenato tiene cuatro aires principales: son, paseo, merengue y puya. La puya es el más rápido.',
    'Según la leyenda, Francisco el Hombre venció al diablo en un duelo de acordeón tocando el Credo al revés.',
    'En 2015 la UNESCO declaró el vallenato tradicional Patrimonio Cultural Inmaterial de la Humanidad.',
    'Gabriel García Márquez dijo que "Cien años de soledad" era un vallenato de 350 páginas.',
    '"La gota fría" nació de una pelea musical entre Emiliano Zuleta y Lorenzo Morales. Décadas después, Carlos Vives la hizo famosa en todo el mundo.',
    'Las "piquerías" son duelos de versos improvisados entre juglares. Antes eran una forma de resolver rivalidades.',
    'Se cree que el acordeón llegó a Colombia a finales del siglo XIX por los puertos de La Guajira, en barcos que venían de Europa.',
    'La mayoría de acordeoneros vallenatos prefieren los acordeones de la marca alemana Hohner.',
    'Cada diez años el Festival Vallenato organiza el concurso "Rey de Reyes", donde compiten solo los ganadores anteriores.',
    'Diomedes Díaz, "El Cacique de La Junta", es uno de los artistas que más discos ha vendido en la historia de Colombia.',
    'En 1991 Carlos Vives interpretó a Rafael Escalona en una telenovela. Ese papel lo llevó a grabar "Clásicos de la Provincia" (1993), disco que modernizó el vallenato.',
  ],
  Genero.reggaeton: [
    'El reggaetón tiene raíces en Panamá, con el "reggae en español" de artistas como El General en los años 80 y 90.',
    'El ritmo base se llama "dembow" por la canción "Dem Bow" del jamaiquino Shabba Ranks (1990).',
    'En Puerto Rico, a principios de los 90, el género se llamaba "underground" y circulaba en casetes hechos en casa.',
    'En 1995 la policía de Puerto Rico confiscó casetes de underground en tiendas de discos porque consideraba obscenas sus letras.',
    '"Gasolina" de Daddy Yankee (2004) fue la canción que llevó el reggaetón al mundo entero.',
    '"Despacito" (2017), de Luis Fonsi y Daddy Yankee, fue el primer video de YouTube en superar los 3.000 millones de reproducciones.',
    'Ivy Queen es conocida como "La Reina del Reggaetón" y fue una de las primeras mujeres en destacar en el género.',
    'Medellín es una de las capitales mundiales del reggaetón, cuna de J Balvin, Maluma, Karol G, Feid y Blessd.',
    'La Real Academia Española incluyó la palabra "reguetón" en su diccionario.',
    'El reggaetón suele moverse entre 90 y 100 golpes por minuto, un tempo pensado para bailar sin cansarse rápido.',
    '"Un Verano Sin Ti" de Bad Bunny fue el primer álbum totalmente en español nominado a Álbum del Año en los Grammy.',
    'En 2026 Bad Bunny ganó el Grammy al Álbum del Año con "Debí Tirar Más Fotos", el primero totalmente en español en lograrlo.',
    'Daddy Yankee se despidió de la música con la gira "La Última Vuelta" y su último concierto fue en San Juan en 2023.',
    'Antes de ser famoso, Bad Bunny empacaba bolsas en un supermercado en Puerto Rico.',
    'La palabra "perreo" viene de la forma de bailar el género y se volvió tan común que da nombre a canciones, fiestas y playlists.',
  ],
  Genero.salsa: [
    'La palabra "salsa" se popularizó en Nueva York en los años 60 y 70 para vender música de raíz cubana y puertorriqueña.',
    'El sello Fania Records, fundado en 1964 por Johnny Pacheco y Jerry Masucci, fue la casa de las grandes estrellas de la salsa.',
    'En 1971 la Fania All-Stars dio un concierto histórico en el club Cheetah de Nueva York que quedó grabado en la película "Our Latin Thing".',
    'Celia Cruz empezó a gritar "¡Azúcar!" después de que un mesero en Miami le preguntara si quería su café con azúcar.',
    'Celia Cruz cantó durante 15 años con la Sonora Matancera, antes de su carrera en Estados Unidos.',
    'Cali es llamada la "Capital Mundial de la Salsa".',
    'Se cuenta que en Cali ponían los discos de salsa más rápido de lo normal, y de ahí nació el estilo caleño de pies veloces.',
    'Desde 2008 la Feria de Cali abre con el Salsódromo, un desfile de bailarines por la ciudad.',
    '"El Cantante", el gran éxito de Héctor Lavoe, fue escrito por Rubén Blades.',
    '"Pedro Navaja" de Rubén Blades se inspiró en "Mack the Knife", una canción alemana de los años 20.',
    'Rubén Blades fue candidato a la presidencia de Panamá en 1994 y después ministro de Turismo.',
    '"Siembra" (1978), de Willie Colón y Rubén Blades, es uno de los álbumes de salsa más vendidos de la historia.',
    '"La Rebelión" de Joe Arroyo cuenta la historia de esclavos africanos en Cartagena durante la Colonia.',
    'Jairo Varela, fundador del Grupo Niche, era del Chocó, pero el grupo se formó en Bogotá y triunfó en Cali.',
    'La base rítmica de la salsa es la "clave", un patrón de cinco golpes que puede ir en 3-2 o 2-3.',
  ],
  Genero.rockPop: [
    'Rock al Parque, en Bogotá, nació en 1995 y es uno de los festivales gratuitos de rock más grandes de Latinoamérica.',
    '"Pies Descalzos" (1995) fue el disco que convirtió a Shakira en estrella internacional.',
    'En 2020 Shakira y Jennifer Lopez protagonizaron el show de medio tiempo del Super Bowl.',
    '"La Camisa Negra" de Juanes fue un éxito en todo el mundo, incluso en países que no hablan español.',
    'Aterciopelados, con "Bolero Falaz", fue uno de los grupos que puso el rock colombiano en el mapa en los 90.',
    'En los años 60, bandas bogotanas como Los Speakers fueron pioneras del rock en Colombia.',
    'En los 80 el movimiento "Rock en tu idioma" impulsó a bandas latinas que cantaban en español.',
    'Soda Stereo se despidió en 1997 con el concierto "El Último Concierto", donde Gustavo Cerati dijo "¡Gracias totales!".',
    'Café Tacvba tomó su nombre de un famoso restaurante del centro de Ciudad de México.',
    'Morat, banda bogotana, empezó tocando instrumentos como el banjo, poco usado en el pop latino.',
    '"Bohemian Rhapsody" de Queen dura casi 6 minutos y no tiene coro. La disquera pensaba que no sonaría en la radio.',
    'Freddie Mercury nació en Zanzíbar (África) y su nombre real era Farrokh Bulsara.',
    '"Yesterday" de The Beatles es una de las canciones con más versiones grabadas: más de 1.600.',
    'El título "Smells Like Teen Spirit" de Nirvana viene de una marca de desodorante llamada Teen Spirit.',
    '"Thriller" de Michael Jackson es considerado el álbum más vendido de la historia.',
  ],
  Genero.popular: [
    'José Alfredo Jiménez compuso cientos de canciones sin saber leer música ni tocar ningún instrumento.',
    'Vicente Fernández, "El Charro de Huentitán", prometía no dejar de cantar mientras el público no dejara de aplaudir.',
    'En 2011 la UNESCO declaró el mariachi Patrimonio Cultural Inmaterial de la Humanidad.',
    '"Cielito Lindo" fue compuesta en 1882 por Quirino Mendoza y Cortés y hoy es casi un himno de México.',
    'Jorge Negrete y Pedro Infante llevaron la ranchera a todo el mundo con el cine mexicano de los años 40 y 50.',
    'La Plaza Garibaldi, en Ciudad de México, es famosa porque allí se contratan mariachis a cualquier hora.',
    'La "música de carrilera" se llamó así porque sonaba en cantinas cerca de las vías del tren en Antioquia.',
    'Darío Gómez es conocido como "El Rey del Despecho".',
    'Artistas como Jhonny Rivera, Jessi Uribe y Paola Jara llevaron la música popular a estadios y plataformas digitales.',
    'El bambuco es considerado por muchos el ritmo nacional de Colombia.',
    'El tiple es un instrumento colombiano de 12 cuerdas organizadas en 4 grupos de tres.',
    'El pasillo viene del vals europeo. Su nombre significa "paso pequeño" por la forma de bailarlo.',
    'Ibagué es llamada la "Capital Musical de Colombia" por su conservatorio y su tradición de duetos.',
    'El Festival Mono Núñez, en Ginebra (Valle), celebra la música andina colombiana desde 1975.',
    'Jorge Velosa creó la música carranguera en Boyacá, mezclando ritmos campesinos con letras humorísticas.',
    'Jorge Villamil, compositor huilense, escribió clásicos como "Espumas" y "Los Guaduales".',
    'En Neiva se celebra el Festival Folclórico y Reinado Nacional del Bambuco durante las fiestas de San Pedro.',
  ],
};

/// Una curiosidad al azar del género; Medley toma de cualquiera de los cinco.
String curiosidadAlAzar(Genero genero) {
  final lista =
      _curiosidades[genero] ??
      _curiosidades.values.expand((curiosidades) => curiosidades).toList();
  return lista[Random().nextInt(lista.length)];
}
