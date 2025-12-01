import 'package:flutter/material.dart';
import 'package:tablet_time/db_helper.dart';
import 'package:tablet_time/models.dart';
import 'package:tablet_time/notificacion/notificacion.dart';

const Color kPrimaryBlue = Color(0xFF0F7CC9);
const Color kLightBackground = Color(0xFFE4F3FF);

class MedicationFormScreen extends StatefulWidget {
  const MedicationFormScreen({super.key});

  @override
  State<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends State<MedicationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Nombre
  final _nameController = TextEditingController();

  // Dosis: cantidad + unidad
  final _doseAmountController = TextEditingController();
  String _doseUnit = 'mg';

  // Frecuencia: cada X (número) + unidad
  final _freqValueController = TextEditingController();
  String _freqUnit = 'horas';

  // Duración: cantidad + unidad
  final _durationAmountController = TextEditingController();
  String _durationUnit = 'días';

  // Hora seleccionada
  TimeOfDay? _pickedTime;      // usado para mostrar
  String? _hourToStore;        // "HH:mm" que guardamos en BD

  @override
  void initState() {
    super.initState();
    // Inicializar con la hora actual
    final now = TimeOfDay.now();
    _pickedTime = now;
    _hourToStore =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseAmountController.dispose();
    _freqValueController.dispose();
    _durationAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickHour() async {
    // Usar la hora ya seleccionada o la actual como inicial
    final initial = _pickedTime ?? TimeOfDay.now();

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null && mounted) {
      _pickedTime = picked;
      _hourToStore =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  /// Calcula la próxima toma a partir de:
  ///  - hourStr: "HH:mm" (formato 24h, p.ej. "08:00", "21:30")
  ///  - freqStr: "Cada X horas" / "Cada X días"
  DateTime? _computeNextDoseDateTime(String? hourStr, String freqStr) {
    if (hourStr == null || hourStr.trim().isEmpty) return null;

    // 1) Parsear hora "08:00" o "8:00"
    final regex = RegExp(r'(\d{1,2}):(\d{2})');
    final match = regex.firstMatch(hourStr);
    if (match == null) return null;

    final h = int.tryParse(match.group(1)!) ?? 0;
    final m = int.tryParse(match.group(2)!) ?? 0;

    final now = DateTime.now();
    DateTime start = DateTime(now.year, now.month, now.day, h, m);

    // 2) Parsear frecuencia "Cada 8 horas" / "Cada 1 días"
    int every = 0;
    String unit = 'horas';

    if (freqStr.isNotEmpty) {
      final parts = freqStr.split(RegExp(r'\s+'));
      if (parts.length >= 3 && parts[0].toLowerCase() == 'cada') {
        every = int.tryParse(parts[1]) ?? 0;
        unit = parts[2].toLowerCase();
      }
    }

    // Sin frecuencia válida → misma hora, hoy o mañana
    if (every <= 0) {
      if (start.isAfter(now)) return start;
      return start.add(const Duration(days: 1));
    }

    DateTime next;

    if (start.isAfter(now)) {
      // La primera toma de hoy aún no pasa
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
        // Unidad desconocida → siguiente día a la misma hora
        next = start.add(const Duration(days: 1));
      }
    }

    return next;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final name = _nameController.text.trim();
      final doseAmount = _doseAmountController.text.trim();
      final freqValue = _freqValueController.text.trim();
      final durationAmount = _durationAmountController.text.trim();

      final doseStr = '$doseAmount $_doseUnit';              // ej. "500 mg"
      final freqStr = 'Cada $freqValue $_freqUnit';          // ej. "Cada 8 horas"
      final durationStr = '$durationAmount $_durationUnit';  // ej. "7 días"

      final tr = Treatment(
        medName: name,
        dose: doseStr,
        frequency: freqStr,
        duration: durationStr,
        hour: _hourToStore, // 👈 SIEMPRE "HH:mm"
      );

      // Guardar en BD
      final id = await AppDb.instance.insertTreatment(tr.toMap());

      // Programar alarma si tenemos hora y frecuencia válidas
      final next = _computeNextDoseDateTime(_hourToStore, freqStr);
      if (id != null && next != null) {
        
        await NotificationService.instance.scheduleMedicationAlarm(
          id: id,
          scheduledDate: next,
          title: 'Es hora de tomar tu medicamento',
          body: '$name ($doseStr)',
          payload: 'treatment|$id',  // 👈 importante
        );
      }

      if (!mounted) return;
      Navigator.pop(context, id);
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
      hintText: hint,
      helperText: helper,
      prefixIcon: icon != null ? Icon(icon, color: kPrimaryBlue) : null,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: kPrimaryBlue, width: 2),
      ),
    );
  }

  InputDecoration _decNoIcon({String? hint}) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: kPrimaryBlue, width: 1.8),
      ),
    );
  }

  TextStyle get _labelStyle => const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      );

  TextStyle get _smallBold => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      );

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final horaVisible = _pickedTime != null
        ? loc.formatTimeOfDay(_pickedTime!)
        : 'Cargando hora actual...';

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: kPrimaryBlue,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Nombre del medicamento
                      Text('Nombre del medicamento:', style: _labelStyle),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: _dec(
                          hint: 'Ej. Paracetamol',
                          helper: 'Escribe el nombre comercial o genérico',
                          icon: Icons.medication_outlined,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Escribe el nombre del medicamento'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Dosis
                      Text('Dosis:', style: _labelStyle),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _doseAmountController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              decoration:
                                  _decNoIcon(hint: 'Cantidad (ej. 500)'),
                              style: _smallBold,
                              validator: (v) {
                                final txt = v?.trim() ?? '';
                                if (txt.isEmpty) return 'Ingresa la cantidad';
                                if (int.tryParse(txt) == null) {
                                  return 'Sólo números';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              value: _doseUnit,
                              isDense: true,
                              decoration: _decNoIcon(),
                              style: _smallBold,
                              iconSize: 20,
                              items: const [
                                DropdownMenuItem(
                                    value: 'mg', child: Text('mg')),
                                DropdownMenuItem(
                                    value: 'ml', child: Text('ml')),
                                DropdownMenuItem(
                                    value: 'gotas', child: Text('gotas')),
                                DropdownMenuItem(
                                    value: 'tableta(s)',
                                    child: Text('tableta(s)')),
                                DropdownMenuItem(
                                    value: 'cápsula(s)',
                                    child: Text('cápsula(s)')),
                              ],
                              onChanged: (val) {
                                if (val == null) return;
                                setState(() => _doseUnit = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Frecuencia
                      Text('Frecuencia:', style: _labelStyle),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text('Cada ', style: _smallBold),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 70,
                            child: TextFormField(
                              controller: _freqValueController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              decoration: _decNoIcon(hint: '8'),
                              style: _smallBold,
                              validator: (v) {
                                final txt = v?.trim() ?? '';
                                if (txt.isEmpty) return 'Requerido';
                                if (int.tryParse(txt) == null) {
                                  return 'Número';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _freqUnit,
                              isDense: true,
                              decoration: _decNoIcon(),
                              style: _smallBold,
                              iconSize: 20,
                              items: const [
                                DropdownMenuItem(
                                    value: 'horas', child: Text('horas')),
                                DropdownMenuItem(
                                    value: 'días', child: Text('días')),
                              ],
                              onChanged: (val) {
                                if (val == null) return;
                                setState(() => _freqUnit = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Duración
                      Text('Duración del tratamiento:', style: _labelStyle),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _durationAmountController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              decoration:
                                  _decNoIcon(hint: 'Cantidad (ej. 7)'),
                              style: _smallBold,
                              validator: (v) {
                                final txt = v?.trim() ?? '';
                                if (txt.isEmpty) return 'Ingresa la cantidad';
                                if (int.tryParse(txt) == null) {
                                  return 'Sólo números';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              value: _durationUnit,
                              isDense: true,
                              decoration: _decNoIcon(),
                              style: _smallBold,
                              iconSize: 20,
                              items: const [
                                DropdownMenuItem(
                                    value: 'días', child: Text('días')),
                                DropdownMenuItem(
                                    value: 'semanas',
                                    child: Text('semanas')),
                                DropdownMenuItem(
                                    value: 'meses', child: Text('meses')),
                              ],
                              onChanged: (val) {
                                if (val == null) return;
                                setState(() => _durationUnit = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Hora
                      Text('Hora:', style: _labelStyle),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: _pickHour,
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black26),
                            borderRadius: BorderRadius.circular(18),
                            color: Colors.white,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.alarm, color: kPrimaryBlue),
                              const SizedBox(width: 8),
                              Text(
                                horaVisible,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.keyboard_arrow_down_rounded),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Botón Guardar
                      Center(
                        child: SizedBox(
                          width: 200,
                          height: 46,
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
