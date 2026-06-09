class Animal {
  final int id;
  final String name;
  final String species;
  final String speciesDisplay;
  final String breed;

  Animal({
    required this.id,
    required this.name,
    required this.species,
    required this.speciesDisplay,
    required this.breed,
  });

  factory Animal.fromJson(Map<String, dynamic> json) => Animal(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        species: json['species'] as String? ?? '',
        speciesDisplay: json['species_display'] as String? ?? '',
        breed: json['breed'] as String? ?? '',
      );

  @override
  String toString() => name;
}
