// ================= MODEL =================
class Cat {
  final int id;
  final String name;
  final String? rfidTag;
  final String? sex; // 'Female' | 'Male' | null
  final DateTime? birthDate;
  final String? breed;
  final bool? isNeutered;
  final double? weightKg;
  final String? personality;
  final String? goals;

  const Cat({
    required this.id,
    required this.name,
    this.rfidTag,
    this.sex,
    this.birthDate,
    this.breed,
    this.isNeutered,
    this.weightKg,
    this.personality,
    this.goals,
  });

  factory Cat.fromJson(Map<String, dynamic> json) => Cat(
        id: json['id'] as int,
        name: (json['name'] as String?) ?? 'Mačka',
        rfidTag: json['rfidTag'] as String?,
        sex: json['sex'] as String?,
        birthDate: json['birthDate'] != null ? DateTime.tryParse(json['birthDate'].toString()) : null,
        breed: json['breed'] as String?,
        isNeutered: json['isNeutered'] as bool?,
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        personality: json['personality'] as String?,
        goals: json['goals'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'rfidTag': rfidTag,
        'sex': sex,
        'birthDate': birthDate?.toIso8601String(),
        'breed': breed,
        'isNeutered': isNeutered,
        'weightKg': weightKg,
        'personality': personality,
        'goals': goals,
      };

  // Ljudski čitljiv opis starosti, npr. "2 mjeseca" ili "1 godina i 3 mjeseca".
  String? get ageDescription {
    if (birthDate == null) return null;
    final now = DateTime.now();
    var months = (now.year - birthDate!.year) * 12 + (now.month - birthDate!.month);
    if (now.day < birthDate!.day) months--;
    if (months < 0) months = 0;
    if (months < 1) return 'Manje od mjesec dana';
    if (months < 12) return '$months ${months == 1 ? "mjesec" : "mjeseci"}';
    final years = months ~/ 12;
    final remMonths = months % 12;
    final yearsText = '$years ${years == 1 ? "godina" : "godine"}';
    if (remMonths == 0) return yearsText;
    return '$yearsText i $remMonths ${remMonths == 1 ? "mjesec" : "mjeseci"}';
  }
}
