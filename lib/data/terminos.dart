// Texto de los Términos y Condiciones. Al cambiar el contenido, sube [versionTerminos]:
// la app vuelve a pedir la aceptación a quien tenga una versión anterior.

const versionTerminos = '1.0';
const fechaTerminos = '6 de noviembre de 2026';
const revisionTerminos = '12 de noviembre de 2026';
const responsableTerminos = 'Joannes Gutierrez';
const correoTerminos = 'jpaulogutierrez@unicesar.edu.co';

const introTerminos =
    'Lee con atención estos Términos y Condiciones de Uso (en adelante, los «Términos») antes de usar RIFF. Al marcar la casilla de aceptación y pulsar «Aceptar y continuar», declaras que los leíste, que los entiendes y que estás de acuerdo con ellos. Si no estás de acuerdo, pulsa «No acepto»: cerraremos tu sesión y no podrás usar la aplicación.';

/// Cada sección: (título, párrafos). Los que empiezan con «• » son viñetas.
const seccionesTerminos = <(String, List<String>)>[
  (
    '1. Disposiciones generales',
    [
      'Los presentes Términos y Condiciones de Uso (en adelante, los «Términos») regulan el acceso, la utilización y las condiciones de funcionamiento de RIFF (en adelante, la «Aplicación»).',
      'RIFF es una aplicación de entretenimiento musical que permite a los usuarios poner a prueba sus conocimientos musicales mediante dinámicas de reconocimiento de canciones, identificación de melodías, desafíos individuales y partidas multijugador.',
      'El acceso y utilización de la Aplicación implican el conocimiento de estos Términos y su aceptación expresa por parte del usuario.',
      'Se recomienda leer detenidamente este documento antes de utilizar cualquiera de las funcionalidades de RIFF.',
    ],
  ),
  (
    '2. Definiciones',
    [
      'Para efectos de interpretación de estos Términos, se establecen las siguientes definiciones:',
      '• RIFF o Aplicación: plataforma de entretenimiento musical, incluyendo su código fuente, interfaz, diseño, funcionalidades y contenidos propios.',
      '• Usuario: persona que accede, se registra o utiliza cualquiera de los servicios ofrecidos por RIFF.',
      '• Contenido Musical: canciones, fragmentos de audio, pistas instrumentales, introducciones musicales, grabaciones y demás recursos sonoros utilizados dentro de la Aplicación.',
      '• Cuenta: perfil individual asociado a un identificador de usuario mediante el cual se almacena su información y progreso.',
      '• Modo Invitado: modalidad de acceso que permite utilizar RIFF sin completar un proceso de registro permanente.',
      '• Monedas y Fichas: unidades virtuales utilizadas para determinadas funcionalidades y dinámicas internas del juego, sin valor monetario.',
      '• Servicios: funcionalidades disponibles en RIFF, incluyendo niveles, Adivina la Intro, Medley, salas multijugador, estadísticas, insignias y sistemas de progreso.',
    ],
  ),
  (
    '3. Aceptación de los Términos',
    [
      'El usuario deberá aceptar expresamente estos Términos antes de acceder a las funcionalidades principales de RIFF.',
      'La aceptación se realizará mediante la selección de la casilla correspondiente y la confirmación de la opción «Aceptar y continuar».',
      'En caso de no estar de acuerdo con las disposiciones establecidas, el usuario podrá seleccionar «No acepto», situación que impedirá el acceso a la Aplicación y dará lugar al cierre de la sesión.',
      'La aceptación se registrará por cuenta de usuario junto con la versión de los Términos aceptada. Cuando se publiquen modificaciones sustanciales, RIFF podrá solicitar una nueva aceptación antes de continuar utilizando sus servicios.',
      'El usuario deberá ser mayor de edad o contar con la autorización correspondiente de su representante legal cuando sea menor de edad. El tratamiento de datos personales de niños, niñas y adolescentes estará sujeto a las disposiciones legales aplicables en Colombia.',
    ],
  ),
  (
    '4. Descripción de los servicios',
    [
      'RIFF ofrece una experiencia de entretenimiento basada en el reconocimiento y conocimiento musical.',
      'La Aplicación incorpora las siguientes categorías musicales:',
      '• Vallenato.',
      '• Reggaetón.',
      '• Rock / Pop.',
      '• Salsa.',
      '• Música Popular.',
      'Asimismo, dispone de diferentes modalidades de juego:',
      '4.1. Niveles musicales: desafíos individuales en los que el usuario deberá identificar canciones a partir de fragmentos o pistas instrumentales.',
      '4.2. Adivina la Intro: modalidad en la que el usuario deberá reconocer una canción a partir de sus primeros segundos o introducción musical.',
      '4.3. Medley: modalidad que combina diferentes géneros musicales en una misma experiencia de juego.',
      '4.4. Salas multijugador: espacios de competencia en los que varios usuarios pueden participar simultáneamente y comparar sus resultados.',
      '4.5. Sistema de progreso: funcionalidades que permiten registrar estadísticas, partidas, victorias, insignias, monedas y demás avances obtenidos durante la experiencia de juego.',
      'RIFF podrá incorporar nuevas funcionalidades, modificar las existentes, actualizar sus dinámicas o retirar determinadas características cuando resulte necesario para mejorar el funcionamiento y la experiencia de usuario.',
      'La disponibilidad de una canción, modalidad o funcionalidad específica no constituye una garantía de permanencia dentro de la Aplicación.',
    ],
  ),
  (
    '5. Registro, cuentas y acceso',
    [
      'RIFF permite acceder a sus servicios mediante las siguientes modalidades:',
      '• Registro e inicio de sesión con correo electrónico y contraseña.',
      '• Autenticación mediante una cuenta de Google.',
      '• Acceso temporal mediante el Modo Invitado.',
      'El usuario se compromete a:',
      '• Proporcionar información veraz durante el registro.',
      '• Mantener la confidencialidad de sus credenciales de acceso.',
      '• No suplantar la identidad de terceros.',
      '• No crear cuentas con fines fraudulentos o para alterar el funcionamiento del juego.',
      '• Informar oportunamente cualquier acceso no autorizado del que tenga conocimiento.',
      '5.1. Modo Invitado: permite acceder a determinadas funcionalidades sin necesidad de crear una cuenta permanente. El progreso y los datos asociados a esta modalidad tienen carácter temporal. Al cerrar la sesión de invitado, la información correspondiente se elimina de acuerdo con el funcionamiento establecido por la Aplicación.',
      '5.2. Reinicio del progreso: el usuario podrá solicitar o ejecutar el reinicio de su progreso desde las opciones disponibles en Ajustes. Esta operación podrá implicar la eliminación de estadísticas, niveles completados, monedas, insignias y demás información de progreso. Una vez confirmada, podrá ser irreversible.',
    ],
  ),
  (
    '6. Propiedad intelectual y Contenido Musical',
    [
      'RIFF reconoce que las obras musicales, interpretaciones artísticas y grabaciones utilizadas en la Aplicación pertenecen a sus respectivos titulares de derechos.',
      'Estos pueden incluir autores, compositores, artistas intérpretes, productores fonográficos y editores musicales.',
      'La Aplicación no reclama la titularidad de las canciones ni de las grabaciones de terceros.',
      'En cada país, las sociedades de gestión colectiva administran determinados derechos de autor correspondientes a autores y compositores. Los derechos conexos de artistas intérpretes y productores fonográficos corresponden a sus respectivos titulares y pueden ser gestionados por las entidades competentes.',
      'El uso de contenido musical dentro de RIFF deberá contar con las autorizaciones o licencias que resulten legalmente exigibles.',
      'La finalidad educativa, cultural o recreativa de la Aplicación no constituye por sí misma una autorización para utilizar obras musicales o grabaciones protegidas.',
      'El usuario únicamente podrá acceder al contenido musical mediante las funcionalidades habilitadas dentro de RIFF y de acuerdo con las condiciones de uso aplicables.',
      'Queda prohibido:',
      '• Descargar o extraer grabaciones musicales desde la Aplicación.',
      '• Redistribuir o comercializar el contenido musical.',
      '• Reproducir públicamente el contenido fuera de los usos autorizados.',
      '• Utilizar las grabaciones para crear productos o servicios derivados sin autorización.',
      '• Eludir las medidas técnicas destinadas a proteger los recursos musicales.',
      'La relación de canciones y artistas utilizados se encuentra disponible en la sección Información → Créditos.',
    ],
  ),
  (
    '7. Reconocimiento y créditos musicales',
    [
      'RIFF reconoce la contribución artística y cultural de los autores, compositores, intérpretes y productores cuyas obras forman parte de su experiencia musical.',
      'Con el propósito de facilitar su identificación, la Aplicación dispone de una sección de créditos que presenta los títulos de las canciones y sus respectivos artistas, incluyendo colaboradores cuando corresponda.',
      'La información de los créditos se proporciona con fines de identificación y reconocimiento. Su publicación no implica que RIFF sea propietario de las obras o grabaciones mencionadas.',
      'La música utilizada como ambientación en los menús también pertenece a sus respectivos titulares.',
    ],
  ),
  (
    '8. Reclamaciones y solicitudes sobre contenido musical',
    [
      'Los titulares de derechos de autor, derechos conexos o sus representantes podrán presentar solicitudes relacionadas con el contenido musical disponible en RIFF.',
      'Las solicitudes podrán estar relacionadas con:',
      '• Uso no autorizado de una obra o grabación.',
      '• Corrección de títulos o créditos musicales.',
      '• Identificación de autores, intérpretes o colaboradores.',
      '• Solicitudes de retiro de contenido.',
      'Para presentar una reclamación, deberá enviarse una comunicación al correo electrónico jpaulogutierrez@unicesar.edu.co.',
      'La solicitud deberá incluir la identificación del solicitante, su relación con los derechos reclamados, la identificación del contenido correspondiente y una descripción de la petición.',
      'RIFF evaluará las solicitudes recibidas y adoptará las medidas que correspondan conforme a la legislación aplicable.',
    ],
  ),
  (
    '9. Licencia de uso de la Aplicación',
    [
      'RIFF concede al usuario una licencia de uso personal, limitada, gratuita, revocable, no exclusiva e intransferible para acceder y utilizar las funcionalidades de la Aplicación.',
      'Esta licencia no implica la transferencia de derechos de propiedad intelectual sobre RIFF ni sobre los elementos que lo componen.',
      'Salvo autorización expresa, queda prohibido:',
      '• Copiar, modificar o distribuir el código fuente.',
      '• Comercializar, sublicenciar o transferir la Aplicación.',
      '• Utilizar el nombre, logotipo o elementos gráficos de RIFF sin autorización.',
      '• Crear versiones derivadas de la Aplicación con fines comerciales sin el consentimiento correspondiente.',
      '• Eliminar avisos de propiedad intelectual o mecanismos de identificación.',
      'El nombre RIFF, su identidad visual, interfaz, diseño, textos y demás elementos originales del proyecto se encuentran protegidos por las disposiciones aplicables en materia de propiedad intelectual.',
      '© 2026 Joannes Gutierrez. Todos los derechos reservados, respecto de los elementos de los que sea titular.',
    ],
  ),
  (
    '10. Conductas prohibidas',
    [
      'El usuario se compromete a utilizar RIFF de manera responsable, respetuosa y conforme a la legislación vigente.',
      'En consecuencia, se prohíben las siguientes conductas:',
      '• Alterar, modificar o manipular los archivos internos de la Aplicación.',
      '• Realizar ingeniería inversa o intentar obtener información técnica protegida.',
      '• Extraer, copiar o distribuir recursos musicales sin autorización.',
      '• Utilizar programas automatizados, scripts o herramientas para alterar resultados.',
      '• Obtener monedas, fichas o beneficios mediante mecanismos fraudulentos.',
      '• Aprovechar errores o vulnerabilidades para obtener ventajas indebidas.',
      '• Interferir con el funcionamiento de los servidores o servicios tecnológicos.',
      '• Suplantar la identidad de otros usuarios.',
      '• Realizar actos de acoso, intimidación o discriminación dentro de las salas.',
      '• Publicar mensajes ofensivos, ilegales o que vulneren los derechos de terceros.',
      '• Compartir respuestas o información confidencial de las partidas con el propósito de alterar sus resultados.',
      '• Utilizar RIFF para actividades contrarias a la ley.',
      'El incumplimiento de estas disposiciones podrá dar lugar a medidas correctivas, restricciones, suspensión o cancelación de la cuenta, según la gravedad de la conducta.',
    ],
  ),
  (
    '11. Monedas virtuales y economía del juego',
    [
      'RIFF incorpora un sistema de unidades virtuales destinado a complementar la experiencia de juego.',
      'Entre estos elementos se encuentran las monedas por género musical, las monedas de Medley, las fichas de las salas y el presupuesto disponible durante determinadas partidas.',
      'Estos elementos:',
      '• Son recursos exclusivamente virtuales.',
      '• No representan dinero ni instrumentos financieros.',
      '• No tienen valor monetario ni generan rendimientos.',
      '• No pueden convertirse en dinero real.',
      '• No pueden venderse, transferirse o canjearse fuera de las condiciones habilitadas por RIFF.',
      '• No generan derechos económicos a favor del usuario.',
      'RIFF podrá realizar ajustes en el funcionamiento de su economía virtual para corregir errores, prevenir usos indebidos o mantener el equilibrio de las partidas.',
      'Cualquier modificación deberá respetar las disposiciones legales aplicables y las condiciones de los servicios ofrecidos.',
    ],
  ),
  (
    '12. Salas multijugador y competencia',
    [
      'Las salas multijugador permiten la participación de hasta diez (10) usuarios en una misma partida, de acuerdo con las condiciones técnicas de la Aplicación.',
      'Al ingresar a una sala, el nombre de jugador y determinados resultados de la partida podrán ser visibles para los demás participantes.',
      'El usuario deberá mantener una conducta respetuosa durante las competencias y abstenerse de realizar acciones que perjudiquen la experiencia de los demás participantes.',
      'RIFF podrá adoptar medidas frente a comportamientos que afecten la integridad de las partidas, incluyendo la expulsión de participantes, cierre de salas o suspensión de cuentas cuando corresponda.',
      'Las estadísticas, victorias, podios, fichas e insignias se almacenan como parte del progreso del usuario y podrán ser corregidas cuando se detecten errores técnicos o irregularidades.',
    ],
  ),
  (
    '13. Tratamiento de datos personales y privacidad',
    [
      'El tratamiento de los datos personales recopilados mediante RIFF se realizará de conformidad con la Ley 1581 de 2012, el Decreto 1377 de 2013 y las demás disposiciones aplicables en Colombia.',
      '13.1. Información recopilada. Dependiendo de la modalidad de acceso y las funcionalidades utilizadas, RIFF podrá tratar:',
      '• Datos de identificación de la cuenta, incluyendo correo electrónico e identificador único.',
      '• Nombre y fotografía de perfil cuando se utilice autenticación mediante Google.',
      '• Información relacionada con el progreso, niveles, partidas, monedas, fichas, insignias y estadísticas.',
      '• Información técnica necesaria para garantizar el funcionamiento, estabilidad y seguridad de la Aplicación.',
      '• Preferencias de configuración y archivos temporales almacenados en el dispositivo.',
      '13.2. Finalidades del tratamiento. Los datos personales podrán utilizarse para:',
      '• Gestionar el registro y la autenticación de usuarios.',
      '• Mantener y sincronizar el progreso de las partidas.',
      '• Habilitar las funcionalidades multijugador.',
      '• Administrar estadísticas, insignias y sistemas de juego.',
      '• Garantizar la seguridad de las cuentas.',
      '• Detectar y prevenir actividades fraudulentas.',
      '• Identificar errores y mejorar el funcionamiento de RIFF.',
      '13.3. Proveedores tecnológicos. RIFF utiliza servicios tecnológicos de terceros para el funcionamiento de determinadas funcionalidades, entre ellos:',
      '• Google Firebase, para servicios de autenticación y almacenamiento de información.',
      '• Supabase, para servicios de almacenamiento y procesamiento de información en el servidor.',
      'Estos proveedores podrán tratar información de acuerdo con las condiciones contractuales y políticas de privacidad correspondientes. Cuando resulte aplicable, las operaciones internacionales de transmisión o transferencia de datos estarán sujetas a los requisitos legales correspondientes.',
      '13.4. Derechos del titular. El usuario podrá ejercer los siguientes derechos:',
      '• Conocer, actualizar y rectificar sus datos personales.',
      '• Solicitar información sobre el tratamiento realizado.',
      '• Solicitar prueba de la autorización otorgada, cuando corresponda.',
      '• Presentar consultas y reclamaciones.',
      '• Solicitar la revocatoria de la autorización o la supresión de sus datos cuando legalmente proceda.',
      '• Presentar quejas ante la Superintendencia de Industria y Comercio.',
      '• Acceder gratuitamente a sus datos personales.',
      '13.5. Conservación de la información. Los datos se conservarán durante el tiempo necesario para cumplir las finalidades informadas y las obligaciones legales correspondientes. En el Modo Invitado, la información temporal asociada a la sesión se elimina al cerrarla, de acuerdo con el funcionamiento de la Aplicación.',
      '13.6. Menores de edad. El tratamiento de datos personales de niños, niñas y adolescentes se realizará respetando su interés superior, sus derechos fundamentales y las condiciones especiales establecidas por la legislación colombiana. La autorización correspondiente deberá obtenerse cuando sea legalmente exigible.',
      '13.7. Canal de atención. Para ejercer los derechos relacionados con los datos personales, presentar consultas o formular reclamaciones, el usuario podrá comunicarse mediante jpaulogutierrez@unicesar.edu.co. La autorización para el tratamiento de datos personales deberá documentarse de manera previa, expresa e informada, conforme a las disposiciones aplicables.',
    ],
  ),
  (
    '14. Conectividad, disponibilidad y almacenamiento de audio',
    [
      'RIFF requiere conexión a internet para acceder a sus servicios y consultar la información almacenada en sus servidores.',
      'En la versión Android, determinadas canciones desbloqueadas podrán almacenarse temporalmente en la memoria caché del dispositivo con el propósito de mejorar los tiempos de reproducción.',
      'Estos archivos se utilizan exclusivamente dentro de la experiencia de la Aplicación y no constituyen una autorización para su extracción o distribución.',
      'En la versión web, el contenido musical se solicita al servidor cuando corresponde a una canción previamente desbloqueada. Según la implementación descrita, no se conserva una caché local de archivos de audio.',
      'La disponibilidad de RIFF podrá verse afectada por labores de mantenimiento, problemas de conectividad, interrupciones de proveedores externos o circunstancias técnicas ajenas al control del proyecto.',
      'Por lo tanto, no se garantiza la disponibilidad permanente e ininterrumpida de todos los servicios.',
    ],
  ),
  (
    '15. Suspensión y terminación del acceso',
    [
      'RIFF podrá restringir temporal o definitivamente el acceso de un usuario cuando se presenten circunstancias que justifiquen dicha medida, entre ellas:',
      '• Incumplimiento de estos Términos.',
      '• Actividades fraudulentas o manipulación de resultados.',
      '• Vulneración de derechos de terceros.',
      '• Uso indebido de los servicios tecnológicos.',
      '• Requerimientos de autoridades competentes.',
      '• Circunstancias técnicas o legales que hagan necesaria la suspensión de determinadas funcionalidades.',
      'El usuario podrá dejar de utilizar RIFF en cualquier momento, cerrar su sesión o solicitar la eliminación de su información personal mediante los canales habilitados.',
      'La terminación del acceso no afectará los derechos que correspondan al usuario conforme a la legislación vigente.',
    ],
  ),
  (
    '16. Garantías y limitaciones del servicio',
    [
      'RIFF se proporciona conforme a las funcionalidades y condiciones técnicas disponibles en cada versión.',
      'Aunque se procura mantener una experiencia estable y segura, pueden presentarse errores, interrupciones, inconsistencias en los datos o limitaciones derivadas de servicios de terceros.',
      'El responsable del proyecto realizará esfuerzos razonables para corregir los problemas identificados y mantener el funcionamiento adecuado de la Aplicación.',
      'Estas disposiciones no excluyen ni limitan las garantías o derechos que sean irrenunciables conforme a la legislación colombiana.',
    ],
  ),
  (
    '17. Responsabilidad',
    [
      'El usuario es responsable del uso que realice de su cuenta y de las acciones que ejecute dentro de la Aplicación.',
      'RIFF no será responsable por situaciones que se deriven exclusivamente de factores externos fuera de su control, como interrupciones de conectividad, fallas de proveedores tecnológicos o problemas del dispositivo del usuario.',
      'Tampoco se asume responsabilidad por las conductas individuales de otros participantes en las salas multijugador, sin perjuicio de las medidas que puedan adoptarse frente a comportamientos contrarios a estos Términos.',
      'Las limitaciones de responsabilidad aquí establecidas se aplicarán únicamente en la medida permitida por la legislación colombiana y no afectarán los derechos irrenunciables de los consumidores.',
    ],
  ),
  (
    '18. Modificaciones y actualizaciones',
    [
      'RIFF podrá actualizar sus funcionalidades, características, contenidos y estos Términos cuando sea necesario.',
      'Las modificaciones podrán responder a:',
      '• Cambios tecnológicos.',
      '• Incorporación de nuevas modalidades.',
      '• Ajustes en las reglas del juego.',
      '• Actualizaciones legales.',
      '• Mejoras de seguridad y privacidad.',
      '• Cambios en los servicios de terceros.',
      'La versión vigente de estos Términos estará disponible en la sección Ajustes → Información.',
      'Cuando se introduzcan modificaciones sustanciales, se informará al usuario y se solicitará una nueva aceptación cuando corresponda.',
    ],
  ),
  (
    '19. Legislación aplicable y resolución de controversias',
    [
      'Estos Términos se interpretarán y aplicarán de conformidad con las leyes de la República de Colombia.',
      'Las diferencias que puedan surgir entre el usuario y el responsable de RIFF procurarán resolverse inicialmente mediante comunicación directa y mecanismos de solución amistosa.',
      'Cuando no sea posible alcanzar un acuerdo, las partes podrán acudir a las autoridades y mecanismos judiciales o administrativos competentes.',
      'Lo anterior se entiende sin perjuicio de las competencias de la Superintendencia de Industria y Comercio y de las demás autoridades correspondientes.',
    ],
  ),
  (
    '20. Disposiciones finales',
    [
      'Si alguna disposición de estos Términos es declarada inválida, ilegal o inaplicable, las demás disposiciones conservarán su vigencia en la medida permitida por la ley.',
      'La falta de exigencia inmediata de alguna obligación no constituye renuncia a los derechos derivados de estos Términos.',
      'El presente documento constituye el marco general de condiciones para el acceso y utilización de RIFF, sin perjuicio de las políticas adicionales que resulten aplicables a determinados servicios.',
      'Responsable del proyecto: Joannes Gutierrez. Contacto: jpaulogutierrez@unicesar.edu.co.',
    ],
  ),
];

const cierreTerminos =
    'RIFF — La música se convierte en un desafío.\n© 2026 Joannes Gutierrez. Todos los derechos reservados.';

const avisoCreditos =
    'Las canciones de RIFF se usan con fines educativos y culturales, sin ánimo de lucro. Los derechos sobre cada obra y grabación pertenecen a sus autores, compositores, artistas, productores y editores, o a las sociedades de gestión colectiva que los representan en cada país. RIFF no es dueño de esas canciones ni reclama ningún derecho sobre ellas. Si eres titular de derechos y quieres corregir un crédito o retirar una canción, escríbenos a jpaulogutierrez@unicesar.edu.co.';

/// Música de fondo de los menús: (grupo, [(título, autor)]).
const musicaMenuCreditos = <(String, List<(String, String)>)>[
  (
    'Menús de los géneros: vallenato',
    [
      ('Intro (Saludos Inicio)', 'El Gran Martín Elías'),
      (
        'Pista de ambientación 2',
        'Autor original sin identificar (fuente: YouTube)',
      ),
      (
        'Pista de ambientación 3',
        'Autor original sin identificar (fuente: YouTube)',
      ),
    ],
  ),
  (
    'Menús de los géneros: salsa',
    [
      (
        'Super Salsa Mix Vol. 3: Puro Sabor',
        'DJ Marlong Son (fuente: YouTube)',
      ),
      (
        'Una Experiencia Musical (Pacific Live)',
        'DJ Marlong Son (fuente: YouTube)',
      ),
    ],
  ),
  (
    'Menús de los géneros: rock / pop',
    [
      ('Mix Rock Clásico Corto', 'DJ V (fuente: YouTube)'),
      (
        'Psychedelic Classic Rock Blues Guitar Mix (Tribute)',
        'Pink Floyd y Black Sabbath, mezcla de tributo (fuente: YouTube)',
      ),
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
      (
        'Ayer Te Soñé (ranchera)',
        'Autor original sin identificar (fuente: YouTube)',
      ),
      (
        'Esta letra te hará pensar en tu vida',
        'Autor original sin identificar (fuente: YouTube)',
      ),
    ],
  ),
  (
    'Menú principal, Medley y salas',
    [
      ('Bossa Nova Instrumental 2024', 'Música instrumental (fuente: YouTube)'),
      (
        'Bossa Nova Jazz para Relajarte',
        'Música instrumental (fuente: YouTube)',
      ),
      (
        'Cafe Music (música ambiental instrumental)',
        'Música instrumental (fuente: YouTube)',
      ),
      ('Relaxing Bossa Nova Vibes', 'Música instrumental (fuente: YouTube)'),
    ],
  ),
];
