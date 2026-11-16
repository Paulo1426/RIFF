part of 'home_screen.dart';

/// Progreso: arriba el general (niveles de las tres dificultades más las
/// intros adivinadas) y debajo cada dificultad y las intros por separado.
class _ProgresoGeneral extends StatelessWidget {
  const _ProgresoGeneral({
    required this.dificultades,
    required this.intros,
    required this.cargandoIntros,
  });

  // Niveles por dificultad y total de intros del género que se juega (Medley
  // 15 y 100). shortcut: si cambian en el servidor hay que actualizarlos en
  // Genero; las dificultades bloqueadas llegan con 0.
  static int get _nivelesPorDificultad => generoActivo.nivelesPorDificultad;
  static int get _totalIntros => generoActivo.totalIntros;

  final List<ProgresoDificultadRemoto> dificultades;
  final EstadoIntros? intros;
  final bool cargandoIntros;

  /// Avance total del juego (niveles más intros adivinadas), de 0 a 1.
  static double porcentajeDe(
    List<ProgresoDificultadRemoto> dificultades,
    EstadoIntros? intros,
  ) {
    final totalNiveles = dificultades.length * _nivelesPorDificultad;
    final niveles = dificultades.fold<int>(
      0,
      (sum, item) => sum + item.completados,
    );
    final totalIntros = intros == null
        ? _totalIntros
        : intros.intros.length + intros.restantes;
    final adivinadas =
        intros?.intros
            .where((item) => item.estado == EstadoIntro.completada)
            .length ??
        0;
    final total = totalNiveles + totalIntros;
    return total == 0 ? 0.0 : (niveles + adivinadas) / total;
  }

  static Widget _fila(
    BuildContext context, {
    required String nombre,
    required int hechos,
    required int total,
    required Color color,
    String? detalle,
  }) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(nombre, style: text.titleSmall)),
              Text('$hechos/$total', style: text.bodySmall),
            ],
          ),
          if (detalle != null)
            Text(
              detalle,
              style: text.bodySmall?.copyWith(color: context.paleta.tintaSuave),
            ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : hechos / total,
              minHeight: 6,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final totalNiveles = dificultades.length * _nivelesPorDificultad;
    final niveles = dificultades.fold<int>(
      0,
      (sum, item) => sum + item.completados,
    );
    final intros = this.intros;
    final totalIntros = intros == null
        ? _totalIntros
        : intros.intros.length + intros.restantes;
    final adivinadas =
        intros?.intros
            .where((item) => item.estado == EstadoIntro.completada)
            .length ??
        0;
    final porcentaje = porcentajeDe(dificultades, intros);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${(porcentaje * 100).round()}%',
          textAlign: TextAlign.center,
          // Color del género, del tema de su menú.
          style: text.displaySmall,
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(value: porcentaje, minHeight: 12),
        ),
        const SizedBox(height: 8),
        Text(
          '$niveles de $totalNiveles niveles · $adivinadas de $totalIntros intros',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: context.paleta.tintaSuave),
        ),
        const SizedBox(height: 20),
        for (final item in dificultades)
          _fila(
            context,
            nombre: _nombreDificultad(item.dificultad),
            hechos: item.completados,
            total: max(item.total, _nivelesPorDificultad),
            color: colorDificultad(item.dificultad),
          ),
        cargandoIntros
            ? const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 6),
              )
            : _fila(
                context,
                nombre: 'Adivina la intro',
                hechos: adivinadas,
                total: totalIntros,
                color: paletaGenero(generoActivo).intro,
                detalle: '${intros?.intros.length ?? 0} cartas obtenidas',
              ),
      ],
    );
  }
}

/// Menú del género: carrusel de los dos modos y el progreso que gira solo de
/// izquierda a derecha (se pausa al tocarlo).
class _MenuPrincipal extends StatelessWidget {
  const _MenuPrincipal({
    super.key,
    required this.genero,
    required this.claveCarrusel,
    required this.onVisible,
    required this.infoCancion,
    required this.infoIntros,
    required this.onInstrumentos,
    required this.onIntros,
    required this.onProgreso,
    this.infoProgreso,
  });

  // Color e instrumentos de la tarjeta "Adivina la canción".
  final Genero genero;
  final GlobalKey claveCarrusel;
  // Una línea de datos del jugador en cada tarjeta (null si no hay).
  final String infoCancion;
  final String? infoIntros;
  // Avisa cuando el menú ya está en pantalla (para el recorrido inicial).
  final VoidCallback onVisible;
  final VoidCallback onInstrumentos;
  final VoidCallback onIntros;
  final VoidCallback onProgreso;
  final String? infoProgreso;

  // Las tres tarjetas llevan el color del género; solo Medley conserva los
  // suyos.
  List<Color> get _colores => genero.esPopurri
      ? [
          colorGenero(genero),
          paletaGenero(genero).intro,
          paletaGenero(genero).progreso,
        ]
      : List.filled(3, colorGenero(genero));

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => onVisible());
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: CarruselGiratorio(
        key: claveCarrusel,
        itemCount: _colores.length,
        autoGiro: const Duration(seconds: 5),
        // Del mismo tamaño que las del selector de géneros, con las otras dos
        // asomando detrás.
        compacto: true,
        anchoRelativo: 0.84,
        proporcion: 1.3,
        colorDe: (index) => _colores[index],
        itemBuilder: (context, index, alFrente) => ConReflejo(
          color: _colores[index],
          tarjeta: _cuadro(index, alFrente),
        ),
      ),
    );
  }

  Widget _cuadro(int index, bool alFrente, {bool animar = true}) {
    return switch (index) {
      0 => _CuadroModo(
        emoji: genero.instrumentos,
        animacion: _Animacion.tocar,
        titulo: 'Adivina la canción',
        detalle: 'Compra instrumentos y descubre la canción.',
        info: infoCancion,
        color: colorGenero(genero),
        alFrente: alFrente,
        // Solo la del frente se mueve; las laterales, quietas.
        animar: animar && alFrente,
        onTap: onInstrumentos,
      ),
      1 => _CuadroModo(
        emoji: '🎧',
        animacion: _Animacion.mecer,
        titulo: 'Adivina la intro',
        detalle: 'Escucha 30 segundos y adivina la canción.',
        info: infoIntros,
        color: _colores[1],
        alFrente: alFrente,
        // Solo la del frente se mueve; las laterales, quietas.
        animar: animar && alFrente,
        onTap: onIntros,
      ),
      _ => _CuadroModo(
        emoji: '📈',
        animacion: _Animacion.saltar,
        titulo: 'Progreso',
        detalle: 'Tus niveles, intros e insignias.',
        info: infoProgreso,
        color: _colores[2],
        alFrente: alFrente,
        // Solo la del frente se mueve; las laterales, quietas.
        animar: animar && alFrente,
        onTap: onProgreso,
      ),
    };
  }
}

class _CuadroModo extends StatelessWidget {
  const _CuadroModo({
    required this.emoji,
    required this.animacion,
    required this.titulo,
    required this.detalle,
    required this.color,
    required this.onTap,
    this.info,
    this.alFrente = true,
    this.bloqueado = false,
    this.animar = true,
    this.grande = false,
  });

  final String emoji;
  final _Animacion animacion;
  final String titulo;
  // Vacío: no se muestra la línea de detalle.
  final String detalle;
  // Ícono y título más grandes (p. ej. la tarjeta de Salas, sin detalle).
  final bool grande;
  final Color color;
  final VoidCallback? onTap;
  // Dato del jugador (nivel, intros, salas ganadas) bajo la descripción.
  final String? info;
  final bool alFrente;
  final bool bloqueado;
  final bool animar;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LiquidGlassCard(
      borderRadius: 28,
      opacity: bloqueado ? 0.35 : 0.6,
      // Las laterales solo se ven al girar: sin desenfoque, que es caro.
      blur: alFrente ? LiquidGlass.glassBlur : 0,
      borderColor: alFrente && !bloqueado ? color : null,
      tintColor: bloqueado ? null : color,
      child: LiquidRippleEffect(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: bloqueado ? 0.4 : 1,
                      child: _EmojiAnimado(
                        emoji: emoji,
                        tamano: grande ? 80 : 48,
                        animacion: animacion,
                        // Bloqueado se queda quieto: no invita a tocarlo.
                        activo: !bloqueado && animar,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      style: (grande ? text.displaySmall : text.headlineSmall)
                          ?.copyWith(
                            color: bloqueado
                                ? context.paleta.tintaSuave
                                : context.paleta.tonoTexto(color),
                          ),
                    ),
                    if (detalle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (bloqueado) ...[
                            Icon(
                              PhosphorIconsFill.lock,
                              size: 18,
                              color: context.paleta.tintaSuave,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              detalle,
                              textAlign: TextAlign.center,
                              style: text.bodyMedium?.copyWith(
                                color: context.paleta.tintaSuave,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (info case final dato?) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: color.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          dato,
                          textAlign: TextAlign.center,
                          style: text.labelLarge?.copyWith(
                            color: context.paleta.tonoTexto(color),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Animacion { tocar, saltar, mecer }

/// Emojis de las tarjetas del menú en movimiento: los instrumentos se mecen
/// por turnos como si tocaran, la copa salta y los audífonos se balancean.
class _EmojiAnimado extends StatefulWidget {
  const _EmojiAnimado({
    required this.emoji,
    required this.animacion,
    required this.activo,
    this.tamano = 48,
  });

  final String emoji;
  final double tamano;
  final _Animacion animacion;
  final bool activo;

  @override
  State<_EmojiAnimado> createState() => _EmojiAnimadoState();
}

class _EmojiAnimadoState extends State<_EmojiAnimado> {
  final _ciclo = CicloLento(periodo: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _actualizar();
  }

  @override
  void didUpdateWidget(_EmojiAnimado oldWidget) {
    super.didUpdateWidget(oldWidget);
    _actualizar();
  }

  // Quieto si está bloqueado, con "reducir movimiento" o con la pantalla
  // tapada por otra.
  void _actualizar() => _ciclo.activo =
      widget.activo &&
      !MediaQuery.disableAnimationsOf(context) &&
      TickerMode.valuesOf(context).enabled;

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emojis = widget.emoji.characters.toList();
    // Capa propia: el rebote no repinta la tarjeta de vidrio ni su sombra.
    return RepaintBoundary(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _ciclo,
          builder: (context, _) {
            final t = _ciclo.value * 2 * pi;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, emoji) in emojis.indexed)
                  Transform.translate(
                    offset: Offset(0, switch (widget.animacion) {
                      // Cada instrumento rebota desfasado, como una banda.
                      _Animacion.tocar => -sin(t + i * 2).abs() * 6,
                      _Animacion.saltar => -sin(t).abs() * 10,
                      _Animacion.mecer => 0,
                    }),
                    child: Transform.rotate(
                      angle: switch (widget.animacion) {
                        _Animacion.tocar => sin(t + i * 2) * 0.15,
                        _Animacion.saltar => sin(t * 2) * 0.05,
                        _Animacion.mecer => sin(t) * 0.25,
                      },
                      child: Transform.scale(
                        scale: widget.animacion == _Animacion.saltar
                            ? 1 + sin(t).abs() * 0.08
                            : 1,
                        child: Text(
                          emoji,
                          style: TextStyle(fontSize: widget.tamano),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PanelDificultades extends StatelessWidget {
  const _PanelDificultades({
    super.key,
    required this.estado,
    required this.seleccionada,
    required this.nivelesDe,
    required this.esInvitado,
    required this.abierta,
    required this.onCambio,
    required this.onAbrir,
    required this.onJugar,
    required this.onRefresh,
  });

  final EstadoJuegoRemoto estado;
  final bool abierta;
  final ValueChanged<Dificultad> onAbrir;
  final Dificultad seleccionada;
  final List<NivelAsignado> Function(Dificultad) nivelesDe;
  final bool esInvitado;
  final ValueChanged<Dificultad> onCambio;
  final void Function(Dificultad dificultad, int index) onJugar;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final dificultades = estado.dificultades;
    return Column(
      children: [
        Expanded(
          child: SafeArea(
            top: false,
            // Con el aviso de invitado debajo, el margen inferior lo pone él.
            bottom: !esInvitado,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              // El mismo fundido cruzado que al cambiar de pestaña.
              child: TransicionMusical(
                child: KeyedSubtree(
                  key: ValueKey(abierta),
                  child: abierta ? _niveles() : _carrusel(dificultades),
                ),
              ),
            ),
          ),
        ),
        // Solo los invitados ven el aviso; correo y Google no muestran nada.
        if (esInvitado)
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Modo invitado: el progreso se guarda en este dispositivo.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.paleta.tintaSuave,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

extension on _PanelDificultades {
  /// Carrusel de dificultades como el del menú: compactas.
  Widget _carrusel(List<ProgresoDificultadRemoto> dificultades) =>
      CarruselGiratorio(
        itemCount: dificultades.length,
        inicial: dificultades
            .indexWhere((item) => item.dificultad == seleccionada)
            .clamp(0, dificultades.length - 1),
        compacto: true,
        anchoRelativo: 0.84,
        proporcion: 1.3,
        onCambio: (index) => onCambio(dificultades[index].dificultad),
        colorDe: (index) => colorDificultad(dificultades[index].dificultad),
        itemBuilder: (context, index, alFrente) {
          final progreso = dificultades[index];
          Widget tarjeta(bool alFrente) => _ResumenDificultad(
            progreso: progreso,
            anterior: index == 0 ? null : dificultades[index - 1],
            niveles: nivelesDe(progreso.dificultad),
            alFrente: alFrente,
            onTap: () => onAbrir(progreso.dificultad),
          );
          return ConReflejo(
            color: colorDificultad(progreso.dificultad),
            tarjeta: tarjeta(alFrente),
          );
        },
      );

  /// Todos los niveles de la dificultad seleccionada.
  Widget _niveles() {
    final dificultades = estado.dificultades;
    final index = dificultades
        .indexWhere((item) => item.dificultad == seleccionada)
        .clamp(0, dificultades.length - 1);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _TarjetaDificultad(
            progreso: dificultades[index],
            anterior: index == 0 ? null : dificultades[index - 1],
            niveles: nivelesDe(dificultades[index].dificultad),
            alFrente: true,
            onJugar: (nivel) => onJugar(dificultades[index].dificultad, nivel),
            onRefresh: onRefresh,
          ),
        ),
      ),
    );
  }
}

/// Tarjeta compacta del carrusel de dificultades: avance y los niveles ya
/// completados; tocarla abre la tarjeta con todos los niveles.
class _ResumenDificultad extends StatelessWidget {
  const _ResumenDificultad({
    required this.progreso,
    required this.anterior,
    required this.niveles,
    required this.alFrente,
    required this.onTap,
  });

  final ProgresoDificultadRemoto progreso;
  final ProgresoDificultadRemoto? anterior;
  final List<NivelAsignado> niveles;
  final bool alFrente;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = colorDificultad(progreso.dificultad);
    final tono = context.paleta.tonoTexto(color);
    final bloqueada = !progreso.desbloqueada;
    final completados = [
      for (var i = 0; i < niveles.length; i++)
        if (niveles[i].completado) i + 1,
    ];
    return LiquidGlassCard(
      borderRadius: 28,
      tintColor: color,
      borderColor: alFrente ? color : null,
      // Las laterales solo se ven al girar: sin desenfoque, que es caro.
      blur: alFrente ? LiquidGlass.glassBlur : 0,
      child: LiquidRippleEffect(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            // Con letra grande se encoge en vez de desbordarse.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 280,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 76,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: progreso.total == 0
                                ? 0
                                : progreso.completados / progreso.total,
                            strokeWidth: 7,
                            color: color,
                            backgroundColor: color.withValues(alpha: 0.2),
                            strokeCap: StrokeCap.round,
                          ),
                          Center(
                            child: bloqueada
                                ? Icon(
                                    PhosphorIconsFill.lock,
                                    color: context.paleta.tintaSuave,
                                  )
                                : Text(
                                    '${progreso.completados}/'
                                    '${max(progreso.total, 5)}',
                                    style: text.titleLarge,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _nombreDificultad(progreso.dificultad),
                      style: text.headlineMedium?.copyWith(color: tono),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bloqueada
                          ? 'Completa ${_nombreDificultad(anterior?.dificultad ?? progreso.dificultad)} para desbloquearla'
                          : completados.isEmpty
                          ? 'Aún no completas niveles'
                          : progreso.completados >= progreso.total
                          ? '¡Completada! 🎉'
                          : 'Niveles completados',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(
                        color: context.paleta.tintaSuave,
                      ),
                    ),
                    if (completados.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      // Solo los completados; los demás se ven al abrirla.
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final numero in completados)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.6),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Nivel $numero',
                                    style: text.labelMedium?.copyWith(
                                      color: tono,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    PhosphorIconsFill.checkCircle,
                                    size: 16,
                                    color: tono,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ver niveles',
                          style: text.labelLarge?.copyWith(color: tono),
                        ),
                        Icon(Icons.chevron_right_rounded, color: tono),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Una "pantalla" con todos los niveles de la dificultad.
class _TarjetaDificultad extends StatelessWidget {
  const _TarjetaDificultad({
    required this.progreso,
    required this.anterior,
    required this.niveles,
    required this.alFrente,
    required this.onJugar,
    required this.onRefresh,
  });

  final ProgresoDificultadRemoto progreso;
  final ProgresoDificultadRemoto? anterior;
  final List<NivelAsignado> niveles;
  final bool alFrente;
  final ValueChanged<int> onJugar;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = colorDificultad(progreso.dificultad);
    // La dificultad se puede ver siempre; sus niveles se abren al completar
    // la anterior.
    final bloqueada = !progreso.desbloqueada;
    final cantidadBloqueados = progreso.total == 0 ? 5 : progreso.total;
    return LiquidGlassCard(
      borderRadius: 28,
      tintColor: color,
      borderColor: alFrente ? color : null,
      // Las laterales solo se ven al girar y atenuadas: sin desenfoque, que es
      // lo más caro de pintar en cada cuadro.
      blur: alFrente ? LiquidGlass.glassBlur : 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Anillo de avance con "3/5" (o candado) en el centro.
                SizedBox.square(
                  dimension: 64,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progreso.total == 0
                            ? 0
                            : progreso.completados / progreso.total,
                        strokeWidth: 6,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.2),
                        strokeCap: StrokeCap.round,
                      ),
                      Center(
                        child: bloqueada
                            ? Icon(
                                PhosphorIconsFill.lock,
                                color: context.paleta.tintaSuave,
                              )
                            : Text(
                                '${progreso.completados}/'
                                '${max(progreso.total, 5)}',
                                style: text.titleMedium,
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nombreDificultad(progreso.dificultad),
                        style: text.headlineMedium?.copyWith(
                          color: context.paleta.tonoTexto(color),
                        ),
                      ),
                      Text(
                        bloqueada
                            ? 'Completa ${_nombreDificultad(anterior?.dificultad ?? progreso.dificultad)} para desbloquearla'
                            : progreso.total == 0
                            ? 'Todavía no hay niveles publicados'
                            : progreso.completados >= progreso.total
                            ? '¡Completada! 🎉'
                            : 'Niveles completados',
                        style: text.bodyMedium?.copyWith(
                          color: context.paleta.tintaSuave,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: color.withValues(alpha: 0.35), height: 1),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                onRefresh: onRefresh,
                child: LayoutBuilder(
                  builder: (context, espacio) => ListView(
                    padding: EdgeInsets.zero,
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: _llenarEspacio(
                      espacio.maxHeight,
                      color,
                      bloqueada
                          ? [
                              for (var i = 0; i < cantidadBloqueados; i++)
                                LiquidLevelCard(
                                  numero: i + 1,
                                  estado: EstadoNivel.bloqueado,
                                  color: color,
                                ),
                            ]
                          : [
                              for (var i = 0; i < niveles.length; i++)
                                _tarjetaNivel(i, niveles[i], color),
                            ],
                      escalaTexto: MediaQuery.textScalerOf(context).scale(1),
                      vacio: Text(
                        progreso.total == 0
                            ? 'Todavía no hay niveles disponibles para esta dificultad.'
                            : 'No hay niveles completados para repetir.',
                        textAlign: TextAlign.center,
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

  /// Reparte el alto disponible: con pocos niveles las tarjetas crecen y, si
  /// aún sobra espacio, abajo toca la banda. Con muchos niveles se desplaza.
  List<Widget> _llenarEspacio(
    double alto,
    Color color,
    List<Widget> tarjetas, {
    required Widget vacio,
    required double escalaTexto,
  }) {
    const separacion = 10.0;
    // Alto natural de la casilla, mayor si el sistema usa letra grande.
    final altoMinimo = max(64.0, 24 + escalaTexto * 44);
    final altoMaximo = altoMinimo;
    const altoBanda = 90.0;
    if (tarjetas.isEmpty) {
      return [
        Padding(padding: const EdgeInsets.only(top: 24), child: vacio),
        SizedBox(
          height: max(altoBanda, alto - 120),
          child: BandaMusical(color: color),
        ),
      ];
    }
    final n = tarjetas.length;
    final altoTarjeta = ((alto - n * separacion) / n).clamp(
      altoMinimo,
      altoMaximo,
    );
    final sobrante = alto - n * (altoTarjeta + separacion);
    return [
      for (final tarjeta in tarjetas)
        Padding(
          padding: const EdgeInsets.only(bottom: separacion),
          child: SizedBox(height: altoTarjeta, child: tarjeta),
        ),
      if (sobrante >= altoBanda)
        SizedBox(
          height: sobrante - 1,
          child: BandaMusical(color: color),
        ),
    ];
  }

  Widget _tarjetaNivel(int index, NivelAsignado asignado, Color color) {
    final canStart = asignado.completado || asignado.puedeIniciar;
    return Entrada(
      indice: index,
      child: LiquidLevelCard(
        numero: index + 1,
        color: color,
        estado: asignado.completado
            ? EstadoNivel.completado
            : canStart
            ? EstadoNivel.disponible
            : EstadoNivel.bloqueado,
        onJugar: () => onJugar(index),
      ),
    );
  }
}

/// "Vas en el nivel 3 de Fácil" según la dificultad activa.
String _textoNivel(EstadoJuegoRemoto estado) {
  final terminado = estado.dificultades.any(
    (progreso) =>
        progreso.dificultad == Dificultad.avanzado &&
        progreso.total >= 5 &&
        progreso.completados >= progreso.total,
  );
  if (terminado) return '¡Completaste las tres dificultades!';
  final activa = estado.dificultades
      .where((item) => item.dificultad == estado.dificultadActiva)
      .firstOrNull;
  final nivel = min((activa?.completados ?? 0) + 1, 5);
  return 'Vas en el nivel $nivel de '
      '${_nombreDificultad(estado.dificultadActiva)}';
}

String _nombreDificultad(Dificultad dificultad) {
  switch (dificultad) {
    case Dificultad.facil:
      return 'Fácil';
    case Dificultad.medio:
      return 'Media';
    case Dificultad.avanzado:
      return 'Avanzada';
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => esErrorDeRed(error)
      ? SinConexion(onReintentar: onRetry)
      : Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No se pudo cargar el progreso.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        );
}
