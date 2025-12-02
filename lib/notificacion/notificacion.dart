// lib/notificacion/notificacion.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../rutas/navigation.dart'; // navigatorKey
import '../db_helper.dart';
import '../models.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    debugPrint('🔔 init() NotificationService');

    // Timezone
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Mexico_City'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Permiso de notificaciones (Android 13+)
    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImpl?.requestNotificationsPermission();

    // 👉 pedir permiso para EXACT ALARMS (Android 13/14)
    try {
      await androidImpl?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('⚠️ requestExactAlarmsPermission lanzó excepción: $e');
    }

    _initialized = true;
  }

  // =================== TEST INMEDIATA ===================
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

    debugPrint('🔔 Mostrando notificación inmediata de prueba');

    await _plugin.show(
      12345,
      'Prueba inmediata',
      'Si ves esto, las notificaciones funcionan 👌',
      details,
      payload: 'test|Prueba inmediata',
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    debugPrint('📲 _onNotificationTap payload=$payload');

    // Reprogramar siguiente dosis si viene treatment
    if (payload != null && payload.startsWith('treatment|')) {
      final parts = payload.split('|');
      if (parts.length >= 2) {
        final id = int.tryParse(parts[1]);
        if (id != null) {
          _scheduleNextDoseFromTreatment(id);
        }
      }
    }

    navigatorKey.currentState?.pushNamed(
      '/alarm',
      arguments: payload,
    );
  }

  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse response) {
    // Para logs de fondo si los necesitas
    debugPrint('📲 notificationTapBackground payload=${response.payload}');
  }

  // ================== PROGRAMAR ALARMA ==================
  Future<void> scheduleMedicationAlarm({
    required int id,
    required DateTime scheduledDate,
    required String title,
    required String body,
    String? payload,
  }) async {
    await init();

    final now = DateTime.now();
    if (!scheduledDate.isAfter(now)) {
      debugPrint(
          '⚠️ NO se programa: fecha no es futura (scheduled=$scheduledDate, now=$now)');
      return;
    }

    final tzDate = tz.TZDateTime(
      tz.local,
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      scheduledDate.hour,
      scheduledDate.minute,
      scheduledDate.second,
    );

    debugPrint(
        '⏰ Programando alarma id=$id para $scheduledDate (tzDate=$tzDate)');

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

        // 👉 AHORA USAMOS EXACT ALARM
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );

      debugPrint('✅ zonedSchedule OK (id=$id)');
    } on PlatformException catch (e) {
      debugPrint('❌ Error programando alarma (exact): $e');
    }
  }

  Future<void> cancelMedicationAlarm(int id) async {
    await init();
    await _plugin.cancel(id);
  }

  Future<void> cancelAllAlarms() async {
    await init();
    await _plugin.cancelAll();
  }

  // Para ver si realmente hay notificaciones pendientes
  Future<void> debugPrintPending() async {
    await init();
    final pending = await _plugin.pendingNotificationRequests();
    debugPrint('🔎 Pending notifications (${pending.length}):');
    for (final p in pending) {
      debugPrint(
          '  id=${p.id}, title=${p.title}, body=${p.body}, payload=${p.payload}');
    }
  }

  // ========== Cálculo siguiente dosis ==========
  DateTime? _computeNextDoseDateTime(Treatment t) {
    final hourStr = t.hour;
    if (hourStr == null || hourStr.trim().isEmpty) return null;

    final regex = RegExp(r'(\d{1,2}):(\d{2})');
    final match = regex.firstMatch(hourStr);
    if (match == null) return null;

    var h = int.tryParse(match.group(1)!) ?? 0;
    final m = int.tryParse(match.group(2)!) ?? 0;

    final lower = hourStr.toLowerCase();
    final hasAm =
        lower.contains('am') || lower.contains('a. m') || lower.contains('a.m');
    final hasPm =
        lower.contains('pm') || lower.contains('p. m') || lower.contains('p.m');

    if (hasPm && h < 12) h += 12;
    if (hasAm && h == 12) h = 0;

    final now = DateTime.now();
    DateTime start = DateTime(now.year, now.month, now.day, h, m);

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
      if (start.isAfter(now)) return start;
      return start.add(const Duration(days: 1));
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
        debugPrint(
            '⚠️ No se pudo calcular siguiente dosis para id=$treatmentId');
        return;
      }

      final title = 'Es hora de tomar tu medicamento';
      final body = '${t.medName} (${t.dose})';

      await scheduleMedicationAlarm(
        id: t.id!,
        scheduledDate: next,
        title: title,
        body: body,
        payload: 'treatment|${t.id}',
      );

      debugPrint('✅ Reprogramada siguiente dosis de id=${t.id} para $next');
    } catch (e) {
      debugPrint('❌ Error reprogramando siguiente dosis: $e');
    }
  }
}
