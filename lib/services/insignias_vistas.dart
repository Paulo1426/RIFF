import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Insignias que el jugador ya vio conseguidas en este teléfono, para avisar
/// solo de las nuevas.
class InsigniasVistas {
  InsigniasVistas(this.uid, {Future<Directory> Function()? carpeta})
    : _carpeta = carpeta ?? getApplicationSupportDirectory;

  final String uid;
  final Future<Directory> Function() _carpeta;

  Future<File> _archivo() async =>
      File('${(await _carpeta()).path}/insignias_$uid.json');

  /// Guarda [logradas] y devuelve las que no se habían visto. La primera vez
  /// no devuelve ninguna: las que ya tenía antes de esta versión no se avisan.
  Future<Set<String>> registrar(Set<String> logradas) async {
    try {
      final archivo = await _archivo();
      final existe = await archivo.exists();
      final vistas = existe
          ? (jsonDecode(await archivo.readAsString()) as List)
                .cast<String>()
                .toSet()
          : <String>{};
      final nuevas = existe ? logradas.difference(vistas) : <String>{};
      if (!existe || nuevas.isNotEmpty) {
        await archivo.writeAsString(jsonEncode([...vistas, ...logradas]));
      }
      return nuevas;
    } catch (error) {
      debugPrint('No se pudieron revisar las insignias vistas: $error');
      return const {};
    }
  }

  /// Al reiniciar el progreso las insignias se vuelven a avisar.
  Future<void> borrar() async {
    try {
      final archivo = await _archivo();
      if (await archivo.exists()) await archivo.delete();
    } catch (error) {
      debugPrint('No se pudieron borrar las insignias vistas: $error');
    }
  }
}
