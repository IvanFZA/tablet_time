import 'package:flutter/material.dart';
import 'package:tablet_time/db_helper.dart';
import 'package:tablet_time/models.dart';


const Color kPrimaryBlue = Color(0xFF0F7CC9);
const Color kLightBackground = Color(0xFFE4F3FF);

class EditMedicationScreen extends StatefulWidget {
  final Treatment treatment; // 👈 medicamento a editar

  const EditMedicationScreen({super.key, required this.treatment});

  @override
  State<EditMedicationScreen> createState() => _EditMedicationScreenState();
}

class _EditMedicationScreenState extends State<EditMedicationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _doseController = TextEditingController();
  final _freqController = TextEditingController();
  final _durationController = TextEditingController();
  String? _pickedHourString;

  @override
  void initState() {
    super.initState();
    final t = widget.treatment;
    _nameController.text = t.medName;
    _doseController.text = t.dose;
    _freqController.text = t.frequency;
    _durationController.text = t.duration;
    _pickedHourString = t.hour;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    _freqController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: kPrimaryBlue, width: 2),
      ),
    );
  }

  Future<void> _pickHour() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
    );
    if (picked != null) {
      final loc = MaterialLocalizations.of(context);
      setState(() {
        _pickedHourString = loc.formatTimeOfDay(picked);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final medName = _nameController.text.trim();
      final dose = _doseController.text.trim();
      final freq = _freqController.text.trim();
      final duration = _durationController.text.trim();
      final hour = _pickedHourString;

      final id = widget.treatment.id;
      if (id == null) {
        // seguridad: no debería pasar, pero por si acaso
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró el ID del tratamiento')),
        );
        return;
      }

      await AppDb.instance.updateTreatment(id, {
        'med_name': medName,
        'dose': dose,
        'frequency': freq,
        'duration': duration,
        'hour': hour,
      });

      if (!mounted) return;
      Navigator.pop(context, true); // 👈 regreso true para que recargues la lista
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar cambios: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Formulario (mismo diseño que el de alta)
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          'Editar medicamento',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: kPrimaryBlue,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Nombre
                        const Text(
                          'Nombre del medicamento:',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameController,
                          decoration: _inputDecoration(),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Escribe el nombre del medicamento';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        // Dosis
                        const Text('Dosis:', style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _doseController,
                          decoration: _inputDecoration(),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Ingresa la dosis' : null,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        // Frecuencia
                        const Text('Frecuencia:',
                            style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _freqController,
                          decoration: _inputDecoration(),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Ingresa la frecuencia'
                              : null,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        // Duración
                        const Text('Duración:',
                            style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _durationController,
                          decoration: _inputDecoration(),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Ingresa la duración'
                              : null,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _save(),
                        ),
                        const SizedBox(height: 16),

                        // Hora opcional
                        const Text('Hora (opcional):',
                            style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickHour,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
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
                                  _pickedHourString ?? 'Selecciona una hora',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _pickedHourString == null
                                        ? Colors.black54
                                        : Colors.black87,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.keyboard_arrow_down_rounded),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Botón "Guardar cambios"
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
                                'Guardar cambios',
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
            ),

            // Barra inferior azul
            Container(
              height: 24,
              color: kPrimaryBlue,
            ),
          ],
        ),
      ),
    );
  }
}
