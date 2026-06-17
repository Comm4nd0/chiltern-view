class Animal {
  final int id;
  final String name;
  final String species;
  final String speciesDisplay;
  final String breed;
  final DateTime? dateOfBirth;
  final bool active;
  final String? photo;

  Animal({
    required this.id,
    required this.name,
    required this.species,
    required this.speciesDisplay,
    required this.breed,
    this.dateOfBirth,
    this.active = true,
    this.photo,
  });

  factory Animal.fromJson(Map<String, dynamic> json) {
    final dob = json['date_of_birth'] as String?;
    return Animal(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      species: json['species'] as String? ?? '',
      speciesDisplay: json['species_display'] as String? ?? '',
      breed: json['breed'] as String? ?? '',
      dateOfBirth: (dob == null || dob.isEmpty) ? null : DateTime.tryParse(dob),
      active: json['active'] as bool? ?? true,
      photo: json['photo'] as String?,
    );
  }

  @override
  String toString() => name;
}
