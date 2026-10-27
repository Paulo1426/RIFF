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
    this.cargandoTipo,
  });

  final int saldoMonedas;
  final Map<TipoPista, String> pistasDesbloqueadas;
  final void Function(TipoPista tipo) onComprarPista;
  final TipoPista? cargandoTipo;

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.signalOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.signalOrange.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  '$saldoMonedas',
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.signalOrange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Usa tus monedas ganadas para desbloquear pistas y adivinar la canción:',
            style: text.bodyMedium?.copyWith(
              color: text.bodyMedium?.color?.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          for (final tipo in TipoPista.values)
            PistaCard(
              tipo: tipo,
              saldoMonedas: saldoMonedas,
              desbloqueada: pistasDesbloqueadas.containsKey(tipo),
              valor: pistasDesbloqueadas[tipo],
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
}
