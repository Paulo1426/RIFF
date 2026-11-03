import 'package:flutter/material.dart';

import '../models/genero.dart';

class MonedasGenero extends StatelessWidget {
  const MonedasGenero({
    super.key,
    required this.genero,
    required this.saldo,
    this.saldos = const {},
  });

  final Genero genero;
  final int saldo;
  final Map<String, int> saldos;

  Widget _chip() => Chip(
    visualDensity: VisualDensity.compact,
    avatar: Text(genero.simboloMoneda),
    label: Text('$saldo'),
  );

  @override
  Widget build(BuildContext context) {
    if (!genero.esPopurri) {
      return Semantics(
        label: '$saldo monedas de ${genero.nombre}',
        child: _chip(),
      );
    }

    return PopupMenuButton<Genero>(
      tooltip:
          '$saldo monedas de ${genero.nombre}. Ver monedas de todos los géneros',
      onSelected: (_) {},
      itemBuilder: (context) => [
        for (final item in Genero.values)
          PopupMenuItem<Genero>(
            value: item,
            child: Row(
              children: [
                Text(item.simboloMoneda),
                const SizedBox(width: 10),
                Expanded(child: Text(item.nombre)),
                Text('${saldos[item.id] ?? (item == genero ? saldo : 0)}'),
              ],
            ),
          ),
      ],
      child: _chip(),
    );
  }
}
