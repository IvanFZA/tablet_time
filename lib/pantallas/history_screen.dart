import 'package:flutter/material.dart';
import '../db_helper.dart';

const Color kPrimaryBlue = Color(0xFF0F7CC9);
const Color kLightBackground = Color(0xFFE4F3FF);

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> history = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();

    // SOLO PARA PRUEBA (quítalo después)
    // AppDb.instance.insertFakeHistory();

    loadHistory();
  }

  Future<void> loadHistory() async {
    final data = await AppDb.instance.getHistory();

    setState(() {
      history = data;
      loading = false;
    });
  }

  Color getColor(String action) {
    return action == 'taken' ? Colors.green : Colors.orange;
  }

  String getText(String action) {
    return action == 'taken' ? 'Tomado' : 'Pospuesto';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightBackground,
      body: SafeArea(
        child: Column(
          children: [
            //  HEADER
            Container(
              height: 80,
              width: double.infinity,
              color: kPrimaryBlue,
              alignment: Alignment.center,
              child: const Text(
                'Historial de medicamentos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : history.isEmpty
                  ? _emptyState()
                  : _historyList(),
            ),

            //  BOTÓN REGRESAR
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Regresar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //  PANTALLA VACÍA
  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.history, size: 90, color: kPrimaryBlue),
          SizedBox(height: 20),
          Text(
            'No hay historial aún',
            style: TextStyle(fontSize: 18, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  //  LISTA DE HISTORIAL
  Widget _historyList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final item = history[index];

        final date = DateTime.parse(item['date']).toLocal();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // ICONO
              CircleAvatar(
                backgroundColor: getColor(item['action']).withOpacity(0.2),
                child: Icon(
                  item['action'] == 'taken' ? Icons.check : Icons.snooze,
                  color: getColor(item['action']),
                ),
              ),

              const SizedBox(width: 12),

              // TEXTO
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['med_name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${date.day}/${date.month} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),

              // ESTADO
              Text(
                getText(item['action']),
                style: TextStyle(
                  color: getColor(item['action']),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
