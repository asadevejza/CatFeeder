// ================= MODEL =================
class Cat {
  final int id;
  final String name;
  const Cat({required this.id, required this.name});

  factory Cat.fromJson(Map<String, dynamic> json) =>
      Cat(id: json['id'] as int, name: (json['name'] as String?) ?? 'Mačka');
}
