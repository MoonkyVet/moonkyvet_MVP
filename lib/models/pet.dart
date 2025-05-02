// === models/pet.dart ===

class Pet {
  final String id;
  final String name;
  final String breed;
  final String sex;
  final String birthDate;
  final double weight;
  final bool neutered;
  final String allergies;
  final String photoUrl;
  final List<String> medicalRecordUrls;
  final String medicalRecordText;
  final String microchipNumber;
  final String microchipLocation;
  final String otherDetails;

  Pet({
    required this.id,
    required this.name,
    required this.breed,
    required this.sex,
    required this.birthDate,
    required this.weight,
    required this.neutered,
    required this.allergies,
    required this.photoUrl,
    required this.medicalRecordUrls,
    required this.medicalRecordText,
    required this.microchipNumber,
    required this.microchipLocation,
    required this.otherDetails,
  });

  factory Pet.fromMap(Map<String, dynamic> map) {
    return Pet(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      breed: map['breed'] ?? '',
      sex: map['sex'] ?? '',
      birthDate: map['birthDate'] ?? '',
      weight: (map['weight'] ?? 0).toDouble(),
      neutered: map['neutered'] ?? false,
      allergies: map['allergies'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      medicalRecordUrls: List<String>.from(map['medicalRecordUrls'] ?? []),
      medicalRecordText: map['medicalRecordText'] ?? '',
      microchipNumber: map['microchipNumber'] ?? '',
      microchipLocation: map['microchipLocation'] ?? '',
      otherDetails: map['otherDetails'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'breed': breed,
      'sex': sex,
      'birthDate': birthDate,
      'weight': weight,
      'neutered': neutered,
      'allergies': allergies,
      'photoUrl': photoUrl,
      'medicalRecordUrls': medicalRecordUrls,
      'medicalRecordText': medicalRecordText,
      'microchipNumber': microchipNumber,
      'microchipLocation': microchipLocation,
      'otherDetails': otherDetails,
    };
  }

  Pet copyWith({
    String? name,
    String? breed,
    String? sex,
    String? birthDate,
    double? weight,
    bool? neutered,
    String? allergies,
    String? photoUrl,
    List<String>? medicalRecordUrls,
    String? medicalRecordText,
    String? microchipNumber,
    String? microchipLocation,
    String? otherDetails,
  }) {
    return Pet(
      id: id,
      name: name ?? this.name,
      breed: breed ?? this.breed,
      sex: sex ?? this.sex,
      birthDate: birthDate ?? this.birthDate,
      weight: weight ?? this.weight,
      neutered: neutered ?? this.neutered,
      allergies: allergies ?? this.allergies,
      photoUrl: photoUrl ?? this.photoUrl,
      medicalRecordUrls: medicalRecordUrls ?? this.medicalRecordUrls,
      medicalRecordText: medicalRecordText ?? this.medicalRecordText,
      microchipNumber: microchipNumber ?? this.microchipNumber,
      microchipLocation: microchipLocation ?? this.microchipLocation,
      otherDetails: otherDetails ?? this.otherDetails,
    );
  }
}
