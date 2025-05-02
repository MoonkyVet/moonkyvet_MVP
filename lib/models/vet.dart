class Vet {
  final String uid;
  final String name;
  final String email;
  final List<String> specializations;
  final double videoCallRate;
  final double textConsultRate;
  final bool isAvailableNow;
  final Map<String, List<String>> availableHoursThisWeek;
  final int consultations;
  final double rating;
  final int ratingsCount;
  final bool doNotDisturb;
  final bool isOnline;

  Vet({
    required this.uid,
    required this.name,
    required this.email,
    required this.specializations,
    required this.videoCallRate,
    required this.textConsultRate,
    required this.isAvailableNow,
    required this.availableHoursThisWeek,
    required this.consultations,
    required this.rating,
    required this.ratingsCount,
    required this.doNotDisturb,
    required this.isOnline,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'name': name,
    'email': email,
    'specializations': specializations,
    'videoCallRate': videoCallRate,
    'textConsultRate': textConsultRate,
    'isAvailableNow': isAvailableNow,
    'availableHoursThisWeek': availableHoursThisWeek,
    'consultations': consultations,
    'rating': rating,
    'ratingsCount': ratingsCount,
    'doNotDisturb': doNotDisturb,
    'isOnline': isOnline,
  };

  factory Vet.fromMap(Map<String, dynamic> map) => Vet(
    uid: map['uid'],
    name: map['name'],
    email: map['email'],
    specializations: List<String>.from(map['specializations']),
    videoCallRate: (map['videoCallRate'] ?? 0).toDouble(),
    textConsultRate: (map['textConsultRate'] ?? 0).toDouble(),
    isAvailableNow: map['isAvailableNow'] ?? false,
    availableHoursThisWeek: Map<String, List<String>>.from(map['availableHoursThisWeek'] ?? {}),
    consultations: map['consultations'] ?? 0,
    rating: (map['rating'] ?? 0).toDouble(),
    ratingsCount: map['ratingsCount'] ?? 0,
    doNotDisturb: map['doNotDisturb'] ?? false,
    isOnline: map['isOnline'] ?? false,
  );
}
