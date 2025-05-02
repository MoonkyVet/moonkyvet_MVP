// VET CARD — DOUĂ BUTOANE: SUNĂ ACUM / TRIMITE MESAJ
// (păstrăm Tinder style UI, înlocuim butonul cu două opțiuni)
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ConnectWithAVetPage extends StatefulWidget {
  const ConnectWithAVetPage({super.key});

  @override
  State<ConnectWithAVetPage> createState() => _ConnectWithAVetPageState();
}

class _ConnectWithAVetPageState extends State<ConnectWithAVetPage> {
  List<Map<String, dynamic>> nearbyVets = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadVets();
  }

  Future<void> loadVets() async {
    try {
      double? userLat;
      double? userLng;

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      if (!serviceEnabled || permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final address = userDoc.data()?['address'];
          if (address != null && address.toString().isNotEmpty) {
            final latLng = await getLatLngFromAddress(address);
            if (latLng != null) {
              userLat = latLng.latitude;
              userLng = latLng.longitude;
            }
          }
        }
      } else {
        final position = await Geolocator.getCurrentPosition();
        userLat = position.latitude;
        userLng = position.longitude;
      }

      if (userLat == null || userLng == null) {
        setState(() {
          loading = false;
          nearbyVets = [];
        });
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('vets')
          .where('status', isEqualTo: 'APPROVED')
          .where('vetAvailabilityNow', isEqualTo: true)
          .get();

      final vetDocs = snapshot.docs;

      final futures = vetDocs.map((doc) async {
        final vet = doc.data();
        final address = vet['address'];
        if (address == null) return null;

        final latLng = await getLatLngFromAddress(address);
        if (latLng == null) return null;

        final distance = Geolocator.distanceBetween(userLat!, userLng!, latLng.latitude, latLng.longitude);

        return { ...vet, 'distance': distance, 'id': doc.id };
      }).toList();

      final results = await Future.wait(futures);
      final filtered = results.whereType<Map<String, dynamic>>().toList();
      filtered.sort((a, b) {
        // Sort by availableNow (true first), then by distance, then by rating desc
        final ratingA = (a['rating'] ?? 0).toDouble();
        final ratingB = (b['rating'] ?? 0).toDouble();
        final distanceA = a['distance'];
        final distanceB = b['distance'];
        return distanceA.compareTo(distanceB) != 0
            ? distanceA.compareTo(distanceB)
            : ratingB.compareTo(ratingA);
      });

      setState(() {
        nearbyVets = filtered;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future<LatLng?> getLatLngFromAddress(String address) async {
    const apiKey = 'AIzaSyDGOs5SQxeY3rHvkJgdUE-R8Ip5rApwk-4';
    final sanitized = address.replaceAll('ă', 'a').replaceAll('â', 'a').replaceAll('î', 'i').replaceAll('ș', 's').replaceAll('ț', 't');
    final url = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(sanitized)}&key=$apiKey');

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final location = data['results'][0]['geometry']['location'];
        return LatLng(location['lat'], location['lng']);
      }
    }
    return null;
  }

  void _showVetInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Center(child: Icon(Icons.info_outline, color: Colors.white, size: 36)),
              SizedBox(height: 12),
              Text(
                'Despre această pagină',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(height: 10),
              Text(
                'Veterinarii de aici sunt profesioniști reali, verificați manual de echipa Moonky. '
                    'Poți să le trimiți mesaje sau să inițiezi un apel video, dacă sunt disponibili, iar acestia, cu siguranta, iti vor ajuta animalutul.',
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          padding: const EdgeInsets.only(top: 40, left: 12, right: 12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 24),
                onPressed: () => Navigator.pop(context),
              ),
              const Text(
                'Vorbeste cu un veterinar',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.white, size: 24),
                onPressed: _showVetInfo,
                tooltip: 'Despre această pagină',
              ),
            ],
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : nearbyVets.isEmpty
          ? const Center(child: Text('No vets nearby.', style: TextStyle(color: Colors.white70)))
          : ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: nearbyVets.length,
        itemBuilder: (context, index) {
          final vet = nearbyVets[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Stack(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.75,
                    width: double.infinity,
                    child: vet['profileImage'] != null
                        ? Image.network(vet['profileImage'], fit: BoxFit.cover)
                        : Container(color: Colors.grey.shade800),
                  ),
                  Container(
                    height: MediaQuery.of(context).size.height * 0.75,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Dr. ${vet['name']}',
                                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                              if (vet['vetAvailabilityNow'] == true)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.4),
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(color: Colors.greenAccent.withOpacity(0.6)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.circle, size: 10, color: Colors.greenAccent),
                                          SizedBox(width: 6),
                                          Text('Disponibil acum', style: TextStyle(color: Colors.white, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${(vet['distance'] / 1000).toStringAsFixed(1)} km • ${vet['address'] ?? ''}',
                              style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 8),
                          labelText("Specializări"),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: List.generate(
                              (vet['expertise'] as List<dynamic>?)?.length ?? 0,
                                  (i) => Chip(
                                label: Text(vet['expertise'][i]),
                                labelStyle: const TextStyle(color: Colors.white, fontSize: 13),
                                backgroundColor: Colors.teal.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // labelText("Animale tratate"),
                          // Text((vet['animals'] as List<dynamic>).join(', '),
                          //     style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 8),
                          labelText("Experiență"),
                          infoRow(Icons.work_outline, '${vet['experience']} ani'),
                          labelText("Preț consultație"),
                          infoRow(Icons.monetization_on, '${vet['price']} lei'),
                          labelText("Rating"),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amberAccent, size: 20),
                              const SizedBox(width: 6),
                              Text('${vet['rating'] ?? 0.0} / 5.0', style: const TextStyle(color: Colors.white70)),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    // TODO: integrare call
                                  },
                                  icon: const Icon(Icons.phone),
                                  label: const Text('Sună acum'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    // TODO: trimite mesaj
                                  },
                                  icon: const Icon(Icons.chat),
                                  label: const Text('Trimite mesaj'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black87,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget labelText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class LatLng {
  final double latitude;
  final double longitude;
  LatLng(this.latitude, this.longitude);
}