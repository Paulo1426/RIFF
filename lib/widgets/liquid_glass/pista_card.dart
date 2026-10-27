import 'package:flutter/material.dart';

import '../../models/pista.dart';
import '../../theme.dart';
import 'liquid_glass_card.dart';

/// Tarjeta que representa una pista disponible para canjear con monedas.
class PistaCard extends StatelessWidget {
  const PistaCard({
    super.key,
    required this.tipo,
    required this.saldoMonedas,
    this.desbloqueada = false,
    this.valor,
    this.cargando = false,
    this.onComprar,
  });

  final TipoPista tipo;
  final int saldoMonedas;
  final bool desbloqueada;
  final String? valor;
  final bool cargando;
  final VoidCallback? onComprar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final costo = tipo.costoMonedas;
    final puedeComprar = !desbloqueada && saldoMonedas >= costo && !cargando;

    return LiquidGlassCard(
      borderRadius: 16,
      opacity: desbloqueada ? 0.35 : 0.25,
      borderColor: desbloqueada ? AppColors.verde.withValues(alpha: 0.6) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: desbloqueada
                      ? AppColors.verde.withValues(alpha: 0.2)
                      : theme.colorScheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  tipo.icono,
                  color: desbloqueada
                      ? AppColors.verde
                      : theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tipo.titulo,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!desbloqueada)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.secondary.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '🪙',
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$costo',
                                  style: text.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tipo.descripcion,
                      style: text.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // La sorpresa muestra lo que ya salió y sigue a la venta hasta
          // agotarse, así que valor y botón pueden ir juntos.
          if (valor != null && valor!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.verde.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.verde.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.verde,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      valor!,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.verde,
                        letterSpacing: tipo == TipoPista.iniciales ? 2.0 : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!desbloqueada) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: puedeComprar ? onComprar : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                child: cargando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        saldoMonedas >= costo
                            ? 'Desbloquear (🪙 $costo)'
                            : 'Faltan monedas (tienes $saldoMonedas)',
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
