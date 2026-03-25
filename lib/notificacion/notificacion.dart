// lib/notificacion/notificacion.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'dart:typed_data';
import '../rutas/navigation.dart';
import '../db_helper.dart';
import '../models.dart';
import '../utils/dosis_utils.dart';
import 'package:telephony/telephony.dart';

const String kActionOpenAlarm = 'open_alarm';
const String kActionTakeNow = 'take_now';
const String kActionSnooze5 = 'snooze_5';
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint('🔔 CALLBACK BG');
  debugPrint('   actionId=${response.actionId}');
  debugPrint('   payload=${response.payload}');
  NotificationService.instance
      .handleNotificationActionFromBackground(response);
}
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  final Telephony _telephony = Telephony.instance;

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
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImpl?.requestNotificationsPermission();

    try {
      await androidImpl?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('⚠️ requestExactAlarmsPermission lanzó excepción: $e');
    }

    _initialized = true;
  }

  void _onNotificationResponse(NotificationResponse response) {
    debugPrint('🔔 CALLBACK MAIN');
    debugPrint('   actionId=${response.actionId}');
    debugPrint('   payload=${response.payload}');
    _handleNotificationAction(response, fromBackground: false);
  }

  void handleNotificationActionFromBackground(
      NotificationResponse response) {
    _handleNotificationAction(response, fromBackground: true);
  }
  Future<bool> _ensureSmsPermission() async {
  try {
    final granted = await _telephony.requestPhoneAndSmsPermissions ?? false;
    debugPrint('📨 Permiso SMS otorgado: $granted');
    return granted;
  } catch (e) {
    debugPrint('❌ Error solicitando permisos SMS: $e');
    return false;
  }
}

Future<Map<String, String?>> _getFamilyContact() async {
  try {
    final families = await AppDb.instance.getAllFamilies();

    if (families.isNotEmpty) {
      final fam = families.first;
      return {
        'name': fam['name'] as String?,
        'phone': fam['phone'] as String?,
      };
    }
  } catch (e) {
    debugPrint('❌ Error obteniendo familiar: $e');
  }

  return {
    'name': null,
    'phone': null,
  };
}

String _horaActualTexto() {
  final now = DateTime.now();
  final hh = now.hour.toString().padLeft(2, '0');
  final mm = now.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

Future<void> _sendTakenSms(Treatment treatment) async {
  try {
    final granted = await _ensureSmsPermission();
    if (!granted) {
      debugPrint('⚠️ No se otorgó permiso para enviar SMS');
      return;
    }

    final family = await _getFamilyContact();
    final phone = family['phone'];
    final familyName = family['name'] ?? 'Familiar';

    if (phone == null || phone.trim().isEmpty) {
      debugPrint('⚠️ No hay teléfono del familiar configurado');
      return;
    }

    final hora = _horaActualTexto();
    final nombreMedicamento = treatment.medName;

    final mensaje =
        'Hola $familyName, ya se ha tomado el medicamento '
        '$nombreMedicamento a las $hora.';

    await _telephony.sendSms(
      to: phone,
      message: mensaje,
    );

    debugPrint('✅ SMS enviado: medicamento tomado');
  } catch (e) {
    debugPrint('❌ Error al enviar SMS tomado: $e');
  }
}

Future<void> _sendSnoozedSms(Treatment treatment) async {
  try {
    final granted = await _ensureSmsPermission();
    if (!granted) {
      debugPrint('⚠️ No se otorgó permiso para enviar SMS');
      return;
    }

    final family = await _getFamilyContact();
    final phone = family['phone'];
    final familyName = family['name'] ?? 'Familiar';

    if (phone == null || phone.trim().isEmpty) {
      debugPrint('⚠️ No hay teléfono del familiar configurado');
      return;
    }

    final hora = _horaActualTexto();
    final nombreMedicamento = treatment.medName;

    final mensaje =
        'Hola $familyName, el medicamento '
        '$nombreMedicamento fue pospuesto a las $hora. '
        'Por favor verifica que se lo haya tomado.';

    await _telephony.sendSms(
      to: phone,
      message: mensaje,
    );

    debugPrint('✅ SMS enviado: medicamento pospuesto');
  } catch (e) {
    debugPrint('❌ Error al enviar SMS pospuesto: $e');
  }
}


  void _handleNotificationAction(
    NotificationResponse response, {
    required bool fromBackground,
  }) {
    final payload = response.payload;
    final actionId = response.actionId;

    debugPrint(
      '📲 Notification action. actionId=$actionId payload=$payload fromBackground=$fromBackground',
    );

    if (payload == null || payload.isEmpty) return;

    // Si el usuario toca el cuerpo de la notificación
    if (actionId == null || actionId.isEmpty) {
      navigatorKey.currentState?.pushNamed(
        '/alarm',
        arguments: payload,
      );
      return;
    }

    if (actionId == kActionTakeNow) {
      _handleTakeNow(payload);
      return;
    }

    if (actionId == kActionSnooze5) {
      _handleSnooze(payload);
      return;
    }

    if (actionId == kActionOpenAlarm) {
      navigatorKey.currentState?.pushNamed(
        '/alarm',
        arguments: payload,
      );
      return;
    }
  }

  Future<void> _handleTakeNow(String payload) async {
  try {
    final treatment = await _loadTreatmentFromPayload(payload);
    if (treatment == null || treatment.id == null) {
      debugPrint('⚠️ No se pudo resolver tratamiento desde payload=$payload');
      return;
    }

    // 1) Enviar SMS
    await _sendTakenSms(treatment);

    // 2) Calcular siguiente dosis
    final next = computeNextDoseDateTime(treatment);
    if (next == null) {
      debugPrint('⚠️ No se pudo calcular siguiente dosis');
      return;
    }

    final displayText = treatment.dose.trim().isNotEmpty
        ? '${treatment.medName} (${treatment.dose})'
        : treatment.medName;

    // 3) Cancelar la actual
    await cancelMedicationAlarm(treatment.id!);

    // 4) Programar la siguiente dosis real
    await scheduleMedicationAlarm(
      id: treatment.id!,
      scheduledDate: next,
      title: 'Es hora de tomar tu medicamento',
      body: displayText,
      payload: 'treatment|${treatment.id}|$displayText',
    );

    debugPrint('✅ Toma confirmada desde notificación. Próxima dosis: $next');
  } catch (e) {
    debugPrint('❌ Error en _handleTakeNow: $e');
  }
}

  Future<void> _handleSnooze(String payload) async {
  try {
    final treatment = await _loadTreatmentFromPayload(payload);
    if (treatment == null || treatment.id == null) {
      debugPrint('⚠️ No se pudo resolver tratamiento desde payload=$payload');
      return;
    }

    // 1) Enviar SMS
    await _sendSnoozedSms(treatment);

    final displayText = treatment.dose.trim().isNotEmpty
        ? '${treatment.medName} (${treatment.dose})'
        : treatment.medName;

    final newTime = DateTime.now().add(const Duration(minutes: 5));

    // 2) Cancelar la actual
    await cancelMedicationAlarm(treatment.id!);

    // 3) Reprogramar 5 min
    await scheduleMedicationAlarm(
      id: treatment.id!,
      scheduledDate: newTime,
      title: 'Recordatorio pospuesto',
      body: 'Es hora de tomar $displayText',
      payload: 'treatment|${treatment.id}|$displayText',
    );

    debugPrint('✅ Medicamento pospuesto 5 minutos');
  } catch (e) {
    debugPrint('❌ Error en _handleSnooze: $e');
  }
}

  Future<Treatment?> _loadTreatmentFromPayload(String payload) async {
    final parts = payload.split('|');
    if (parts.isEmpty) return null;

    int? treatmentId;

    if (parts[0] == 'treatment') {
      if (parts.length >= 2) {
        treatmentId = int.tryParse(parts[1]);
      }
    } else {
      treatmentId = int.tryParse(parts[0]);
    }

    if (treatmentId == null) return null;

    final map = await AppDb.instance.getTreatmentById(treatmentId);
    if (map == null) return null;

    return Treatment.fromMap(map);
  }

  Future<void> showInstantTestNotification() async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      'meds_test_channel',
      'Notificaciones de prueba',
      channelDescription: 'Canal para pruebas inmediatas',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      actions: <AndroidNotificationAction>[
  AndroidNotificationAction(
    kActionTakeNow,
    'Tomar',
    showsUserInterface: false,
    cancelNotification: true,
  ),
  AndroidNotificationAction(
    kActionSnooze5,
    'Posponer 5 min',
    showsUserInterface: false,
    cancelNotification: true,
  ),
],
    );

    const details = NotificationDetails(android: androidDetails);

    debugPrint('🔔 Mostrando notificación inmediata de prueba');

    await _plugin.show(
      12345,
      'Prueba inmediata',
      'Si ves esto, las notificaciones funcionan 👌',
      details,
      payload: 'treatment|1|Medicamento de prueba',
    );
  }

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
        '⚠️ NO se programa: fecha no es futura (scheduled=$scheduledDate, now=$now)',
      );
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

const androidDetails = AndroidNotificationDetails(
  'meds_alarm_channel',
  'Alarmas de medicamentos',
  channelDescription: 'Notificaciones tipo alarma para medicamentos',
  importance: Importance.max,
  priority: Priority.max,
  fullScreenIntent: true,
  category: AndroidNotificationCategory.alarm,
  playSound: true,
  enableVibration: true,
  vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
  sound: RawResourceAndroidNotificationSound('alarm_sound'),
  actions: <AndroidNotificationAction>[
    AndroidNotificationAction(
      kActionTakeNow,
      'Tomar',
      showsUserInterface: false,
      cancelNotification: true,
    ),
    AndroidNotificationAction(
      kActionSnooze5,
      'Posponer 5 min',
      showsUserInterface: false,
      cancelNotification: true,
    ),
  ],
);

const details = NotificationDetails(android: androidDetails);

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        details,
        payload: payload,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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

  Future<void> debugPrintPending() async {
    await init();
    final pending = await _plugin.pendingNotificationRequests();
    debugPrint('🔎 Pending notifications (${pending.length}):');
    for (final p in pending) {
      debugPrint(
        '  id=${p.id}, title=${p.title}, body=${p.body}, payload=${p.payload}',
      );
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
          '⚠️ No se pudo calcular siguiente dosis para id=$treatmentId',
        );
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
