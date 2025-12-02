// lib/pantallas/alarm_screen.dart
import 'package:flutter/material.dart';
import 'package:tablet_time/db_helper.dart';
import 'package:tablet_time/models.dart';
import 'package:tablet_time/notificacion/notificacion.dart';
import 'package:tablet_time/utils/dosis_utils.dart'; // si usas computeNextDoseDateTime aquí

const Color kPrimaryBlue = Color(0xFF0F7CC9);
const Color kLightBackground = Color(0xFFE4F3FF);

class AlarmScreen extends StatefulWidget {
  final String? payload; // ej. "treatment|3|Paracetamol 500 mg (500 mg)" o "3|Paracetamol 500 mg"

  const AlarmScreen({super.key, this.payload});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  Treatment? _treatment;
  int? _treatmentId;
  String _medName = 'Medicamento';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFromPayload();
  }

  void _parsePayload() {
    final payload = widget.payload;
    if (payload == null) return;

    final parts = payload.split('|');
    if (parts.isEmpty) return;

    if (parts[0] == 'treatment') {
      // Formato nuevo: "treatment|id|texto"
      if (parts.length >= 2) {
        _treatmentId = int.tryParse(parts[1]);
      }
      if (parts.length >= 3) {
        _medName = parts[2];
      }
    } else {
      // Formato viejo: "id|texto"
      if (parts.length >= 1) {
        _treatmentId = int.tryParse(parts[0]);
      }
      if (parts.length >= 2) {
        _medName = parts[1];
      }
    }
  }

  Future<void> _loadFromPayload() async {
    _parsePayload();

    if (_treatmentId == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    final map = await AppDb.instance.getTreatmentById(_treatmentId!);
    if (!mounted) return;

    if (map != null) {
      _treatment = Treatment.fromMap(map);
      _medName = _treatment!.medName;
    }

    setState(() {
      _loading = false;
    });
  }

  void _goBackToHome() {
    // Regresa al home y destruye las pantallas anteriores
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _onTomarMedicamento() async {
    if (_treatment != null && _treatment!.id != null) {
      // Usa tu utilidad de cálculo (si la tienes) o lógica interna
      final next = computeNextDoseDateTime(_treatment!);
      if (next != null) {
        final displayText = '${_treatment!.medName} (${_treatment!.dose})';

        await NotificationService.instance.scheduleMedicationAlarm(
          id: _treatment!.id!,
          scheduledDate: next,
          title: 'Es hora de tomar tu medicamento',
          body: displayText,
          payload: 'treatment|${_treatment!.id}|$displayText',
        );
      }
    }

    _goBackToHome();
  }

  Future<void> _onPosponer() async {
    final id = _treatment?.id ?? _treatmentId ?? 1000;
    final name = _treatment?.medName ?? _medName;
    final dose = _treatment?.dose ?? '';
    final displayText = dose.isNotEmpty ? '$name ($dose)' : name;

    final now = DateTime.now();
    final newTime = now.add(const Duration(minutes: 5));

    await NotificationService.instance.scheduleMedicationAlarm(
      id: id,
      scheduledDate: newTime,
      title: 'Recordatorio pospuesto',
      body: 'Es hora de tomar $displayText',
      payload: 'treatment|$id|$displayText',
    );

    _goBackToHome();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Si el usuario presiona el botón físico "atrás"
      onWillPop: () async {
        _goBackToHome();
        return false;
      },
      child: Scaffold(
        backgroundColor: kLightBackground,
        body: SafeArea(
          child: Column(
            children: [
              // Barra superior
              Container(
                height: 60,
                color: kPrimaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _goBackToHome,
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Alarma de medicamento',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.alarm,
                                  size: 90, color: kPrimaryBlue),
                              const SizedBox(height: 24),
                              const Text(
                                'Es hora de tomar tu medicamento',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: kPrimaryBlue,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _medName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 40),

                              // Botón Tomar medicamento
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: _onTomarMedicamento,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kPrimaryBlue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  icon: const Icon(Icons.check,
                                      color: Colors.white),
                                  label: const Text(
                                    'Tomar medicamento',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Botón Posponer
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: _onPosponer,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: kPrimaryBlue, width: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  icon: const Icon(Icons.snooze,
                                      color: kPrimaryBlue),
                                  label: const Text(
                                    'Posponer 5 minutos',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: kPrimaryBlue,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),

              Container(
                height: 24,
                color: kPrimaryBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
