import 'package:flutter/material.dart';
import 'pantallas/principal.dart'; // Asegúrate de que aquí está TreatmentsScreen
import 'db_helper.dart';          // opcional: para precalentar la BD

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Opcional: abre/crea la BD al inicio (útil para evitar latencia en la 1ª pantalla)
  await AppDb.instance.database;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tratamientos',
      theme: ThemeData(
        useMaterial3: false,
        primaryColor: const Color(0xFF0F7CC9),
        scaffoldBackgroundColor: const Color(0xFFE4F3FF),
      ),
      home: const TreatmentsScreen(), // la pantalla que moviste a principal.dart
    );
  }
}
