// models.dart
class Family {
  final int? id;
  final String name;
  final String phone;
  final String email;

  Family({this.id, required this.name, required this.phone, required this.email});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
      };

  factory Family.fromMap(Map<String, dynamic> m) => Family(
        id: m['id'] as int?,
        name: m['name'] as String,
        phone: m['phone'] as String,
        email: m['email'] as String,
      );
}

class Treatment {
  final int? id;
  final String medName;
  final String dose;
  final String frequency;
  final String duration;
  final String? hour;

  Treatment({
    this.id,
    required this.medName,
    required this.dose,
    required this.frequency,
    required this.duration,
    this.hour,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'med_name': medName,
        'dose': dose,
        'frequency': frequency,
        'duration': duration,
        'hour': hour,
      };

  factory Treatment.fromMap(Map<String, dynamic> m) => Treatment(
        id: m['id'] as int?,
        medName: m['med_name'] as String,
        dose: m['dose'] as String,
        frequency: m['frequency'] as String,
        duration: m['duration'] as String,
        hour: m['hour'] as String?,
      );
}
