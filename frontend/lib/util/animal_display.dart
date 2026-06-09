// Species display helpers shared by the animal screens.

const List<List<String>> speciesChoices = [
  ['chicken', 'Chicken'],
  ['duck', 'Duck'],
  ['goose', 'Goose'],
  ['turkey', 'Turkey'],
  ['goat', 'Goat'],
  ['sheep', 'Sheep'],
  ['pig', 'Pig'],
  ['cow', 'Cow'],
  ['horse', 'Horse'],
  ['rabbit', 'Rabbit'],
  ['tortoise', 'Tortoise'],
  ['dog', 'Dog'],
  ['cat', 'Cat'],
  ['bees', 'Bee colony'],
  ['other', 'Other'],
];

const Map<String, String> speciesEmoji = {
  'chicken': '🐔',
  'duck': '🦆',
  'goose': '🦢',
  'turkey': '🦃',
  'goat': '🐐',
  'sheep': '🐑',
  'pig': '🐷',
  'cow': '🐄',
  'horse': '🐴',
  'rabbit': '🐰',
  'tortoise': '🐢',
  'dog': '🐕',
  'cat': '🐈',
  'bees': '🐝',
  'other': '🐾',
};

/// Age from date of birth, e.g. "2 yr 3 mo" / "5 mo". Null if unknown.
String? ageLabel(DateTime? dob) {
  if (dob == null) return null;
  final now = DateTime.now();
  int months = (now.year - dob.year) * 12 + (now.month - dob.month);
  if (now.day < dob.day) months -= 1;
  if (months < 0) return null;
  final years = months ~/ 12;
  final rem = months % 12;
  if (years == 0) return '$months mo';
  if (rem == 0) return '$years yr';
  return '$years yr $rem mo';
}
