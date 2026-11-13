part of 'home_screen.dart';

/// Pide la contraseña (o Google) otra vez: las acciones que borran datos exigen
/// haber confirmado la cuenta hace poco. false si el usuario cancela.
Future<bool> _reautenticar(
  BuildContext context,
  User user,
  String accion,
) async {
  final conCorreo = user.providerData.any(
    (proveedor) => proveedor.providerId == 'password',
  );
  if (conCorreo) {
    final clave = await showDialog<String>(
      context: context,
      builder: (_) => DialogoContrasena(accion: accion),
    );
    if (clave == null) return false;
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email!, password: clave),
    );
  } else if (kIsWeb) {
    // Web: google_sign_in no tiene authenticate(); se usa la ventana de Firebase.
    await user.reauthenticateWithPopup(GoogleAuthProvider());
  } else {
    await prepararGoogle();
    final cuenta = await GoogleSignIn.instance.authenticate();
    final idToken = cuenta.authentication.idToken;
    if (idToken == null) throw StateError('Google no confirmó la cuenta.');
    await user.reauthenticateWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }
  return true;
}

/// Eliminar la cuenta: confirma, pide la contraseña (o Google) de nuevo, borra
/// los datos en el servidor y después el usuario de Firebase.
Future<void> _borrarCuenta(BuildContext context, WidgetRef ref) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (context) => LiquidGlassDialog(
      icon: const Icon(Icons.delete_forever_rounded, size: 56),
      title: const Text('¿Eliminar tu cuenta?', textAlign: TextAlign.center),
      content: const Text(
        'Se borrarán tu cuenta y todos tus datos: niveles, intros, monedas, '
        'fichas, estadísticas e insignias. No se puede deshacer.',
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  final user = FirebaseAuth.instance.currentUser;
  if (confirmar != true || user == null || !context.mounted) return;
  final mensajes = ScaffoldMessenger.of(context);
  final navegador = Navigator.of(context);
  try {
    if (!await _reautenticar(context, user, 'Eliminar')) return;
    await ref.read(firebaseGameRepositoryProvider).borrarCuenta();
    await InsigniasVistas(user.uid).borrar();
    await user.delete();
    navegador.popUntil((route) => route.isFirst);
    mensajes.showSnackBar(
      const SnackBar(content: Text('Tu cuenta fue eliminada.')),
    );
  } catch (error) {
    final mensaje = switch (error) {
      FirebaseAuthException(code: 'wrong-password' || 'invalid-credential') =>
        'La contraseña no es correcta.',
      FirebaseAuthException(code: 'requires-recent-login') =>
        'Confirma tu cuenta otra vez e inténtalo de nuevo.',
      GameRepositoryException(:final message) => message,
      _ => 'No se pudo eliminar la cuenta: $error',
    };
    mensajes.showSnackBar(SnackBar(content: Text(mensaje)));
  }
}

/// Empezar desde cero: confirma, pide la contraseña (o Google) de nuevo y
/// borra el progreso de todos los géneros en el servidor y en el teléfono.
/// [alEmpezar] corre ya confirmada la cuenta. Devuelve si se reinició.
Future<bool> _reiniciarCuenta(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? alEmpezar,
}) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (context) => LiquidGlassDialog(
      icon: const Icon(Icons.warning_amber_rounded, size: 56),
      title: const Text('¿Empezar desde cero?', textAlign: TextAlign.center),
      content: const Text(
        'Se borrarán tus niveles, intros, monedas, fichas, estadísticas de '
        'salas e insignias. No se puede deshacer.',
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
  final user = FirebaseAuth.instance.currentUser;
  if (confirmar != true || user == null || !context.mounted) return false;
  final mensajes = ScaffoldMessenger.of(context);
  try {
    if (!await _reautenticar(context, user, 'Reiniciar')) return false;
    alEmpezar?.call();
    await ref.read(firebaseGameRepositoryProvider).reiniciarProgreso();
    await InsigniasVistas(user.uid).borrar();
    mensajes.showSnackBar(
      const SnackBar(content: Text('Tu progreso empezó desde cero.')),
    );
    return true;
  } catch (error) {
    final mensaje = switch (error) {
      FirebaseAuthException(code: 'wrong-password' || 'invalid-credential') =>
        'La contraseña no es correcta.',
      GameRepositoryException(:final message) => message,
      _ => 'No se pudo reiniciar el progreso: $error',
    };
    mensajes.showSnackBar(SnackBar(content: Text(mensaje)));
    return false;
  }
}

/// Cierra la sesión; la de invitado se borra entera. Las pantallas abiertas
/// encima (ajustes, salas) se cierran con ella.
Future<void> _cerrarSesionDe(
  BuildContext context,
  WidgetRef ref,
  User user,
) async {
  final mensajes = ScaffoldMessenger.of(context);
  Navigator.of(context).popUntil((route) => route.isFirst);
  try {
    if (user.isAnonymous) {
      await ref.read(firebaseGameRepositoryProvider).finalizarSesionInvitado();
      await user.delete();
    }
    await FirebaseAuth.instance.signOut();
  } catch (error) {
    mensajes.showSnackBar(
      SnackBar(content: Text('No se pudo cerrar sesión: $error')),
    );
  }
}

class _PestanaConfiguracion extends ConsumerStatefulWidget {
  const _PestanaConfiguracion({
    super.key,
    this.onRecorrido,
    required this.onCerrarSesion,
    this.onReiniciar,
  });

  // null fuera de un género: el recorrido explica el menú del género.
  final VoidCallback? onRecorrido;
  final VoidCallback onCerrarSesion;
  // null para invitados: su progreso ya se borra al salir.
  final VoidCallback? onReiniciar;

  @override
  ConsumerState<_PestanaConfiguracion> createState() =>
      _PestanaConfiguracionState();
}

class _PestanaConfiguracionState extends ConsumerState<_PestanaConfiguracion> {
  @override
  Widget build(BuildContext context) {
    final musica = ref.read(musicaMenuProvider);
    final oscuro = context.paleta.oscuro;
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: max(16, (MediaQuery.sizeOf(context).width - 680) / 2),
        vertical: 16,
      ),
      children: [
        LiquidGlassCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.menu_book_rounded),
                title: const Text('Instrucciones'),
                subtitle: const Text('Cómo se juega cada modo'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => mostrarInstrucciones(context),
              ),
              if (widget.onRecorrido != null)
                ListTile(
                  leading: const Icon(Icons.tour_rounded),
                  title: const Text('Recorrido guiado'),
                  subtitle: const Text('Las burbujas que explican la app'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: widget.onRecorrido,
                ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Información'),
                subtitle: const Text('Términos y condiciones y créditos'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => mostrarInformacion(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LiquidGlassCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              // En el navegador no suena la música del menú.
              if (!kIsWeb)
                SwitchListTile(
                  secondary: Icon(
                    musica.silenciada
                        ? PhosphorIconsFill.speakerSlash
                        : PhosphorIconsFill.musicNotes,
                  ),
                  title: const Text('Música del menú'),
                  value: !musica.silenciada,
                  onChanged: (_) async {
                    await musica.alternarSilencio();
                    if (mounted) setState(() {});
                  },
                ),
              SwitchListTile(
                secondary: Icon(
                  oscuro ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                ),
                title: const Text('Modo oscuro'),
                value: oscuro,
                onChanged: (valor) => ref
                    .read(modoTemaProvider.notifier)
                    .cambiar(valor ? ThemeMode.dark : ThemeMode.light),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (widget.onReiniciar case final reiniciar?) ...[
          LiquidGlassCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: Icon(
                Icons.restart_alt_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Reiniciar progreso',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              subtitle: const Text('Empezar el juego desde cero'),
              onTap: reiniciar,
            ),
          ),
          const SizedBox(height: 16),
          LiquidGlassCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: Icon(
                Icons.delete_forever_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Eliminar cuenta',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              subtitle: const Text('Borra tu cuenta y todos tus datos'),
              onTap: () => _borrarCuenta(context, ref),
            ),
          ),
          const SizedBox(height: 16),
        ],
        LiquidGlassCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: Icon(
              Icons.logout_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Cerrar sesión',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: widget.onCerrarSesion,
          ),
        ),
      ],
    );
  }
}
