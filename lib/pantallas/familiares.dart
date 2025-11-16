import 'package:flutter/material.dart';
import 'package:tablet_time/db_helper.dart';
import 'package:tablet_time/models.dart';

const Color kPrimaryBlue = Color(0xFF0F7CC9);
const Color kLightBackground = Color(0xFFE4F3FF);

class FamilyListScreen extends StatefulWidget {
  const FamilyListScreen({super.key});

  @override
  State<FamilyListScreen> createState() => _FamilyListScreenState();
}

class _FamilyListScreenState extends State<FamilyListScreen> {
  late Future<List<Family>> _futureFamilies;

  Future<List<Family>> _fetchFamilies() async {
    final rows = await AppDb.instance.getAllFamilies();
    return rows.map((m) => Family.fromMap(m)).toList();
  }

  @override
  void initState() {
    super.initState();
    _futureFamilies = _fetchFamilies();
  }

  Future<void> _reload() async {
    setState(() {
      _futureFamilies = _fetchFamilies();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior
            Container(height: 60, color: kPrimaryBlue),

            // Contenido
            Expanded(
              child: FutureBuilder<List<Family>>(
                future: _futureFamilies,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Error al cargar: ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final items = snapshot.data ?? [];

                  return RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text(
                            'Familiares registrados',
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: kPrimaryBlue,
                            ),
                          ),
                        ),

                        if (items.isEmpty) ...[
                          const SizedBox(height: 40),
                          Column(
                            children: const [
                              Icon(Icons.group_outlined,
                                  size: 62, color: kPrimaryBlue),
                              SizedBox(height: 12),
                              Text(
                                'No hay familiares registrados',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          for (final f in items) _FamilyCard(family: f),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // Botón regresar
            Container(
              color: kLightBackground,
              padding: const EdgeInsets.only(bottom: 16),
              child: Center(
                child: SizedBox(
                  width: 220,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: const Text(
                      'Regresar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
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

class _FamilyCard extends StatelessWidget {
  final Family family;
  const _FamilyCard({required this.family});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kPrimaryBlue, width: 4),
        boxShadow: [
          BoxShadow(
            blurRadius: 4,
            offset: const Offset(0, 2),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            family.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(family.phone, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 2),
          Text(family.email, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
