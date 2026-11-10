/// Stable IDs are saved with companions. Changing a design never changes its ID.
class AnimalDesign {
  const AnimalDesign(
      this.id, this.label, this.description, this.color, this.accent);
  final String id, label, description;
  final int color, accent;
}

const animalDesigns = [
  AnimalDesign(
      'cat', 'Cat', 'Striped cheeks & a curling tail', 0xFFD99458, 0xFFFFE4BB),
  AnimalDesign(
      'dog', 'Dog', 'Floppy ears & a happy wag', 0xFFB88C67, 0xFFF1DCC0),
  AnimalDesign(
      'bunny', 'Bunny', 'Tall ears & a little hop', 0xFFB6C4BC, 0xFFE6C2CB),
  AnimalDesign('fox', 'Fox', 'Pointed ears & a cream-tipped tail', 0xFFC47743,
      0xFFFFE4BB),
  AnimalDesign('bear', 'Bear', 'Round ears & honey-colored paws', 0xFF997052,
      0xFFE9C999),
  AnimalDesign(
      'panda', 'Panda', 'Eye patches & tiny dark paws', 0xFFE8E5DA, 0xFF53616B),
  AnimalDesign(
      'frog', 'Frog', 'Bright eyes & springy feet', 0xFF7FAD71, 0xFFDCE6A3),
  AnimalDesign('penguin', 'Penguin', 'A snowy belly & a little waddle',
      0xFF586D82, 0xFFF4EEDC),
  AnimalDesign(
      'owl', 'Owl', 'Feather tufts & speckled wings', 0xFFA18A72, 0xFFF1DBB4),
  AnimalDesign('monkey', 'Monkey', 'Round ears & a playful curling tail',
      0xFFA57550, 0xFFF0D4A0),
  AnimalDesign('turtle', 'Turtle', 'A patterned shell & a gentle stroll',
      0xFF80A58A, 0xFFDBCB8D),
];

AnimalDesign animalDesign(String id) => animalDesigns
    .firstWhere((a) => a.id == id, orElse: () => animalDesigns.first);
