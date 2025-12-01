// lib/pantallas/principal.dart
import 'package:flutter/material.dart';
import 'package:tablet_time/pantallas/registroMedicamento.dart';
import 'package:tablet_time/pantallas/registrofamiliar.dart';
import 'package:tablet_time/pantallas/familiares.dart';
import 'package:tablet_time/pantallas/modMedicamento.dart';
import 'package:tablet_time/db_helper.dart';
import 'package:tablet_time/models.dart';
import 'package:tablet_time/notificacion/notificacion.dart';
import 'package:tablet_time/utils/dosis_utils.dart';

const Color kPrimaryBlue = Color(0xFF0F7CC9);
const Color kLightBackground = Color(0xFFE4F3FF);

class TreatmentsScreen extends StatefulWidget {
  const TreatmentsScreen({super.key});

  @override
  State<TreatmentsScreen> createState() => _TreatmentsScreenState();
}

class _TreatmentsScreenState extends State<TreatmentsScreen> {
  bool _isMenuOpen = false;
  late Future<List<Treatment>> _futureTreatments;

  @override
  void initState() {
    super.initState();
    _futureTreatments = _loadTreatments();
  }

  Future<List<Treatment>> _loadTreatments() async {
    final rows = await AppDb.instance.getAllTreatments();
    return rows.map((m) => Treatment.fromMap(m)).toList();
  }

  void _reload() {
    setState(() {
      _futureTreatments = _loadTreatments();
    });
  }

  void _toggleMenu() => setState(() => _isMenuOpen = !_isMenuOpen);

  void _closeMenu() {
    if (_isMenuOpen) setState(() => _isMenuOpen = false);
  }

  Future<void> _goToAddMedication() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MedicationFormScreen()),
    );
    if (result != null && mounted) _reload();
  }

  Future<void> _goToEditMedication(Treatment t) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditMedicationScreen(treatment: t),
      ),
    );
    if (result == true && mounted) {
      _reload();
    }
  }

  // ---------- CONFIRMACIONES / ELIMINAR ----------

  Future<bool?> _confirmDelete(String name) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar tratamiento'),
        content: Text('¿Quieres eliminar "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmEdit(String name) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar tratamiento'),
        content: Text('¿Quieres editar "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Editar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTreatment(Treatment t) async {
    if (t.id == null) return;

    // 1) Cancelar notificación de ese tratamiento
    await NotificationService.instance.cancelMedicationAlarm(t.id!);

    // 2) Borrar de la BD
    await AppDb.instance.deleteTreatment(t.id!);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tratamiento eliminado')),
    );
    _reload();
  }

  // ------------------------------ BUILD ------------------------------

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: kLightBackground,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _TopBar(onMenuTap: _toggleMenu),

                // HEADER FIJO
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: const [
                      SizedBox(height: 24),
                      _ProfileHeader(),
                      SizedBox(height: 16),
                      Text(
                        'TRATAMIENTOS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: kPrimaryBlue,
                        ),
                      ),
                      SizedBox(height: 12),
                    ],
                  ),
                ),

                // LISTA DESDE BD
                Expanded(
                  child: FutureBuilder<List<Treatment>>(
                    future: _futureTreatments,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      if (snap.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text('Error al cargar: ${snap.error}'),
                          ),
                        );
                      }
                      final items = snap.data ?? [];
                      if (items.isEmpty) {
                        return ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 24,
                          ),
                          children: const [
                            SizedBox(height: 40),
                            Center(
                              child: Text(
                                'No hay tratamientos registrados',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final t = items[i];
                          final displayName =
                              '${t.medName}${(t.dose.isNotEmpty) ? ' ${t.dose}' : ''}';

                          // próxima hora de toma (texto) —> misma lógica que la alarma
                          final nextTime = formatNextDoseTime(context, t);

                          // Swipe para borrar con confirmación
                          return Dismissible(
                            key: ValueKey('t_${t.id ?? '$i-${t.medName}'}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              color: Colors.red.shade400,
                              child: const Icon(Icons.delete,
                                  color: Colors.white),
                            ),
                            confirmDismiss: (_) => _confirmDelete(displayName),
                            onDismissed: (_) async => _deleteTreatment(t),

                            // Mantener presionado para editar
                            child: GestureDetector(
                              onLongPress: () async {
                                final ok =
                                    await _confirmEdit(displayName) ?? false;
                                if (ok) {
                                  await _goToEditMedication(t);
                                }
                              },
                              child: TreatmentCard(
                                name: displayName,
                                time: nextTime, // próxima hora = hora de alarma
                                onDelete: t.id == null
                                    ? null
                                    : () async {
                                        final ok =
                                            await _confirmDelete(displayName) ??
                                                false;
                                        if (ok) await _deleteTreatment(t);
                                      },
                                onEdit: () => _goToEditMedication(t),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // BARRA INFERIOR CON +
                _BottomAddBar(onAdd: _goToAddMedication),
              ],
            ),

            if (_isMenuOpen)
              PositionedFillMenu(
                width: width,
                onClose: _closeMenu,
              ),
          ],
        ),
      ),
    );
  }
}

/// Barra superior con botón de menú
class _TopBar extends StatelessWidget {
  final VoidCallback onMenuTap;
  const _TopBar({super.key, required this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kPrimaryBlue,
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onMenuTap,
            icon: const Icon(Icons.menu),
            color: Colors.white,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

/// Widget que pinta el menú desplegable
class PositionedFillMenu extends StatelessWidget {
  final double width;
  final VoidCallback onClose;

  const PositionedFillMenu({
    super.key,
    required this.width,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Row(
        children: [
          Container(
            width: width * 0.55,
            color: kPrimaryBlue.withOpacity(0.8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                _MenuButton(
                  text: 'Registrar familiar',
                  onTap: () async {
                    onClose();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FamilyFormScreen()),
                    );
                  },
                ),
                _MenuButton(
                  text: 'Familiares Registrados',
                  onTap: () {
                    onClose();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FamilyListScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onClose,
              child: Container(color: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botones grandes del menú
class _MenuButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _MenuButton({
    super.key,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: kPrimaryBlue,
          border: Border.all(color: Colors.white, width: 2),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Avatar
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 60,
      backgroundColor: Colors.amber[400],
      child: const CircleAvatar(
        radius: 56,
        backgroundColor: Colors.white,
        child: Icon(Icons.person, size: 60, color: kPrimaryBlue),
      ),
    );
  }
}

/// Tarjeta de tratamiento
class TreatmentCard extends StatelessWidget {
  final String name;
  final String time;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TreatmentCard({
    super.key,
    required this.name,
    required this.time,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimaryBlue, width: 3),
        boxShadow: [
          BoxShadow(
            blurRadius: 4,
            offset: const Offset(0, 2),
            color: Colors.black.withOpacity(0.08),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.alarm, size: 18, color: kPrimaryBlue),
                    const SizedBox(width: 6),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit),
            color: kPrimaryBlue,
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete),
            color: kPrimaryBlue,
          ),
        ],
      ),
    );
  }
}

/// Barra inferior con botón +
class _BottomAddBar extends StatelessWidget {
  final VoidCallback onAdd;
  const _BottomAddBar({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      color: kPrimaryBlue,
      child: Center(
        child: GestureDetector(
          onTap: onAdd,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 40),
          ),
        ),
      ),
    );
  }
}
