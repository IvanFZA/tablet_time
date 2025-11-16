// db_helper.dart
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  static const String _dbName = 'meds_local.db';
  static const int _dbVersion = 1;

  static const String tableFamily = 'family';
  static const String tableTreatment = 'treatment';

  Database? _db;

  /// Obtiene (o crea) la instancia de la BD
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        // Por si en el futuro agregas FKs, lo dejamos activo (no afecta si no hay FK)
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableFamily (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT NOT NULL,
            email TEXT NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE $tableTreatment (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            med_name TEXT NOT NULL,
            dose TEXT NOT NULL,
            frequency TEXT NOT NULL,
            duration TEXT NOT NULL,
            hour TEXT
          );
        ''');

        // Índices útiles
        await db.execute('CREATE INDEX IF NOT EXISTS idx_family_name ON $tableFamily(name);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_treatment_med ON $tableTreatment(med_name);');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Aquí escribes migraciones cuando subas _dbVersion
        // Ejemplo:
        // if (oldVersion < 2) {
        //   await db.execute('ALTER TABLE $tableTreatment ADD COLUMN notes TEXT;');
        // }
      },
    );
  }

  // ===========================
  // FAMILY (Contactos)
  // ===========================
  Future<int> insertFamily(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert(tableFamily, data);
  }

  Future<List<Map<String, dynamic>>> getAllFamilies() async {
    final db = await database;
    return db.query(tableFamily, orderBy: 'name ASC');
  }

  Future<Map<String, dynamic>?> getFamilyById(int id) async {
    final db = await database;
    final rows = await db.query(tableFamily, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<int> updateFamily(int id, Map<String, dynamic> data) async {
    final db = await database;
    return db.update(tableFamily, data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteFamily(int id) async {
    final db = await database;
    return db.delete(tableFamily, where: 'id = ?', whereArgs: [id]);
  }

  // ===========================
  // TREATMENT (Tratamientos)
  // ===========================
  Future<int> insertTreatment(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert(tableTreatment, data);
  }

  Future<List<Map<String, dynamic>>> getAllTreatments() async {
    final db = await database;
    return db.query(tableTreatment, orderBy: 'id DESC');
  }

  Future<Map<String, dynamic>?> getTreatmentById(int id) async {
    final db = await database;
    final rows = await db.query(tableTreatment, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Modificar tratamiento por id (p.ej. dose, frequency, duration, hour)
  Future<int> updateTreatment(int id, Map<String, dynamic> data) async {
    final db = await database;
    return db.update(tableTreatment, data, where: 'id = ?', whereArgs: [id]);
  }

  /// Eliminar tratamiento por id
  Future<int> deleteTreatment(int id) async {
    final db = await database;
    return db.delete(tableTreatment, where: 'id = ?', whereArgs: [id]);
  }

  // ===========================
  // Utilidades (dev / debug)
  // ===========================
  Future<int> countFamilies() async {
    final db = await database;
    final res = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $tableFamily'))!;
    return res;
  }

  Future<int> countTreatments() async {
    final db = await database;
    final res = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $tableTreatment'))!;
    return res;
  }

  /// Borra el contenido de ambas tablas (útil en pruebas)
  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableTreatment);
      await txn.delete(tableFamily);
    });
  }

  /// Elimina el archivo de la BD (para reiniciar en desarrollo)
  Future<void> deleteDbFile() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    await deleteDatabase(path);
    _db = null; // fuerza re-inicialización en la próxima llamada
  }
}
