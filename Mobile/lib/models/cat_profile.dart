// ================= LOKALNI PROFIL MAČKE =================
// Podaci koje backend (CatFeeder.Api) trenutno ne čuva (spol, rasa, godine,
// težina). Drže se lokalno na telefonu, isto kao i slika mačke.
class CatProfile {
  final String gender; // 'Mužjak' ili 'Ženka'
  final String breed;
  final int ageYears;
  final double weightKg;

  const CatProfile({
    required this.gender,
    required this.breed,
    required this.ageYears,
    required this.weightKg,
  });

  Map<String, dynamic> toJson() => {
        'gender': gender,
        'breed': breed,
        'ageYears': ageYears,
        'weightKg': weightKg,
      };

  factory CatProfile.fromJson(Map<String, dynamic> json) => CatProfile(
        gender: json['gender'] as String? ?? 'Mužjak',
        breed: json['breed'] as String? ?? '',
        ageYears: (json['ageYears'] as num?)?.toInt() ?? 0,
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0.0,
      );

  CatProfile copyWith({String? gender, String? breed, int? ageYears, double? weightKg}) => CatProfile(
        gender: gender ?? this.gender,
        breed: breed ?? this.breed,
        ageYears: ageYears ?? this.ageYears,
        weightKg: weightKg ?? this.weightKg,
      );
}
