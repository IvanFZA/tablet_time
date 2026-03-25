// lib/rutas/navigation.dart
import 'package:flutter/material.dart';

import 'package:tablet_time/pantallas/principal.dart'; // TreatmentsScreen
import 'package:tablet_time/pantallas/alarma.dart'; // AlarmScreen
import 'package:tablet_time/pantallas/history_screen.dart';

/// Llave global para navegar desde NotificationService
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Route<dynamic>? appOnGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/':
      return MaterialPageRoute(builder: (_) => const TreatmentsScreen());

    case '/alarm':
      final payload = settings.arguments as String?;
      return MaterialPageRoute(builder: (_) => AlarmScreen(payload: payload));

    case '/history': // 👈 NUEVA RUTA
      return MaterialPageRoute(builder: (_) => const HistoryScreen());
  }
  return null;
}
