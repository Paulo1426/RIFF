import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../theme.dart';

/// Un paso del recorrido: el elemento a resaltar y qué explica la burbuja.
class PasoRecorrido {
  const PasoRecorrido({
    required this.clave,
    required this.titulo,
    required this.texto,
  });

  final GlobalKey clave;
  final String titulo;
  final String texto;
}

/// Cada recorrido ([id]: 'menu', 'salas'...) se muestra solo la primera vez
/// que se abre esa pantalla en este teléfono, sea con cuenta o como invitado.
class RecorridoInicial {
  const RecorridoInicial(this.id);

  final String id;

  Future<File> _archivo() async =>
      File('${(await getApplicationSupportDirectory()).path}/recorrido_$id');

  Future<bool> pendiente() async {
    try {
      return !await (await _archivo()).exists();
    } catch (error) {
      debugPrint('No se pudo leer si el recorrido $id ya se vio: $error');
      return false;
    }
  }

  Future<void> marcarVisto() async {
    try {
      await (await _archivo()).create(recursive: true);
    } catch (error) {
      debugPrint('No se pudo guardar que el recorrido $id se vio: $error');
    }
  }

  /// Muestra [pasos] si este recorrido aún no se vio. Espera un momento a
  /// que la pantalla termine de animarse antes de medir los elementos.
  Future<void> mostrarSiEsNuevo(
    BuildContext context,
    List<PasoRecorrido> Function() pasos,
  ) async {
    if (!await pendiente()) return;
    // Se marca antes de mostrarlo: aunque se cierre la app o se salga de la
    // pantalla a mitad, no vuelve a aparecer.
    await marcarVisto();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!context.mounted) return;
    await mostrarRecorrido(context, pasos());
  }
}

/// Oscurece la pantalla salvo el elemento de cada paso y lo explica con una
/// burbuja; "Siguiente" avanza y "Omitir" lo cierra.
Future<void> mostrarRecorrido(BuildContext context, List<PasoRecorrido> pasos) {
  final visibles = pasos.where((p) => p.clave.currentContext != null).toList();
  if (visibles.isEmpty) return Future.value();
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) => _Recorrido(pasos: visibles),
      transitionsBuilder: (_, animacion, _, hijo) =>
          FadeTransition(opacity: animacion, child: hijo),
    ),
  );
}

class _Recorrido extends StatefulWidget {
  const _Recorrido({required this.pasos});

  final List<PasoRecorrido> pasos;

  @override
  State<_Recorrido> createState() => _RecorridoState();
}

class _RecorridoState extends State<_Recorrido> {
  int _paso = 0;

  Rect _zona(PasoRecorrido paso) {
    final caja = paso.clave.currentContext?.findRenderObject() as RenderBox?;
    if (caja == null || !caja.hasSize) return Rect.zero;
    return (caja.localToGlobal(Offset.zero) & caja.size).inflate(6);
  }

  void _siguiente() {
    if (_paso + 1 < widget.pasos.length) {
      setState(() => _paso++);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final paso = widget.pasos[_paso];
    final pantalla = MediaQuery.sizeOf(context);
    final ultimo = _paso == widget.pasos.length - 1;
    return Material(
      type: MaterialType.transparency,
      child: TweenAnimationBuilder<Rect?>(
        tween: RectTween(end: _zona(paso)),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        builder: (context, zona, _) {
          zona ??= Rect.zero;
          final ancho = min(340.0, pantalla.width - 32);
          final izquierda = (zona.center.dx - ancho / 2).clamp(
            16.0,
            pantalla.width - ancho - 16,
          );
          // La burbuja va debajo si cabe, si no encima; con elementos muy
          // altos (un panel o una lista) no cabe en ninguno y va centrada
          // sobre el propio elemento.
          const altoBurbuja = 220.0;
          final margenes = MediaQuery.paddingOf(context);
          final abajo =
              zona.bottom + altoBurbuja < pantalla.height - margenes.bottom;
          final arriba = zona.top - altoBurbuja > margenes.top;
          final burbuja = _Burbuja(
            titulo: paso.titulo,
            texto: paso.texto,
            numero: _paso + 1,
            total: widget.pasos.length,
            ultimo: ultimo,
            onOmitir: () => Navigator.of(context).pop(),
            onSiguiente: _siguiente,
          );
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  // Tocar fuera no hace nada: se avanza con los botones.
                  onTap: () {},
                  child: CustomPaint(painter: _Velo(zona)),
                ),
              ),
              if (abajo || arriba)
                Positioned(
                  left: izquierda,
                  width: ancho,
                  top: abajo ? zona.bottom + 12 : null,
                  bottom: abajo ? null : pantalla.height - zona.top + 12,
                  child: burbuja,
                )
              else
                Positioned.fromRect(
                  rect: zona.intersect(
                    Offset(0, margenes.top) &
                        Size(
                          pantalla.width,
                          pantalla.height - margenes.vertical,
                        ),
                  ),
                  child: Center(
                    child: SizedBox(width: ancho, child: burbuja),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Velo oscuro con un hueco redondeado sobre [zona] y un borde de luz.
class _Velo extends CustomPainter {
  _Velo(this.zona);

  final Rect zona;

  @override
  void paint(Canvas canvas, Size size) {
    final hueco = RRect.fromRectAndRadius(zona, const Radius.circular(18));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(hueco),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.7),
    );
    canvas.drawRRect(
      hueco,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.signalOrange,
    );
  }

  @override
  bool shouldRepaint(_Velo oldDelegate) => oldDelegate.zona != zona;
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({
    required this.titulo,
    required this.texto,
    required this.numero,
    required this.total,
    required this.ultimo,
    required this.onOmitir,
    required this.onSiguiente,
  });

  final String titulo;
  final String texto;
  final int numero;
  final int total;
  final bool ultimo;
  final VoidCallback onOmitir;
  final VoidCallback onSiguiente;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.paleta.superficie,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.signalOrange, width: 1.5),
          boxShadow: const [
            BoxShadow(blurRadius: 24, color: Color(0x55000000)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: text.titleMedium),
              const SizedBox(height: 6),
              Text(texto, style: text.bodyMedium),
              const SizedBox(height: 8),
              Text(
                '$numero de $total',
                style: text.bodySmall?.copyWith(
                  color: context.paleta.tintaSuave,
                ),
              ),
              // Wrap: con letra grande o pantalla angosta los botones bajan
              // de línea en vez de desbordarse.
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    if (!ultimo)
                      TextButton(
                        onPressed: onOmitir,
                        child: const Text('Omitir'),
                      ),
                    FilledButton(
                      onPressed: onSiguiente,
                      child: Text(ultimo ? '¡Listo!' : 'Siguiente'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
