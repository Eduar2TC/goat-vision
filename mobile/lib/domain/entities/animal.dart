class Animal {
  final String id;
  final String name;
  final String? breed;
  final String? sex;
  final DateTime? birthDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Animal({
    required this.id,
    required this.name,
    this.breed,
    this.sex,
    this.birthDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Animal copyWith({
    String? id,
    String? name,
    String? breed,
    String? sex,
    DateTime? birthDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Animal(
      id: id ?? this.id,
      name: name ?? this.name,
      breed: breed ?? this.breed,
      sex: sex ?? this.sex,
      birthDate: birthDate ?? this.birthDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int? get ageMonths {
    if (birthDate == null) return null;
    final now = DateTime.now();
    return (now.year - birthDate!.year) * 12 + (now.month - birthDate!.month);
  }

  String? get ageDisplay {
    final months = ageMonths;
    if (months == null) return null;
    if (months < 12) return '$months meses';
    final years = months ~/ 12;
    final remMonths = months % 12;
    if (remMonths == 0) return '$years años';
    return '$years años, $remMonths meses';
  }
}
