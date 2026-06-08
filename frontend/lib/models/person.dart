class Person {
  final int id;
  final String name;

  Person({required this.id, required this.name});

  factory Person.fromJson(Map<String, dynamic> json) => Person(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
      );

  // Identity by id so DropdownButtonFormField can match the selected value.
  @override
  bool operator ==(Object other) => other is Person && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}
