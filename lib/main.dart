// lib/main.dart
import 'package:flutter/material.dart';
import 'pantallas/principal.dart';
import 'pantallas/alarma.dart';
import 'notificacion/notificacion.dart';
import 'rutas/navigation.dart'; // 👈 aquí ahora vive navigatorKey

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.instance.init();

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
