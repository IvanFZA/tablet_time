import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tablet_time/db_helper.dart';
import 'package:tablet_time/models.dart';
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

  bool _saving = false;

  static const int _maxNameLength = 60;
  static const int _phoneLength = 10;
  static const int _maxEmailLength = 100;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  InputDecoration _decoration({
    required String hint,
    IconData? icon,
    String? counterText,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, color: kPrimaryBlue) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      counterText: counterText,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: kPrimaryBlue, width: 2),
      ),
    );
  }

  String _normalizeSpaces(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _validateName(String? value) {
    final text = _normalizeSpaces(value ?? '');

    if (text.isEmpty) {
      return 'Ingresa el nombre completo';
    }

    if (text.length < 3) {
      return 'El nombre debe tener al menos 3 caracteres';
    }

    if (text.length > _maxNameLength) {
      return 'El nombre no debe exceder $_maxNameLength caracteres';
    }

    final regex = RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s'.-]+$");
    if (!regex.hasMatch(text)) {
      return 'El nombre contiene caracteres no válidos';
    }

    return null;
  }

  String? _validatePhone(String? value) {
    final text = (value ?? '').trim();

    if (text.isEmpty) {
      return 'Ingresa el número de teléfono';
    }

    if (!RegExp(r'^\d+$').hasMatch(text)) {
      return 'El teléfono solo debe contener números';
    }

    if (text.length != _phoneLength) {
      return 'El teléfono debe tener $_phoneLength dígitos';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    final text = (value ?? '').trim();

    if (text.isEmpty) {
      return 'Ingresa el correo electrónico';
    }

    if (text.length > _maxEmailLength) {
      return 'El correo no debe exceder $_maxEmailLength caracteres';
    }

    final regex = RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$');
    if (!regex.hasMatch(text)) {
      return 'Correo electrónico no válido';
    }

    return null;
  }

  Future<void> _submit() async {
    if (_saving) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final fam = Family(
      name: _normalizeSpaces(_nameCtrl.text),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().toLowerCase(),
    );

    try {
      setState(() {
        _saving = true;
      });

      await AppDb.instance.insertFamily(fam.toMap());

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const FamilyListScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al registrar familiar: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightBackground,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 60,
              color: kPrimaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const Spacer(),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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

                      const Text(
                        'Nombre completo:',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: _decoration(
                          hint: 'Ej. María López',
                          icon: Icons.person_outline,
                        ),
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(_maxNameLength),
                          FilteringTextInputFormatter.allow(
                            RegExp(r"[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s'.-]"),
                          ),
                        ],
                        validator: _validateName,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 18),

                      const Text(
                        'Teléfono:',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: _decoration(
                          hint: 'Ej. 7711234567',
                          icon: Icons.phone_outlined,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(_phoneLength),
                        ],
                        validator: _validatePhone,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 18),

                      const Text(
                        'Correo electrónico:',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _decoration(
                          hint: 'Ej. nombre@correo.com',
                          icon: Icons.alternate_email,
                        ),
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(_maxEmailLength),
                        ],
                        validator: _validateEmail,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 32),

                      Center(
                        child: SizedBox(
                          width: 220,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
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
            Container(height: 24, color: kPrimaryBlue),
          ],
        ),
      ),
    );
  }
}