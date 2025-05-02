import '../pages/pets_page.dart'; // importă clasa Pet

class PetModel {
  final String name;
  final String age;
  final String breed;
  final String gender;
  final String? history;

  PetModel({
    required this.name,
    required this.age,
    required this.breed,
    required this.gender,
    this.history,
  });

  factory PetModel.fromPet(Pet pet) {
    return PetModel(
      name: pet.name,
      age: _calculateAge(pet.birthDate),
      breed: pet.breed,
      gender: pet.sex,
      history: pet.medicalHistory.isNotEmpty ? pet.medicalHistory : pet.allergies,
    );
  }

  static String _calculateAge(String birthDateStr) {
    try {
      final birthDate = DateTime.parse(birthDateStr);
      final now = DateTime.now();
      final ageYears = now.year - birthDate.year - (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day) ? 1 : 0);
      return ageYears.toString();
    } catch (_) {
      return "Unknown";
    }
  }
}
