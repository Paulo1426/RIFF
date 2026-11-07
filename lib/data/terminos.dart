// Texto de los Términos y Condiciones. Al cambiar el contenido, sube [versionTerminos]:
// la app vuelve a pedir la aceptación a quien tenga una versión anterior.

const versionTerminos = '1.0';
const fechaTerminos = '6 de noviembre de 2026';

const introTerminos = 'Lee con atención estos Términos y Condiciones de Uso (en adelante, los «Términos») antes de usar RIFF. Al marcar la casilla de aceptación y pulsar «Aceptar y continuar», declaras que los leíste, que los entiendes y que estás de acuerdo con ellos. Si no estás de acuerdo, pulsa «No acepto»: cerraremos tu sesión y no podrás usar la aplicación.';

/// Cada sección: (título, párrafos). Los que empiezan con «• » son viñetas.
const seccionesTerminos = <(String, List<String>)>[
  (
    '1. Definiciones',
    [
      '• «RIFF» o «la Aplicación»: el juego musical para Android que estás usando, con su diseño, código, logotipo, textos, menús y todas sus funciones.',
      '• «Usuario» o «tú»: cualquier persona que descarga, instala o usa RIFF, ya sea con una cuenta registrada o como invitado.',
      '• «Contenido Musical»: todo el material musical que RIFF reproduce o muestra: canciones y fragmentos, pistas de instrumentos, versiones instrumentales, intros, carátulas, nombres de artistas y música de fondo de los menús.',
      '• «Monedas y fichas»: los puntos de juego, es decir, las monedas por género, las monedas de Medley, las fichas de las salas y el presupuesto de cada partida. Solo existen dentro de RIFF y no son dinero.',
      '• «Servicios»: lo que RIFF te ofrece: los niveles, Adivina la intro, Medley, las salas multijugador, las insignias, las estadísticas y el guardado de tu progreso.',
    ],
  ),
  (
    '2. Aceptación y capacidad',
    [
      'Estos Términos son un acuerdo entre tú y RIFF. Se aceptan una sola vez por cuenta, después de iniciar sesión, y siguen vigentes mientras uses la Aplicación. Si publicamos una versión nueva con cambios importantes, te pediremos aceptarla otra vez.',
      'Debes ser mayor de edad según la ley colombiana (18 años) o contar con la autorización de tu padre, madre o representante legal, quien se hace responsable del uso que hagas de RIFF. Si eres menor de edad, tus datos solo se tratarán respetando el interés superior del niño, niña o adolescente y sus derechos fundamentales (Ley 1581 de 2012, artículo 7, y Ley 1098 de 2006).',
    ],
  ),
  (
    '3. Qué es RIFF y cómo funciona',
    [
      'RIFF es un juego de adivinar canciones escuchando sus instrumentos o sus primeros segundos. Incluye géneros como vallenato, reggaetón, rock/pop, salsa y popular, un modo Medley que mezcla todos los géneros, el modo Adivina la intro y salas multijugador.',
      'Las reglas, precios, premios, cantidad de niveles e intros, y la economía del juego pueden cambiar con el tiempo para mejorar la experiencia, corregir errores o mantener el equilibrio. No te prometemos que una función, nivel o canción estará disponible de forma permanente.',
    ],
  ),
  (
    '4. Cuenta, inicio de sesión y modo invitado',
    [
      'Puedes entrar con correo electrónico y contraseña, con tu cuenta de Google o como invitado.',
      '• Debes darnos datos verdaderos y mantenerlos al día.',
      '• Eres responsable de tu contraseña y de lo que ocurra con tu cuenta. Avísanos si crees que alguien la usa sin tu permiso.',
      '• No puedes crear cuentas falsas, suplantar a otra persona ni vender, prestar o transferir tu cuenta.',
      '• El modo invitado te deja jugar sin registrarte, pero tu progreso no se conserva: al cerrar la sesión de invitado, sus datos se borran.',
      '• Puedes reiniciar tu progreso desde Ajustes. Esa acción es definitiva y no se puede deshacer.',
    ],
  ),
  (
    '5. Uso educativo del Contenido Musical y titularidad de los derechos',
    [
      'Las canciones, fragmentos y demás Contenido Musical que aparecen en RIFF se utilizan únicamente con fines educativos, culturales y de entretenimiento sin ánimo de lucro: ayudar a las personas a reconocer, conocer y valorar la música colombiana y latinoamericana.',
      'RIFF no es dueño de ese Contenido Musical. Los derechos de autor y los derechos conexos sobre las obras, interpretaciones y grabaciones pertenecen a sus titulares: autores, compositores, artistas intérpretes, productores fonográficos y editores musicales. En Colombia, la gestión y el recaudo de los derechos de autor de las obras musicales corresponden a la Sociedad de Autores y Compositores de Colombia (SAYCO), y la de los derechos conexos de artistas y productores a las entidades de gestión competentes. Las canciones solicitadas y usadas en la Aplicación se reconocen como propiedad de sus respectivos titulares, representados en Colombia por SAYCO, en los términos de la Ley 23 de 1982, la Ley 44 de 1993, la Ley 1915 de 2018 y la Decisión Andina 351 de 1993.',
      'Estos Términos no te dan ninguna licencia ni derecho sobre ese Contenido Musical. Solo puedes escucharlo dentro de la Aplicación, de forma personal y privada, mientras juegas.',
      'No puedes copiar, descargar, grabar, extraer, redistribuir, comunicar públicamente, vender ni usar ese contenido fuera de la Aplicación, ni con fines comerciales, sin permiso de sus titulares o de la entidad que los gestiona.',
      'La lista completa de canciones y artistas aparece en la sección «Créditos» de este mismo menú de Información.',
    ],
  ),
  (
    '6. Reconocimiento a los artistas',
    [
      'RIFF reconoce el trabajo de cada artista, compositor y productor cuyas canciones aparecen en la Aplicación. Mostramos el título y el artista de cada canción (incluidos los artistas invitados o colaboradores) en la sección «Créditos», y la carátula al acertar un nivel o una intro.',
      'La música de fondo de los menús procede de recopilaciones y mezclas de terceros; sus autores originales se indican en «Créditos» cuando se conocen. Los derechos de esa música pertenecen a sus titulares.',
    ],
  ),
  (
    '7. Retiro de contenido y reclamaciones de derechos de autor',
    [
      'Respetamos los derechos de autor. Si eres titular de derechos, o su representante, y crees que algún Contenido Musical se usa en RIFF sin tu autorización, o quieres que se corrija el crédito, escríbenos por correo a jpaulogutierrez@unicesar.edu.co indicando: tu identificación y la calidad en que actúas, la obra y la ubicación en la Aplicación, y una forma de contactarte.',
      'Revisaremos la solicitud de buena fe y, cuando corresponda, retiraremos o sustituiremos el contenido sin demora y sin que ello genere responsabilidad para RIFF frente a los Usuarios.',
    ],
  ),
  (
    '8. Licencia de uso de la Aplicación',
    [
      'RIFF te concede una licencia personal, limitada, revocable, no exclusiva, intransferible y gratuita para instalar y usar RIFF en tus dispositivos Android, solo para tu entretenimiento y con fines no comerciales.',
      'RIFF, su código, diseño, interfaz, logotipo, nombre, textos, animaciones y organización de los niveles son propiedad de Joannes Gutierrez (© 2026) o se usan con permiso, y están protegidos por las normas de propiedad intelectual. Salvo que se indique otra licencia de forma expresa para una parte del proyecto, todos los derechos están reservados.',
    ],
  ),
  (
    '9. Conductas prohibidas',
    [
      'Al usar RIFF te comprometes a no:',
      '• Hacer ingeniería inversa, descompilar, modificar o intentar obtener el código, las claves o los audios de la Aplicación.',
      '• Extraer, grabar o copiar el audio, las carátulas o cualquier archivo del juego, ni saltarte las protecciones de acceso.',
      '• Usar bots, scripts, emuladores modificados u otras herramientas para jugar por ti, obtener monedas o fichas, o alterar resultados, tiempos, rankings o estadísticas.',
      '• Aprovechar errores del juego en tu favor o en perjuicio de otros, en lugar de avisarnos.',
      '• Sobrecargar, atacar o interferir con los servidores o servicios que usa la Aplicación.',
      '• Publicar nombres, mensajes o contenidos ofensivos, discriminatorios, violentos, sexuales, engañosos o que violen derechos de terceros.',
      '• Suplantar a otras personas, acosar a otros jugadores o usar la Aplicación para actividades ilegales.',
      '• Compartir o publicar las respuestas del juego para beneficiarte de ellas en las salas.',
    ],
  ),
  (
    '10. Monedas virtuales, fichas y presupuesto',
    [
      'Las monedas, las fichas de salas y el presupuesto de cada partida son elementos del juego. No son dinero ni valores, no tienen valor monetario, no se pueden comprar con dinero, vender, regalar ni canjear por dinero, y no son reembolsables.',
      'Podemos ajustar, equilibrar, reiniciar o corregir los saldos y las reglas de la economía del juego, por ejemplo para arreglar errores, evitar abusos o mantener el equilibrio. Usar la Aplicación no genera ningún derecho adquirido sobre esos saldos.',
    ],
  ),
  (
    '11. Salas multijugador, estadísticas e insignias',
    [
      'En las salas pueden participar hasta 10 jugadores. Al crear una sala o unirte a ella, tu nombre de jugador y tu desempeño en la partida pueden ser vistos por los demás participantes.',
      'Eres responsable de lo que haces en las salas y debes comportarte con respeto. Podemos expulsar jugadores, cerrar salas o suspender cuentas que incumplan estos Términos.',
      'Tus estadísticas (partidas jugadas, victorias, podios, fichas ganadas) y tus insignias se guardan en tu cuenta y pueden recalcularse si detectamos errores o trampas.',
    ],
  ),
  (
    '12. Datos personales (Ley 1581 de 2012 y Decreto 1377 de 2013)',
    [
      'Para consultas, sugerencias o solicitudes sobre tus datos personales, escribe a jpaulogutierrez@unicesar.edu.co.',
      'Qué datos tratamos:',
      '• Datos de la cuenta: correo electrónico, nombre y foto de perfil si entras con Google, y un identificador único de usuario.',
      '• Datos de juego: progreso, niveles completados, intros descubiertas, monedas, fichas, insignias, estadísticas y partidas en salas.',
      '• Datos técnicos mínimos: registros de errores y de uso necesarios para que la Aplicación funcione, y archivos guardados en tu dispositivo (memoria caché de las canciones que vas desbloqueando y tus preferencias, como silenciar la música o el modo oscuro). En la versión web no se guarda ningún archivo de audio.',
      'Para qué los usamos (finalidades): crear y mantener tu cuenta, guardar tu progreso, mostrar estadísticas e insignias, hacer funcionar las salas multijugador, mejorar la estabilidad y seguridad de la Aplicación, y prevenir fraudes y trampas.',
      'Con quién se comparten: usamos proveedores tecnológicos que alojan y procesan los datos por cuenta del Responsable: Google (Firebase: autenticación y base de datos) y Supabase (almacenamiento y funciones del servidor). Pueden estar fuera de Colombia, lo que implica una transferencia o transmisión internacional de datos con las medidas de seguridad que ofrecen esos proveedores. No vendemos tus datos ni los usamos para publicidad.',
      'Tus derechos como titular: conocer, actualizar y rectificar tus datos; pedir prueba de esta autorización; ser informado del uso que se les da; presentar quejas ante la Superintendencia de Industria y Comercio; revocar la autorización y solicitar la supresión de tus datos cuando no se respeten las normas; y acceder gratuitamente a ellos. Puedes ejercerlos escribiendo a jpaulogutierrez@unicesar.edu.co.',
      'Conservación: guardamos tus datos mientras tengas cuenta o mientras sean necesarios para las finalidades descritas. La sesión de invitado y su progreso se eliminan al cerrar la sesión.',
      'Los datos de menores de edad solo se tratan con autorización de sus representantes legales y respetando sus derechos prevalentes. Los datos que entregas son de naturaleza no sensible; no te pedimos datos sensibles.',
      'Al aceptar estos Términos autorizas de forma previa, expresa e informada el tratamiento de tus datos personales en los términos de este punto.',
    ],
  ),
  (
    '13. Disponibilidad y caché de audio',
    [
      'RIFF necesita conexión a internet para funcionar: tu progreso y el contenido se consultan siempre en nuestros servidores. Las canciones que vas desbloqueando se guardan en la memoria caché de tu teléfono para que se escuchen más rápido al repetir un nivel o una intro; en la versión web no se guarda nada y la página pide la canción al servidor cada vez, si ya la desbloqueaste. Esos archivos son temporales y solo para uso dentro de la Aplicación; puedes borrarlos desinstalando RIFF.',
      'No garantizamos que la Aplicación esté disponible de forma continua ni libre de errores. Puede haber interrupciones por mantenimiento, fallas de internet, cambios en los servicios de terceros o causas fuera de nuestro control.',
    ],
  ),
  (
    '14. Suspensión y terminación',
    [
      'Podemos suspender o cancelar tu acceso, de forma temporal o definitiva, si incumples estos Términos, si hay indicios de fraude o trampas, si lo exige la ley o la autoridad, o si decidimos dejar de ofrecer la Aplicación o parte de ella.',
      'Puedes dejar de usar RIFF cuando quieras, cerrar tu sesión, reiniciar tu progreso o pedir la supresión de tus datos por el canal de contacto.',
    ],
  ),
  (
    '15. Exclusión de garantías',
    [
      'RIFF se ofrece «tal cual» y «según disponibilidad», como un proyecto educativo y de entretenimiento. En la medida en que la ley lo permita, no damos garantías de que la Aplicación cumpla expectativas particulares, de que los datos de canciones y artistas estén libres de errores, ni de que funcione sin interrupciones.',
    ],
  ),
  (
    '16. Límite de responsabilidad',
    [
      'En la medida permitida por la ley colombiana, RIFF no será responsable por daños indirectos, pérdida de datos, de progreso o de saldos virtuales, interrupciones del servicio, ni por el contenido o las acciones de otros jugadores, ni por fallas de servicios de terceros como Google, Supabase o tu operador de internet.',
      'Nada de lo anterior limita derechos que la ley no permita limitar, incluidos los que te reconoce el Estatuto del Consumidor (Ley 1480 de 2011) cuando resulte aplicable. Como RIFF es gratuita, no existe contraprestación económica que reembolsar.',
    ],
  ),
  (
    '17. Cambios en la Aplicación y en estos Términos',
    [
      'Podemos actualizar RIFF y estos Términos. La versión vigente es la 1.0, con fecha 6 de noviembre de 2026, y siempre estará disponible en Ajustes → Información. Si el cambio es importante, te pediremos aceptar la nueva versión; seguir usando la Aplicación después significa que la aceptas.',
    ],
  ),
  (
    '18. Ley aplicable y solución de controversias',
    [
      'Estos Términos se rigen por las leyes de la República de Colombia. Las partes buscarán resolver cualquier diferencia de forma amistosa por el canal de contacto. Si no es posible, será competente la jurisdicción ordinaria colombiana, sin perjuicio de los derechos que tengas como consumidor ni de las facultades de las autoridades de protección de datos y de derechos de autor.',
    ],
  ),
  (
    '19. Disposiciones finales',
    [
      'Si alguna parte de estos Términos resulta inválida o no se puede aplicar, el resto seguirá vigente. Que no exijamos de inmediato el cumplimiento de alguna regla no significa que renunciemos a ella.',
      'Estos Términos son el acuerdo completo entre tú y RIFF sobre el uso de RIFF y reemplazan cualquier acuerdo anterior sobre el mismo tema.',
    ],
  ),
];

const cierreTerminos = '© 2026 Joannes Gutierrez. Todos los derechos reservados.';

const avisoCreditos = 'Las canciones de RIFF se usan con fines educativos y culturales, sin ánimo de lucro. Los derechos sobre cada obra y grabación pertenecen a sus autores, compositores, artistas, productores y editores, representados en Colombia por SAYCO (Sociedad de Autores y Compositores de Colombia) y las demás entidades de gestión colectiva. RIFF no es dueño de esas canciones ni reclama ningún derecho sobre ellas. Si eres titular de derechos y quieres corregir un crédito o retirar una canción, escríbenos a jpaulogutierrez@unicesar.edu.co.';

/// Música de fondo de los menús: (grupo, [(título, autor)]).
const musicaMenuCreditos = <(String, List<(String, String)>)>[
  (
    'Menús de los géneros: vallenato',
    [
      ('Intro (Saludos Inicio)', 'El Gran Martín Elías'),
      ('Pista de ambientación 2', 'Autor original sin identificar (fuente: YouTube)'),
      ('Pista de ambientación 3', 'Autor original sin identificar (fuente: YouTube)'),
    ],
  ),
  (
    'Menús de los géneros: salsa',
    [
      ('Super Salsa Mix Vol. 3: Puro Sabor', 'DJ Marlong Son (fuente: YouTube)'),
      ('Una Experiencia Musical (Pacific Live)', 'DJ Marlong Son (fuente: YouTube)'),
    ],
  ),
  (
    'Menús de los géneros: rock / pop',
    [
      ('Mix Rock Clásico Corto', 'DJ V (fuente: YouTube)'),
      ('Psychedelic Classic Rock Blues Guitar Mix (Tribute)', 'Pink Floyd y Black Sabbath, mezcla de tributo (fuente: YouTube)'),
    ],
  ),
  (
    'Menús de los géneros: reggaetón',
    [
      ('Reggaeton Antiguo pt. 1', 'Recopilación (fuente: YouTube)'),
      ('Reggaeton Antiguo pt. 2', 'Recopilación (fuente: YouTube)'),
    ],
  ),
  (
    'Menús de los géneros: popular',
    [
      ('Ayer Te Soñé (ranchera)', 'Autor original sin identificar (fuente: YouTube)'),
      ('Esta letra te hará pensar en tu vida', 'Autor original sin identificar (fuente: YouTube)'),
    ],
  ),
  (
    'Menú principal, Medley y salas',
    [
      ('Bossa Nova Instrumental 2024', 'Música instrumental (fuente: YouTube)'),
      ('Bossa Nova Jazz para Relajarte', 'Música instrumental (fuente: YouTube)'),
      ('Cafe Music (música ambiental instrumental)', 'Música instrumental (fuente: YouTube)'),
      ('Relaxing Bossa Nova Vibes', 'Música instrumental (fuente: YouTube)'),
    ],
  ),
];
