import 'package:flutter/material.dart';
import 'package:tablet_time/db_helper.dart';
import 'package:tablet_time/models.dart';
// 👇 importa el módulo donde muestras a los familiares
import 'package:tablet_time/pantallas/familiares.dart';

const Color kPrimaryBlue = Color(0xFF0F7CC9);
const Color kLightBackground = Color(0xFFE4F3FF);

class FamilyFormScreen extends StatefulWidget {
  const FamilyFormScreen({super.key});

  @override
  State<FamilyFormScreen> createState() => _FamilyFormScreenState();
}

class _FamilyFormScreenState extends State<FamilyFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  InputDecoration _decoration({required String hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, color: kPrimaryBlue) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: kPrimaryBlue, width: 2),
      ),
    );
  }

  // ⬇️ GUARDAR Y REDIRIGIR A LA LISTA
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final fam = Family(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
    );

    await AppDb.instance.insertFamily(fam.toMap());

    if (!mounted) return;

    // En lugar de pop, redirigimos al módulo de familiares
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const FamilyListScreen(),
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

            // Formulario
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      const Text(
                        'Registro del Familiar',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: kPrimaryBlue,
                        ),
                      ),
                      const SizedBox(height: 28),

                      const Text('Nombre completo:', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: _decoration(
                          hint: 'Ej. María López',
                          icon: Icons.person_outline,
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 18),

                      const Text('Teléfono:', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: _decoration(
                          hint: 'Ej. 7711234567',
                          icon: Icons.phone_outlined,
                        ),
                        validator: (v) {
                          final t = v?.trim() ?? '';
                          final ok = RegExp(r'^[0-9\s()+-]{7,}$').hasMatch(t);
                          return ok ? null : 'Teléfono no válido';
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 18),

                      const Text('Correo electrónico:', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _decoration(
                          hint: 'Ej. nombre@correo.com',
                          icon: Icons.alternate_email,
                        ),
                        validator: (v) {
                          final e = v?.trim() ?? '';
                          final ok =
                              RegExp(r"^[\w\.\-+]+@([\w\-]+\.)+[A-Za-z]{2,}$").hasMatch(e);
                          return ok ? null : 'Correo no válido';
                        },
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 32),

                      Center(
                        child: SizedBox(
                          width: 220,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            child: const Text(
                              'Registrar',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
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

            // Barra inferior
            Container(height: 24, color: kPrimaryBlue),
          ],
        ),
      ),
    );
  }
}
