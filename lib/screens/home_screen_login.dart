part of 'home_screen.dart';

class FirebaseAuthScreen extends StatefulWidget {
  const FirebaseAuthScreen({super.key, this.savedUser, this.onSignedIn});

  final User? savedUser;
  final VoidCallback? onSignedIn;

  @override
  State<FirebaseAuthScreen> createState() => _FirebaseAuthScreenState();
}

class _FirebaseAuthScreenState extends State<FirebaseAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _registering = false;
  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _mostrarErrorAcceso({
    Object? error,
    String? codigo,
    String? mensaje,
    bool inicioConCorreo = false,
  }) async {
    if (error is FirebaseAuthException) {
      codigo = error.code;
      mensaje = error.message ?? error.code;
    }

    final alerta = switch (codigo) {
      'network-request-failed' => 'No hay conexión a internet.',
      'wrong-password' ||
      'user-not-found' ||
      'invalid-credential' ||
      'invalid-login-credentials' ||
      'invalid-email' when inicioConCorreo => 'Correo o usuario incorrecto.',
      _ when error is SocketException || error is TimeoutException =>
        'No hay conexión a internet.',
      _ => null,
    };

    if (!mounted) return;
    if (alerta == null) {
      setState(() => _error = mensaje ?? error.toString());
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => LiquidGlassDialog(
        icon: Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
          size: 36,
        ),
        title: const Text('Error de inicio de sesión'),
        content: Text(alerta),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (_registering) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        await credential.user?.updateDisplayName(_name.text.trim());
      } else {
        await auth.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      widget.onSignedIn?.call();
    } on FirebaseAuthException catch (error) {
      await _mostrarErrorAcceso(error: error, inicioConCorreo: !_registering);
    } catch (error) {
      await _mostrarErrorAcceso(error: error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      } else {
        await prepararGoogle();
        final account = await GoogleSignIn.instance.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw StateError('Google no devolvió un token de autenticación.');
        }
        final credential = GoogleAuthProvider.credential(idToken: idToken);
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
      widget.onSignedIn?.call();
    } on FirebaseAuthException catch (error) {
      await _mostrarErrorAcceso(error: error);
    } on GoogleSignInException catch (error) {
      if (error.code.name.toLowerCase().contains('network')) {
        await _mostrarErrorAcceso(codigo: 'network-request-failed');
      } else if (mounted) {
        setState(() {
          _error = error.code == GoogleSignInExceptionCode.canceled
              ? 'Se canceló el inicio de sesión con Google.'
              : error.description ?? error.code.name;
        });
      }
    } catch (error) {
      await _mostrarErrorAcceso(error: error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInAnonymously();
      widget.onSignedIn?.call();
    } on FirebaseAuthException catch (error) {
      await _mostrarErrorAcceso(error: error);
    } catch (error) {
      await _mostrarErrorAcceso(error: error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Botones y enlaces con los azules del logo (celeste en modo oscuro).
    final tema = Theme.of(context);
    return Theme(
      data: tema.copyWith(
        colorScheme: tema.colorScheme.copyWith(
          primary: context.paleta.oscuro ? celesteLogin : azulLogin,
        ),
      ),
      child: Scaffold(
        // Sin pantalla de carga: los botones se desactivan mientras entra y
        // después sale la bienvenida con el nombre.
        body: Stack(
          fit: StackFit.expand,
          children: [
            const FondoLogin(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LiquidGlassCard(
                            // Más opaca y con borde azul del logo: resalta
                            // sobre el fondo y el texto se lee bien.
                            opacity: 0.6,
                            borderRadius: 28,
                            borderColor: azulLogin,
                            padding: const EdgeInsets.all(24),
                            // Campos con contorno cian y etiqueta arriba.
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                inputDecorationTheme: camposLogin(context),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Center(child: LogoCircular()),
                                      // Dentro de la tarjeta: arriba no
                                      // tapa su borde.
                                      Positioned(
                                        top: -12,
                                        right: -12,
                                        child: _AjustesLogin(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _registering
                                        ? 'Crea tu cuenta'
                                        : 'Bienvenido',
                                    textAlign: TextAlign.center,
                                    style: text.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Pon a prueba tu oído y descubre la melodía',
                                    textAlign: TextAlign.center,
                                    style: text.bodyMedium?.copyWith(
                                      color: context.paleta.tintaSuave,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  if (_registering) ...[
                                    TextFormField(
                                      controller: _name,
                                      textInputAction: TextInputAction.next,
                                      decoration: const InputDecoration(
                                        labelText: 'Nombre',
                                        prefixIcon: Icon(Icons.person_outline),
                                      ),
                                      validator: (value) =>
                                          value == null || value.trim().isEmpty
                                          ? 'Escribe tu nombre'
                                          : null,
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  TextFormField(
                                    controller: _email,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Correo',
                                      prefixIcon: Icon(Icons.mail_outline),
                                    ),
                                    validator: (value) => validarCorreo(
                                      value,
                                      registrando: _registering,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _password,
                                    obscureText: !_showPassword,
                                    decoration: InputDecoration(
                                      labelText: 'Contraseña',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                      ),
                                      suffixIcon: IconButton(
                                        tooltip: _showPassword
                                            ? 'Ocultar contraseña'
                                            : 'Mostrar contraseña',
                                        onPressed: () => setState(
                                          () => _showPassword = !_showPassword,
                                        ),
                                        icon: Icon(
                                          _showPassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                        ),
                                      ),
                                    ),
                                    validator: (value) => validarClave(
                                      value,
                                      registrando: _registering,
                                    ),
                                  ),
                                  if (_error != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      _error!,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  BotonDegradado(
                                    onPressed: _busy ? null : _submit,
                                    label: _registering
                                        ? 'Crear cuenta'
                                        : 'Iniciar sesión',
                                  ),
                                  // El invitado ya tiene "Jugar sin registrarme",
                                  // que retoma la misma sesión anónima.
                                  if (!_registering &&
                                      widget.savedUser != null &&
                                      !widget.savedUser!.isAnonymous) ...[
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : widget.onSignedIn,
                                      icon: const Icon(
                                        Icons.play_circle_outline,
                                      ),
                                      label: Text(
                                        'Continuar como ${_nombreSesion(widget.savedUser!)}',
                                      ),
                                    ),
                                  ],
                                  if (!_registering) ...[
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        const Expanded(child: Divider()),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Text(
                                            'o',
                                            style: text.bodySmall,
                                          ),
                                        ),
                                        const Expanded(child: Divider()),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : _signInWithGoogle,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      icon: const _LogoGoogle(),
                                      label: const Text('Continuar con Google'),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : _continueAsGuest,
                                      icon: const Icon(
                                        Icons.sports_esports_outlined,
                                      ),
                                      label: const Text(
                                        'Jugar sin registrarme',
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                    _registering = !_registering;
                                    _error = null;
                                  }),
                            child: Text(
                              _registering
                                  ? '¿Ya tienes cuenta? Inicia sesión'
                                  : '¿No tienes cuenta? Crea una nueva',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ajustes del login: modo claro u oscuro, música del menú e instrucciones.
class _AjustesLogin extends ConsumerStatefulWidget {
  const _AjustesLogin();

  @override
  ConsumerState<_AjustesLogin> createState() => _AjustesLoginState();
}

class _AjustesLoginState extends ConsumerState<_AjustesLogin> {
  @override
  Widget build(BuildContext context) {
    final oscuro = context.paleta.oscuro;
    final musica = ref.read(musicaMenuProvider);
    return PopupMenuButton<String>(
      tooltip: 'Ajustes',
      icon: const Icon(Icons.settings_rounded),
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      ),
      onSelected: (opcion) async {
        switch (opcion) {
          case 'tema':
            await ref
                .read(modoTemaProvider.notifier)
                .cambiar(oscuro ? ThemeMode.light : ThemeMode.dark);
          case 'musica':
            await musica.alternarSilencio();
            if (mounted) setState(() {});
          case 'instrucciones':
            if (context.mounted) await mostrarInstrucciones(context);
          case 'informacion':
            if (context.mounted) await mostrarInformacion(context);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'tema',
          child: ListTile(
            leading: Icon(
              oscuro ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
            title: Text(oscuro ? 'Modo claro' : 'Modo oscuro'),
          ),
        ),
        if (!kIsWeb)
          PopupMenuItem(
            value: 'musica',
            child: ListTile(
              leading: Icon(
                musica.silenciada
                    ? PhosphorIconsFill.musicNotes
                    : PhosphorIconsFill.speakerSlash,
              ),
              title: Text(
                musica.silenciada ? 'Activar música' : 'Silenciar música',
              ),
            ),
          ),
        const PopupMenuItem(
          value: 'instrucciones',
          child: ListTile(
            leading: Icon(Icons.menu_book_rounded),
            title: Text('Instrucciones'),
          ),
        ),
        const PopupMenuItem(
          value: 'informacion',
          child: ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('Información'),
          ),
        ),
      ],
    );
  }
}

/// "G" de Google en sus cuatro colores, dibujada para no sumar una
/// dependencia de SVG.
class _LogoGoogle extends StatelessWidget {
  const _LogoGoogle();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: Size.square(20), painter: _GooglePainter());
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final centro = size.center(Offset.zero);
    final grosor = r * 0.38;
    final aro = Rect.fromCircle(center: centro, radius: r - grosor / 2);
    double grados(double g) => g * pi / 180;
    // Ángulos en sentido horario desde las 3 en punto; la abertura de la G
    // queda arriba a la derecha.
    for (final (inicio, barrido, color) in [
      (-40.0, -140.0, const Color(0xFFEA4335)), // rojo, arriba
      (180.0, -45.0, const Color(0xFFFBBC05)), // amarillo, izquierda
      (135.0, -95.0, const Color(0xFF34A853)), // verde, abajo
      (40.0, -40.0, const Color(0xFF4285F4)), // azul, derecha
    ]) {
      canvas.drawArc(
        aro,
        grados(inicio),
        grados(barrido),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = grosor
          ..color = color,
      );
    }
    // Barra horizontal de la G.
    canvas.drawRect(
      Rect.fromLTWH(centro.dx, centro.dy - grosor / 2, r, grosor),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(_GooglePainter oldDelegate) => false;
}
