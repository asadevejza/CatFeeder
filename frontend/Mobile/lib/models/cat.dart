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

  factory Cat.fromJson(Map<String, dynamic> json) {
    dynamic v(String key) => json[key] ?? json[key[0].toUpperCase() + key.substring(1)];
    return Cat(
      id: (v('id') as num).toInt(),
      name: v('name')?.toString() ?? 'Mačka',
      rfidTag: v('rfidTag')?.toString(),
      sex: v('sex')?.toString(),
      birthDate: v('birthDate') != null ? DateTime.tryParse(v('birthDate').toString()) : null,
      breed: v('breed')?.toString(),
      isNeutered: v('isNeutered') as bool?,
      weightKg: (v('weightKg') as num?)?.toDouble(),
      personality: v('personality')?.toString(),
      goals: v('goals')?.toString(),
    );
  }

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
