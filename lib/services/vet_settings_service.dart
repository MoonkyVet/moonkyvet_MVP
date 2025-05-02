import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:moonkyvet/models/time_of_day_range.dart';


class VetSettingsService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<DocumentReference<Map<String, dynamic>>> _vetDocRef() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    return _firestore.collection('vets').doc(user.uid);
  }

  Future<Map<String, dynamic>?> loadVetSettings() async {
    final ref = await _vetDocRef();
    final doc = await ref.get();
    return doc.data();
  }

  Future<void> saveVetSettings({
    required bool vetAvailabilityNow,
    required double videoRate,
    required double messageRate,
    required Map<String, TimeOfDayRange?> availability,
    required BuildContext context,
  }) async {
    final ref = await _vetDocRef();

    final availabilityFormatted = availability.map((key, range) {
      if (range != null) {
        return MapEntry(key.toLowerCase(), [
          {
            'start': range.start.format(context),
            'end': range.end.format(context),
          }
        ]);
      } else {
        return MapEntry(key.toLowerCase(), []);
      }
    });

    await ref.update({
      'vetAvailabilityNow': vetAvailabilityNow,
      'videoRate': videoRate,
      'messageRate': messageRate,
      'availability': availabilityFormatted,
    });
  }

  /// Helper pentru a converti "09:30" în TimeOfDay
  TimeOfDay parseTimeOfDay(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  /// Reconstruiește disponibilitatea din Firestore
  Map<String, TimeOfDayRange?> parseAvailability(Map<String, dynamic>? availabilityRaw) {
    final Map<String, TimeOfDayRange?> result = {};
    if (availabilityRaw == null) return result;

    availabilityRaw.forEach((key, value) {
      if (value is List && value.isNotEmpty) {
        final startStr = value[0]['start'];
        final endStr = value[0]['end'];
        result[key[0].toUpperCase() + key.substring(1)] = TimeOfDayRange(
          start: parseTimeOfDay(startStr),
          end: parseTimeOfDay(endStr),
        );
      }
    });

    return result;
  }
}


