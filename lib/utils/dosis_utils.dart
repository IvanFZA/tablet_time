// lib/utils/dosis_utils.dart
import 'package:flutter/material.dart';
import '../models.dart';

/// Calcula la próxima toma (DateTime) a partir de:
///   - t.hour  (ej. "08:00")
///   - t.frequency (ej. "Cada 8 horas")
DateTime? computeNextDoseDateTime(Treatment t) {
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
      // si ya pasó, siguiente día a misma hora
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

/// Devuelve sólo la hora formateada ("10:00 p. m.") para mostrar en la tarjeta.
String formatNextDoseTime(BuildContext context, Treatment t) {
  final next = computeNextDoseDateTime(t);
  if (next == null) return '--';

  final loc = MaterialLocalizations.of(context);
  final tod = TimeOfDay.fromDateTime(next);
  return loc.formatTimeOfDay(tod);
}
