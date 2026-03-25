// lib/main.dart
import 'package:flutter/material.dart';
import 'pantallas/principal.dart';
import 'pantallas/alarma.dart';
import 'notificacion/notificacion.dart';
import 'rutas/navigation.dart'; // 👈 aquí ahora vive navigatorKey
import 'package:telephony/telephony.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializas notificaciones
  await NotificationService.instance.init();

  // Pides permisos de SMS / teléfono
  final Telephony telephony = Telephony.instance;
  await telephony.requestPhoneAndSmsPermissions;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // 👈 la misma llave
      debugShowCheckedModeBanner: false,
      title: 'Tratamientos',
      initialRoute: '/',
      routes: {
        '/': (_) => const TreatmentsScreen(),
        '/alarm': (ctx) {
          final payload = ModalRoute.of(ctx)!.settings.arguments as String?;
          return AlarmScreen(payload: payload);
        },
      },
    );
  }
}
