import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme.dart';

/// Alterna entre modo claro y oscuro; la elección se guarda en el teléfono.
class BotonTema extends ConsumerWidget {
  const BotonTema({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oscuro = context.paleta.oscuro;
    return IconButton.filledTonal(
      tooltip: oscuro ? 'Modo claro' : 'Modo oscuro',
      icon: Icon(oscuro ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
      onPressed: () => ref
          .read(modoTemaProvider.notifier)
          .cambiar(oscuro ? ThemeMode.light : ThemeMode.dark),
    );
  }
}
