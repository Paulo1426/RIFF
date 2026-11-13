part of 'home_screen.dart';

/// Pestaña Progreso: avance de niveles e intros, estadísticas de salas e
/// insignias.
/// Progreso general (desde el selector de géneros): avance de cada género
/// disponible, las salas (que son de todos los géneros) y las insignias
/// generales. Mismo carrusel que la pestaña Progreso de cada género.
class _ProgresoTodo extends StatelessWidget {
  const _ProgresoTodo({
    required this.datos,
    required this.saldo,
    required this.esInvitado,
  });

  final Map<Genero, ({EstadoJuegoRemoto estado, EstadoIntros? intros})> datos;
  final SaldoSalas saldo;
  final bool esInvitado;

  static const _colores = [AppColors.oro, azulLogin, colorAleatorio];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final avances = [
      for (final MapEntry(key: genero, value: d) in datos.entries)
        _avanceDe(d.estado.dificultades, d.intros, genero),
    ];
    final logros = logrosGenerales(saldo, avances);
    // Niveles cargados de verdad (un género en preparación suma 0) e intros.
    var hechos = 0, total = 0;
    final filas = <Widget>[];
    for (final MapEntry(key: genero, value: d) in datos.entries) {
      final niveles = d.estado.dificultades.fold(
        0,
        (s, x) => s + x.completados,
      );
      final totalNiveles = d.estado.dificultades.fold(0, (s, x) => s + x.total);
      final intros = d.intros;
      final adivinadas =
          intros?.intros
              .where((i) => i.estado == EstadoIntro.completada)
              .length ??
          0;
      final totalIntros = intros == null
          ? genero.totalIntros
          : intros.intros.length + intros.restantes;
      hechos += niveles + adivinadas;
      total += totalNiveles + totalIntros;
      filas.add(
        _ProgresoGeneral._fila(
          context,
          nombre: genero.nombre,
          hechos: niveles + adivinadas,
          total: totalNiveles + totalIntros,
          color: colorGenero(genero),
          detalle: totalNiveles == 0
              ? '$adivinadas de $totalIntros intros · niveles en preparación'
              : '$niveles de $totalNiveles niveles · '
                    '$adivinadas de $totalIntros intros',
        ),
      );
    }
    final porcentaje = total == 0 ? 0.0 : hechos / total;
    Widget tarjeta(int index, bool alFrente) => switch (index) {
      0 => _CuadroProgreso(
        color: _colores[0],
        alFrente: alFrente,
        onTap: null,
        children: [
          _tituloTarjeta(context, '📈 Progreso general', _colores[0]),
          const SizedBox(height: 8),
          Text(
            '${(porcentaje * 100).round()}%',
            textAlign: TextAlign.center,
            style: text.displaySmall?.copyWith(
              color: context.paleta.tonoTexto(_colores[0]),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: porcentaje,
              minHeight: 12,
              color: _colores[0],
            ),
          ),
          const SizedBox(height: 20),
          if (filas.isEmpty)
            const Center(child: CircularProgressIndicator())
          else
            ...filas,
        ],
      ),
      1 => _ResumenSalas(
        saldo: saldo,
        esInvitado: esInvitado,
        color: _colores[1],
        alFrente: alFrente,
      ),
      _ => _ResumenInsignias(
        logros: logros,
        color: _colores[2],
        alFrente: alFrente,
        onTap: () => _PestanaProgreso._verDetalle(
          context,
          'Insignias generales',
          () => _GrillaInsignias(logros: logros),
        ),
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: CarruselGiratorio(
        itemCount: _colores.length,
        compacto: true,
        anchoRelativo: 0.84,
        proporcion: 1.45,
        colorDe: (index) => _colores[index],
        itemBuilder: (context, index, alFrente) => ConReflejo(
          color: _colores[index],
          tarjeta: tarjeta(index, alFrente),
        ),
      ),
    );
  }
}

class _PestanaProgreso extends StatelessWidget {
  const _PestanaProgreso({
    super.key,
    required this.dificultades,
    required this.intros,
    required this.saldo,
    required this.esInvitado,
  });

  final List<ProgresoDificultadRemoto> dificultades;
  final Future<EstadoIntros?>? intros;
  final SaldoSalas saldo;
  final bool esInvitado;

  // Colores del género que se está jugando (las pestañas son de su menú).
  List<Color> get _colores => [
    paletaGenero(generoActivo).progreso,
    paletaGenero(generoActivo).mancha1,
    colorGenero(generoActivo),
  ];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EstadoIntros?>(
      future: intros,
      builder: (context, snapshot) {
        final estadoIntros = snapshot.data;
        final cargando = snapshot.connectionState != ConnectionState.done;
        final logros = logrosDe(
          saldo,
          _avanceDe(dificultades, estadoIntros, generoActivo),
          generoActivo,
        );
        // Progreso y Salas muestran todo en la tarjeta; Insignias abre una
        // hoja con todas al tocarla.
        Widget tarjeta(int index, bool alFrente) => switch (index) {
          0 => _CuadroProgreso(
            color: _colores[0],
            alFrente: alFrente,
            onTap: null,
            children: [
              _tituloTarjeta(context, '📈 Progreso', _colores[0]),
              const SizedBox(height: 8),
              _ProgresoGeneral(
                dificultades: dificultades,
                intros: estadoIntros,
                cargandoIntros: cargando,
              ),
            ],
          ),
          1 => _ResumenSalas(
            saldo: saldo,
            esInvitado: esInvitado,
            color: _colores[1],
            alFrente: alFrente,
          ),
          _ => _ResumenInsignias(
            logros: logros,
            color: _colores[2],
            alFrente: alFrente,
            onTap: () => _verDetalle(
              context,
              'Insignias',
              () => _GrillaInsignias(logros: logros),
            ),
          ),
        };
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CarruselGiratorio(
            itemCount: _colores.length,
            // Como el menú principal: más pequeñas y con las otras
            // asomando detrás.
            compacto: true,
            // Algo más altas que las del menú: Progreso y Salas traen todo.
            anchoRelativo: 0.84,
            proporcion: 1.45,
            colorDe: (index) => _colores[index],
            itemBuilder: (context, index, alFrente) => ConReflejo(
              color: _colores[index],
              tarjeta: tarjeta(index, alFrente),
            ),
          ),
        );
      },
    );
  }

  static void _verDetalle(
    BuildContext context,
    String titulo,
    Widget Function() contenido,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.paleta.fondo,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, desplazamiento) => ListView(
        controller: desplazamiento,
        padding: EdgeInsets.symmetric(
          horizontal: max(16, (MediaQuery.sizeOf(context).width - 680) / 2),
          vertical: 16,
        ),
        children: [
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          contenido(),
        ],
      ),
    ),
  );
}

/// Tarjeta del carrusel de Progreso: vidrio de color, toda tocable y con el
/// contenido encogido si no cabe (letra grande, pantallas bajas).
class _CuadroProgreso extends StatelessWidget {
  const _CuadroProgreso({
    required this.color,
    required this.alFrente,
    required this.onTap,
    required this.children,
  });

  final Color color;
  final bool alFrente;
  final VoidCallback? onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LiquidGlassCard(
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
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: 280,
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        ),
      ),
    ),
  );
}

/// "Toca para ver más" al pie de las tarjetas de Progreso.
Widget _verMas(BuildContext context, Color color) {
  final tono = context.paleta.tonoTexto(color);
  return Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Ver detalle',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: tono),
        ),
        Icon(Icons.chevron_right_rounded, color: tono),
      ],
    ),
  );
}

/// Título de una tarjeta de Progreso, del color de la tarjeta.
Widget _tituloTarjeta(BuildContext context, String titulo, Color color) => Text(
  titulo,
  textAlign: TextAlign.center,
  style: Theme.of(
    context,
  ).textTheme.headlineSmall?.copyWith(color: context.paleta.tonoTexto(color)),
);

/// Salas: las seis estadísticas a la vista.
class _ResumenSalas extends StatelessWidget {
  const _ResumenSalas({
    required this.saldo,
    required this.esInvitado,
    required this.color,
    required this.alFrente,
  });

  final SaldoSalas saldo;
  final bool esInvitado;
  final Color color;
  final bool alFrente;

  @override
  Widget build(BuildContext context) => _CuadroProgreso(
    color: color,
    alFrente: alFrente,
    onTap: null,
    children: [
      _tituloTarjeta(context, '👥 Salas', color),
      const SizedBox(height: 16),
      if (esInvitado)
        Text(
          'Crea una cuenta para jugar en salas y ver tus estadísticas.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.paleta.tintaSuave),
        )
      else
        _EstadisticasSalas(saldo: saldo),
    ],
  );
}

List<_Dato> _datosSalas(SaldoSalas saldo) => [
  _Dato('🎮', '${saldo.jugadas}', 'Jugadas'),
  _Dato('🏆', '${saldo.ganadas}', 'Ganadas'),
  _Dato('😔', '${saldo.derrotas}', 'Derrotas'),
  _Dato('📊', '${(saldo.porcentajeVictorias * 100).round()}%', 'Victorias'),
  _Dato('🏅', '${saldo.podios}', 'Podios'),
  _Dato('🎟️', '${saldo.fichasGanadas}', 'Fichas ganadas'),
];

/// Insignias conseguidas como etiquetas del color de su dificultad, igual que
/// los niveles completados; las pendientes se ven en el detalle.
class _ResumenInsignias extends StatelessWidget {
  const _ResumenInsignias({
    required this.logros,
    required this.color,
    required this.alFrente,
    required this.onTap,
  });

  final List<Logro> logros;
  final Color color;
  final bool alFrente;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final conseguidas = logros.where((logro) => logro.logrado).toList();
    return _CuadroProgreso(
      color: color,
      alFrente: alFrente,
      onTap: onTap,
      children: [
        Text(
          '🏅 Insignias',
          style: text.headlineSmall?.copyWith(
            color: context.paleta.tonoTexto(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${conseguidas.length} de ${logros.length}',
          style: text.bodyMedium?.copyWith(color: context.paleta.tintaSuave),
        ),
        const SizedBox(height: 12),
        if (conseguidas.isEmpty)
          Text(
            'Aún no tienes insignias. ¡Toca para ver cómo ganarlas!',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: context.paleta.tintaSuave),
          )
        else
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final logro in conseguidas) _EtiquetaInsignia(logro: logro),
            ],
          ),
        _verMas(context, color),
      ],
    );
  }
}

/// Nombre de una insignia en una píldora de su color (dorada Vallenatólogo).
class _EtiquetaInsignia extends StatelessWidget {
  const _EtiquetaInsignia({required this.logro});

  final Logro logro;

  @override
  Widget build(BuildContext context) {
    final color = logro.dorada ? AppColors.oro : colorInsignia(logro.nivel);
    final tono = context.paleta.tonoTexto(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color, width: logro.dorada ? 2 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(logro.emoji),
          const SizedBox(width: 4),
          Text(
            logro.nombre,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: tono,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Icon(PhosphorIconsFill.checkCircle, size: 16, color: tono),
        ],
      ),
    );
  }
}

/// Todas las estadísticas de salas: dos filas de tres datos.
class _EstadisticasSalas extends StatelessWidget {
  const _EstadisticasSalas({required this.saldo});

  final SaldoSalas saldo;

  @override
  Widget build(BuildContext context) {
    final datos = _datosSalas(saldo);
    return Column(
      children: [
        for (final fila in [datos.sublist(0, 3), datos.sublist(3)])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, dato) in fila.indexed) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: dato),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Todas las insignias, conseguidas o no, del mismo tamaño.
class _GrillaInsignias extends StatelessWidget {
  const _GrillaInsignias({required this.logros});

  final List<Logro> logros;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, espacio) {
      // Dos por fila en teléfonos, más en tablets.
      final columnas = max(2, (espacio.maxWidth / 200).floor());
      final ancho = (espacio.maxWidth - 10 * (columnas - 1)) / columnas;
      // Todas del mismo alto: cabe nombre en 2 líneas y condición en 4;
      // crece con la letra del sistema.
      final alto = MediaQuery.textScalerOf(context).scale(224);
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final logro in logros)
            SizedBox(
              width: ancho,
              height: alto,
              child: TarjetaLogro(logro: logro),
            ),
        ],
      );
    },
  );
}

/// Un número de las estadísticas de salas con su emoji y nombre.
class _Dato extends StatelessWidget {
  const _Dato(this.emoji, this.valor, this.nombre);

  final String emoji;
  final String valor;
  final String nombre;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: context.paleta.superficie.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.paleta.borde),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          Text(valor, style: text.titleLarge),
          Text(
            nombre,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: context.paleta.tintaSuave),
          ),
        ],
      ),
    );
  }
}

/// Insignia con el color de su dificultad: llena si se consiguió; si no,
/// apagada con su avance. Vallenatólogo conseguida va en dorado.
@visibleForTesting
class TarjetaLogro extends StatelessWidget {
  const TarjetaLogro({super.key, required this.logro});

  final Logro logro;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hecho = logro.logrado;
    final color = colorInsignia(logro.nivel);
    final dorada = hecho && logro.dorada;
    return Semantics(
      label:
          '${logro.nombre}: ${hecho ? 'conseguida' : 'pendiente, '
                    '${min(logro.actual, logro.meta)} de ${logro.meta}'}. '
          '${logro.condicion}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hecho
              ? color.withValues(alpha: 0.22)
              : context.paleta.superficie.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: dorada
                ? AppColors.oro
                : hecho
                ? color
                : color.withValues(alpha: 0.45),
            width: dorada ? 3 : (hecho ? 2 : 1),
          ),
        ),
        child: Column(
          children: [
            Opacity(
              opacity: hecho ? 1 : 0.35,
              child: Text(logro.emoji, style: const TextStyle(fontSize: 34)),
            ),
            const SizedBox(height: 4),
            Text(
              logro.nombre,
              textAlign: TextAlign.center,
              style: dorada
                  ? text.titleSmall?.copyWith(
                      color: context.paleta.tonoTexto(AppColors.oro),
                      fontWeight: FontWeight.w800,
                    )
                  : text.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              logro.condicion,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: context.paleta.tintaSuave),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            // El avance queda abajo en todas, aunque el texto sea corto.
            const Spacer(),
            const SizedBox(height: 8),
            if (hecho)
              Text(
                '✅ Conseguida',
                style: text.labelMedium?.copyWith(
                  color: context.paleta.tonoTexto(color),
                  fontWeight: FontWeight.w800,
                ),
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: logro.meta == 0
                      ? 0
                      : min(logro.actual, logro.meta) / logro.meta,
                  minHeight: 5,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${min(logro.actual, logro.meta)}/${logro.meta}',
                style: text.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pestaña Configuración: instrucciones, música del menú, tema y sesión.
/// Saldo en la barra de arriba: emoji y número en una píldora.
class _Saldo extends StatelessWidget {
  const _Saldo(this.emoji, this.valor, this.nombre);

  final String emoji;
  final int valor;
  final String nombre;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: Semantics(
      label: '$valor $nombre',
      excludeSemantics: true,
      child: Chip(
        visualDensity: VisualDensity.compact,
        avatar: Text(emoji),
        label: Text('$valor'),
      ),
    ),
  );
}
