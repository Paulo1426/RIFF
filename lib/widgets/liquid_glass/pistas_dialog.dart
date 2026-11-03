import 'package:flutter/material.dart';

import '../../models/pista.dart';
import '../../theme.dart';
import 'liquid_glass_dialog.dart';
import 'pista_card.dart';

/// Diálogo modal para consultar y desbloquear pistas a cambio de monedas.
class PistasDialog extends StatelessWidget {
  const PistasDialog({
    super.key,
    required this.saldoMonedas,
    required this.pistasDesbloqueadas,
    required this.onComprarPista,
    this.simboloMoneda = '🪙',
    this.cargandoTipo,
  });

  final int saldoMonedas;
  final String simboloMoneda;
  final Map<TipoPista, String> pistasDesbloqueadas;
  final void Function(TipoPista tipo) onComprarPista;
  final TipoPista? cargandoTipo;

  /// "Empieza por: P · Artista: ..." con las sorpresas que ya salieron.
  String? _sorpresasReveladas() {
    final reveladas = [
      for (final tipo in TipoPistaExtension.sorpresas)
        if (pistasDesbloqueadas[tipo] case final valor?)
          '${tipo.etiqueta}: $valor',
    ];
    return reveladas.isEmpty ? null : reveladas.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    return LiquidGlassDialog(
      title: Row(
        children: [
          const Icon(
            Icons.lightbulb_rounded,
            color: AppColors.signalOrange,
            size: 28,
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('Pistas y Comodines')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: _saldo(text, simboloMoneda, saldoMonedas),
          ),
          const SizedBox(height: 8),
          Text(
            'Usa monedas de esta sección para desbloquear pistas y adivinar la canción:',
            style: text.bodyMedium?.copyWith(
              color: text.bodyMedium?.color?.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          for (final tipo in TipoPistaExtension.comprables)
            PistaCard(
              tipo: tipo,
              saldoMonedas: saldoMonedas,
              simboloMoneda: simboloMoneda,
              desbloqueada: tipo == TipoPista.sorpresa
                  // La sorpresa se agota cuando ya salieron las tres.
                  ? TipoPistaExtension.sorpresas.every(
                      pistasDesbloqueadas.containsKey,
                    )
                  : pistasDesbloqueadas.containsKey(tipo),
              valor: tipo == TipoPista.sorpresa
                  ? _sorpresasReveladas()
                  : pistasDesbloqueadas[tipo],
              cargando: cargandoTipo == tipo,
              onComprar: () => onComprarPista(tipo),
            ),
        ],
      ),
      actions: [
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Volver al juego'),
        ),
      ],
    );
  }

  Widget _saldo(TextTheme text, String simbolo, int saldo) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.signalOrange.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.signalOrange.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(simbolo, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(
          '$saldo',
          style: text.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.signalOrange,
          ),
        ),
      ],
    ),
  );
}
