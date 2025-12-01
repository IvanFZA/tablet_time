// lib/models.dart

/// Modelo para la tabla FAMILY
class Family {
  final int? id;
  final String name;
  final String phone;
  final String email;

  Family({
    this.id,
    required this.name,
    required this.phone,
    required this.email,
  });

  factory Family.fromMap(Map<String, dynamic> map) {
    return Family(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String,
      email: map['email'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'phone': phone,
      'email': email,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }
}

/// Modelo para la tabla TREATMENT
class Treatment {
  final int? id;
  final String medName;
  final String dose;      // NOT NULL en BD
  final String frequency; // NOT NULL en BD (ej. "Cada 8 horas")
  final String duration;  // NOT NULL en BD (ej. "7 días")
  final String? hour;     // puede ser null (HH:mm)

  Treatment({
    this.id,
    required this.medName,
    required this.dose,
    required this.frequency,
    required this.duration,
    this.hour,
  });

  factory Treatment.fromMap(Map<String, dynamic> map) {
    return Treatment(
      id: map['id'] as int?,
      medName: map['med_name'] as String,
      dose: map['dose'] as String,
      frequency: map['frequency'] as String,
      duration: map['duration'] as String,
      hour: map['hour'] as String?, // puede venir null
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'med_name': medName,
      'dose': dose,
      'frequency': frequency,
      'duration': duration,
      'hour': hour,
    };

    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  /// Opcional: para copiar con cambios (útil en futuras mejoras)
  Treatment copyWith({
    int? id,
    String? medName,
    String? dose,
    String? frequency,
    String? duration,
    String? hour,
  }) {
    return Treatment(
      id: id ?? this.id,
      medName: medName ?? this.medName,
      dose: dose ?? this.dose,
      frequency: frequency ?? this.frequency,
      duration: duration ?? this.duration,
      hour: hour ?? this.hour,
    );
  }
}
