import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Notificaciones para volver a jugar: una cada 12 horas desde la última vez
/// que se abrió la app, con textos que se van turnando.
class Recordatorios {
  static const mensajes = [
    'Hay canciones por descubrir 🎶',
    'Encuentra la melodía y disfruta la canción 🪗',
    'Desafía a tus amigos en una sala 👥',
  ];
  static const _cada = Duration(hours: 12);
  // Una semana por delante; cada vez que se abre la app se reprograman.
  static const _cantidad = 14;

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Siguientes [cantidad] recordatorios a partir de [desde]: cada 12 h y
  /// turnando los textos.
  @visibleForTesting
  static List<(DateTime, String)> plan(
    DateTime desde, {
    int cantidad = _cantidad,
  }) => [
    for (var i = 1; i <= cantidad; i++)
      (desde.add(_cada * i), mensajes[(i - 1) % mensajes.length]),
  ];

  static Future<void> programar() async {
    // shortcut: solo Android; para iOS habría que pedir permiso con
    // DarwinInitializationSettings.
    if (!Platform.isAndroid) return;
    try {
      tz.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _plugin.cancelAll();
      const detalles = NotificationDetails(
        android: AndroidNotificationDetails(
          'recordatorios',
          'Recordatorios',
          channelDescription: 'Avisos para volver a jugar RIFF',
        ),
      );
      for (final (i, (cuando, texto)) in plan(DateTime.now()).indexed) {
        await _plugin.zonedSchedule(
          id: i,
          scheduledDate: tz.TZDateTime.from(cuando, tz.UTC),
          notificationDetails: detalles,
          // Sin alarmas exactas: no pide permisos extra y 12 h no necesitan
          // precisión al minuto.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: 'RIFF',
          body: texto,
        );
      }
    } catch (error) {
      debugPrint('No se pudieron programar los recordatorios: $error');
    }
  }
}
