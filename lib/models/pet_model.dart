import 'pet.dart';

class PetModel {
  final String id;
  final String name;
  final String breed;
  final String sex;
  final String birthDate;
  final double weight;
  final bool neutered;
  final String allergies;
  final String microchipNumber;
  final String microchipLocation;
  final String photoUrl;
  final List<String> medicalRecordUrls;
  final String medicalRecordText;
  final String otherDetails;

  PetModel({
    required this.id,
    required this.name,
    required this.breed,
    required this.sex,
    required this.birthDate,
    required this.weight,
    required this.neutered,
    required this.allergies,
    required this.microchipNumber,
    required this.microchipLocation,
    required this.photoUrl,
    required this.medicalRecordUrls,
    required this.medicalRecordText,
    required this.otherDetails,
  });

  factory PetModel.fromPet(Pet pet) {
    return PetModel(
      id: pet.id,
      name: pet.name,
      breed: pet.breed,
      sex: pet.sex,
      birthDate: pet.birthDate,
      weight: pet.weight,
      neutered: pet.neutered,
      allergies: pet.allergies,
      microchipNumber: pet.microchipNumber,
      microchipLocation: pet.microchipLocation,
      photoUrl: pet.photoUrl,
      medicalRecordUrls: pet.medicalRecordUrls,
      medicalRecordText: pet.medicalRecordText,
      otherDetails: pet.otherDetails,
    );
  }

  String get age {
    if (birthDate.isEmpty) return "Necunoscut";
    try {
      final birth = DateTime.parse(birthDate);
      final now = DateTime.now();
      int years = now.year - birth.year;
      if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) {
        years--;
      }
      return years > 0 ? "$years ani" : "Mai puțin de 1 an";
    } catch (_) {
      return "Necunoscut";
    }
  }

  String get gender => sex;

  String? get history => allergies.isNotEmpty ? allergies : null;
}
