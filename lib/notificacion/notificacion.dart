// lib/notificacion/notificacion.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../rutas/navigation.dart'; // navigatorKey
import '../db_helper.dart';         // 👈 BD
import '../models.dart';            // 👈 Treatment

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // Inicializar base de zonas horarias
    tzdata.initializeTimeZones();

    // Zona local
    tz.setLocalLocation(tz.getLocation('America/Mexico_City'));

    // Inicialización Android
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Pedir permiso de notificaciones (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  /// =======================
  /// NOTIFICACIÓN INMEDIATA
  /// =======================
  Future<void> showInstantTestNotification() async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      'meds_test_channel',
      'Notificaciones de prueba',
      channelDescription: 'Canal para pruebas inmediatas',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      12345,
      'Prueba inmediata',
      'Si ves esto, las notificaciones funcionan 👌',
      details,
      payload: 'test|Prueba inmediata',
    );
  }

  /// Callback cuando el usuario TOCA la notificación (app en foreground/background)
  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;

    // 1) Si es un tratamiento, reprogramar siguiente dosis
    if (payload != null && payload.startsWith('treatment|')) {
      final parts = payload.split('|');
      if (parts.length >= 2) {
        final id = int.tryParse(parts[1]);
        if (id != null) {
          _scheduleNextDoseFromTreatment(id);
        }
      }
    }

    // 2) Navegación a la pantalla de alarma (si quieres mostrar algo)
    navigatorKey.currentState?.pushNamed(
      '/alarm',
      arguments: payload,
    );
  }

  /// Cuando se toca la notificación con la app terminada (según Android)
  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse response) {
    // Aquí podrías loguear algo si quieres
  }

  /// ==========================
  /// PROGRAMAR ALARMA (MEDS)
  /// ==========================
  Future<void> scheduleMedicationAlarm({
    required int id,
    required DateTime scheduledDate,
    required String title,
    required String body,
    String? payload,
  }) async {
    await init(); // asegura init + zona horaria

    final now = DateTime.now();
    if (!scheduledDate.isAfter(now)) {
      debugPrint(
          '⚠️ scheduledDate ($scheduledDate) no es futuro (now=$now). No se programa.');
      return;
    }

    // Convertimos a TZDateTime usando la zona local
    final tzDate = tz.TZDateTime(
      tz.local,
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      scheduledDate.hour,
      scheduledDate.minute,
      scheduledDate.second,
    );

    debugPrint('⏰ Programando alarma id=$id para $scheduledDate (tzDate=$tzDate)');

    const androidDetails = AndroidNotificationDetails(
      'meds_alarm_channel',
      'Alarmas de medicamentos',
      channelDescription: 'Notificaciones tipo alarma para medicamentos',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
    );

    const details = NotificationDetails(android: androidDetails);

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    } on PlatformException catch (e) {
      debugPrint('❌ Error programando alarma (inexact): $e');
    }
  }

  /// Cancelar la alarma de un medicamento por id (si existe)
  Future<void> cancelMedicationAlarm(int id) async {
    await init();
    await _plugin.cancel(id);
  }

  /// Cancelar todas las notificaciones
  Future<void> cancelAllAlarms() async {
    await init();
    await _plugin.cancelAll();
  }

  /// Prueba: alarma en 10 segundos (puedes seguir usándola si quieres)
  Future<void> scheduleTestAlarm() async {
    await init();
    final scheduled = DateTime.now().add(const Duration(seconds: 10));
    await scheduleMedicationAlarm(
      id: 999,
      scheduledDate: scheduled,
      title: 'Prueba de alarma',
      body: 'Es hora de tomar tu medicamento de prueba',
      payload: 'test|Prueba de medicamento',
    );
  }

  // ==========================================================
  // CÁLCULO DE SIGUIENTE DOSIS A PARTIR DEL TRATAMIENTO (SIN UI)
  // ==========================================================

  DateTime? _computeNextDoseDateTime(Treatment t) {
    final hourStr = t.hour;
    if (hourStr == null || hourStr.trim().isEmpty) {
      return null;
    }

    // 1) Parsear "hh:mm"
    final regex = RegExp(r'(\d{1,2}):(\d{2})');
    final match = regex.firstMatch(hourStr);
    if (match == null) {
      return null;
    }

    var h = int.tryParse(match.group(1)!) ?? 0;
    final m = int.tryParse(match.group(2)!) ?? 0;

    final lower = hourStr.toLowerCase();

    final hasAm = lower.contains('am') ||
        lower.contains('a. m') ||
        lower.contains('a.m');
    final hasPm = lower.contains('pm') ||
        lower.contains('p. m') ||
        lower.contains('p.m');

    if (hasPm && h < 12) h += 12;
    if (hasAm && h == 12) h = 0;

    final now = DateTime.now();
    DateTime start = DateTime(now.year, now.month, now.day, h, m);

    // 2) Parsear frecuencia "Cada 8 horas"
    final freqStr = t.frequency;
    int every = 0;
    String unit = 'horas';

    if (freqStr.isNotEmpty) {
      final parts = freqStr.split(RegExp(r'\s+'));
      if (parts.length >= 3 && parts[0].toLowerCase() == 'cada') {
        every = int.tryParse(parts[1]) ?? 0;
        unit = parts[2].toLowerCase();
      }
    }

    if (every <= 0) {
      if (start.isAfter(now)) {
        return start;
      } else {
        return start.add(const Duration(days: 1));
      }
    }

    DateTime next = start;

    if (start.isAfter(now)) {
      next = start;
    } else {
      if (unit.startsWith('hora')) {
        final diffHours = now.difference(start).inHours;
        final intervals = (diffHours ~/ every) + 1;
        next = start.add(Duration(hours: intervals * every));
      } else if (unit.startsWith('día')) {
        final diffDays = now.difference(start).inDays;
        final intervals = (diffDays ~/ every) + 1;
        next = start.add(Duration(days: intervals * every));
      } else {
        next = start;
        if (!next.isAfter(now)) {
          next = next.add(const Duration(days: 1));
        }
      }
    }

    return next;
  }

  /// Cargar tratamiento por ID, calcular su siguiente dosis y reprogramar alarma.
  Future<void> _scheduleNextDoseFromTreatment(int treatmentId) async {
  try {
    final map = await AppDb.instance.getTreatmentById(treatmentId);
    if (map == null) {
      debugPrint('⚠️ No se encontró tratamiento id=$treatmentId');
      return;
    }

    final t = Treatment.fromMap(map);
    final next = _computeNextDoseDateTime(t);
    if (next == null) {
      debugPrint('⚠️ No se pudo calcular siguiente dosis para id=$treatmentId');
      return;
    }

    // 👇 AQUÍ aseguramos que el mensaje use nombre y dosis, NO el id
    final title = 'Es hora de tomar tu medicamento';
    final body = '${t.medName} (${t.dose})';

    await scheduleMedicationAlarm(
      id: t.id!,                 // <- esto es SOLO el identificador interno de la notificación
      scheduledDate: next,
      title: title,              // <- este es el título que ve el usuario
      body: body,                // <- y este el cuerpo
      payload: 'treatment|${t.id}',
    );

    debugPrint('✅ Reprogramada siguiente dosis de id=${t.id} para $next');
  } catch (e) {
    debugPrint('❌ Error reprogramando siguiente dosis: $e');
  }
}

}
