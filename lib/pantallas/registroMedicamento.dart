import 'package:flutter/material.dart';
import 'package:tablet_time/db_helper.dart';
import 'package:tablet_time/models.dart';

const Color kPrimaryBlue = Color(0xFF0F7CC9);
const Color kLightBackground = Color(0xFFE4F3FF);

class MedicationFormScreen extends StatefulWidget {
  const MedicationFormScreen({super.key});

  @override
  State<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends State<MedicationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _doseController = TextEditingController();
  final _freqController = TextEditingController();
  final _durationController = TextEditingController();

  String? _pickedHourString; // opcional: "8:00 AM"

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    _freqController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickHour() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: now);
    if (picked != null && mounted) {
      final loc = MaterialLocalizations.of(context);
      setState(() => _pickedHourString = loc.formatTimeOfDay(picked));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final tr = Treatment(
        medName: _nameController.text.trim(),
        dose: _doseController.text.trim(),
        frequency: _freqController.text.trim(),
        duration: _durationController.text.trim(),
        hour: _pickedHourString, // puede ser null
      );

      final id = await AppDb.instance.insertTreatment(tr.toMap());
      if (!mounted) return;
      Navigator.pop(context, id); // regresa el ID insertado
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }
  }

  InputDecoration _dec({
    required String hint,
    String? helper,
    IconData? icon,
  }) {
    return InputDecoration(
      hintText: hint,                // 👈 ejemplo directo en el campo
      helperText: helper,            // 👈 ejemplo adicional bajo el campo
      prefixIcon: icon != null ? Icon(icon, color: kPrimaryBlue) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: kPrimaryBlue, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior azul con botón X
            Container(
              height: 60,
              color: kPrimaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Contenido (formulario)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      const Text(
                        'Registro de\nmedicamentos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: kPrimaryBlue,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Nombre del medicamento
                      const Text('Nombre del medicamento:', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: _dec(
                          hint: 'Ej. Paracetamol',
                          helper: 'Escribe el nombre comercial o genérico',
                          icon: Icons.medication_outlined,
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Escribe el nombre del medicamento' : null,
                      ),
                      const SizedBox(height: 16),

                      // Dosis
                      const Text('Dosis:', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _doseController,
                        textInputAction: TextInputAction.next,
                        decoration: _dec(
                          hint: 'Ej. 500 mg',
                          helper: 'Incluye unidad: mg, ml, gotas, etc.',
                          icon: Icons.scale_outlined,
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Ingresa la dosis' : null,
                      ),
                      const SizedBox(height: 16),

                      // Frecuencia
                      const Text('Frecuencia:', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _freqController,
                        textInputAction: TextInputAction.next,
                        decoration: _dec(
                          hint: 'Ej. Cada 8 horas',
                          helper: 'También puede ser "1 vez al día" o "cada noche"',
                          icon: Icons.repeat_on_outlined,
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Ingresa la frecuencia' : null,
                      ),
                      const SizedBox(height: 16),

                      // Duración
                      const Text('Duración:', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _durationController,
                        textInputAction: TextInputAction.done,
                        decoration: _dec(
                          hint: 'Ej. 7 días',
                          helper: 'Tiempo total del tratamiento',
                          icon: Icons.calendar_month_outlined,
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Ingresa la duración' : null,
                        onFieldSubmitted: (_) => _save(),
                      ),
                      const SizedBox(height: 16),

                      // Hora (opcional)
                      const Text('Hora (opcional):', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pickHour,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black26),
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.white,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.alarm, color: kPrimaryBlue),
                              const SizedBox(width: 10),
                              Text(
                                _pickedHourString ?? 'Ej. 8:00 AM (toca para elegir)',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _pickedHourString == null ? Colors.black54 : Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.keyboard_arrow_down_rounded),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Botón Guardar
                      Center(
                        child: SizedBox(
                          width: 200,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text(
                              'Guardar',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Barra inferior azul
            Container(height: 24, color: kPrimaryBlue),
          ],
        ),
      ),
    );
  }
}
