import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:google_maps_webservice/places.dart' as places;
import 'package:url_launcher/url_launcher.dart';

class FindVetsByProfilePage extends StatefulWidget {
  const FindVetsByProfilePage({super.key});

  @override
  State<FindVetsByProfilePage> createState() => _FindVetsByProfilePageState();
}

class VetClinic {
  final places.PlacesSearchResult vet;
  final String? phoneNumber;

  VetClinic({required this.vet, this.phoneNumber});
}

class _FindVetsByProfilePageState extends State<FindVetsByProfilePage> {
  String? currentAddress;
  LatLng? currentLocation;
  late GoogleMapController mapController;
  Set<Marker> markers = {};
  List<VetClinic> vetClinics = [];
  bool loading = true;

  final places.GoogleMapsPlaces placesApi = places.GoogleMapsPlaces(
    apiKey: 'AIzaSyDGOs5SQxeY3rHvkJgdUE-R8Ip5rApwk-4',
  );

  @override
  void initState() {
    super.initState();
    _loadAddressFromProfile();
  }

  Future<void> _loadAddressFromProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    if (data != null && data['address'] != null && data['address'].toString().isNotEmpty) {
      currentAddress = data['address'];
      _fetchCoordinates(currentAddress!);
    } else {
      setState(() => loading = false);
      _showMissingAddressDialog();
    }
  }

  void _showMissingAddressDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Missing Address'),
        content: const Text('No address found in your profile. Please update your profile to use this feature.'),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<String?> getVetPhoneNumber(String placeId) async {
    final details = await placesApi.getDetailsByPlaceId(placeId);
    if (details.status == 'OK') {
      return details.result.formattedPhoneNumber;
    }
    return null;
  }

  Future<void> _fetchCoordinates(String address) async {
    final locations = await geocoding.locationFromAddress(address);
    if (locations.isNotEmpty) {
      final loc = locations.first;
      final center = LatLng(loc.latitude, loc.longitude);
      _fetchNearbyVets(center);
    }
  }

  Future<void> _fetchNearbyVets(LatLng location) async {
    setState(() => loading = true);
    final response = await placesApi.searchNearbyWithRadius(
      places.Location(lat: location.latitude, lng: location.longitude),
      3000,
      type: 'veterinary_care',
    );

    if (response.status == 'OK') {
      final vets = response.results;
      final enriched = await Future.wait(vets.map((v) async {
        final phone = await getVetPhoneNumber(v.placeId);
        return VetClinic(vet: v, phoneNumber: phone);
      }));

      final userMarker = await _buildUserMarker(location);

      setState(() {
        currentLocation = location;
        vetClinics = enriched;
        markers = {
          userMarker,
          ...vets.map((v) => Marker(
            markerId: MarkerId(v.placeId),
            position: LatLng(v.geometry!.location.lat, v.geometry!.location.lng),
            onTap: () => _showVetModal(v.placeId),
          )),
        };
        loading = false;
      });
    }
  }

  Future<Marker> _buildUserMarker(LatLng location) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Marker(markerId: const MarkerId('user'));

    final petsSnapshot = await FirebaseFirestore.instance
        .collection('pets')
        .where('userId', isEqualTo: uid)
        .get();

    String? photoUrl;
    if (petsSnapshot.docs.isNotEmpty) {
      for (final doc in petsSnapshot.docs) {
        final url = doc.data()['photoUrl'] as String?;
        if (url != null && url.isNotEmpty) {
          photoUrl = url;
          break;
        }
      }
    }

    final BitmapDescriptor icon;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      icon = await _createRoundedMarkerWithImage(photoUrl);
    } else {
      icon = await _createMarkerWithText("YOU");
    }

    return Marker(
      markerId: const MarkerId('user'),
      position: location,
      icon: icon,
      infoWindow: const InfoWindow(title: 'You are here'),
    );
  }

  Future<BitmapDescriptor> _createRoundedMarkerWithImage(String imageUrl) async {
    final completer = Completer<ui.Image>();
    final imageStream = NetworkImage(imageUrl).resolve(const ImageConfiguration());
    imageStream.addListener(ImageStreamListener((info, _) => completer.complete(info.image)));
    final ui.Image image = await completer.future;

    const double size = 120;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();
    final clipPath = Path()
      ..addOval(Rect.fromCircle(center: Offset(size / 2, size / 2), radius: size / 2));
    canvas.clipPath(clipPath);
    paint.isAntiAlias = true;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, size, size),
      paint,
    );

    final picture = recorder.endRecording();
    final ui.Image markerAsImage = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List uint8List = byteData!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(uint8List);
  }

  Future<BitmapDescriptor> _createMarkerWithText(String text) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint()..color = const Color(0xFF0088FF);
    const double size = 120;

    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 30, color: Colors.white, fontWeight: FontWeight.bold),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size / 2 - textPainter.width / 2, size / 2 - textPainter.height / 2));

    final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(bytes);
  }

  Future<void> _showVetModal(String placeId) async {
    final details = await placesApi.getDetailsByPlaceId(placeId);
    if (details.status != 'OK') return;

    final vet = details.result;
    final phone = vet.formattedPhoneNumber;
    final photos = vet.photos;
    final hours = vet.openingHours?.weekdayText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black.withOpacity(0.85),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (photos != null && photos.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: PageView.builder(
                    itemCount: photos.length > 4 ? 4 : photos.length,
                    itemBuilder: (_, i) {
                      final url = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=600&photoreference=${photos[i].photoReference}&key=AIzaSyDGOs5SQxeY3rHvkJgdUE-R8Ip5rApwk-4';
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(url, fit: BoxFit.cover),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Text(vet.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(vet.formattedAddress ?? '', style: const TextStyle(color: Colors.white70)),
              if (vet.rating != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      Text('${vet.rating}', style: const TextStyle(color: Colors.white))
                    ],
                  ),
                ),
              if (hours != null && hours.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text("Opening Hours:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                for (final h in hours) Text(h, style: const TextStyle(color: Colors.white70)),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (phone != null)
                    IconButton(
                      icon: const Icon(Icons.phone, color: Colors.white),
                      onPressed: () async {
                        final telUrl = 'tel:$phone';
                        if (await canLaunchUrl(Uri.parse(telUrl))) {
                          await launchUrl(Uri.parse(telUrl));
                        }
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.directions, color: Colors.white),
                    onPressed: () async {
                      final url = 'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(vet.name)}';
                      if (await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(Uri.parse(url));
                      }
                    },
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.9),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vets by Profile Address', style: TextStyle(color: Colors.white)),
            if (currentAddress != null)
              Text(currentAddress!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: currentLocation ?? const LatLng(45.75, 21.22),
              zoom: 14,
            ),
            markers: markers,
            onMapCreated: (controller) => mapController = controller,
          ),
          if (vetClinics.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
                  itemCount: vetClinics.length,
                  itemBuilder: (_, i) {
                    final vet = vetClinics[i].vet;
                    final rating = vet.rating;
                    final phone = vetClinics[i].phoneNumber;

                    return Container(
                      width: 300,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(vet.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(vet.vicinity ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          if (rating != null)
                            Row(children: [
                              const Icon(Icons.star, size: 16, color: Colors.amber),
                              Text(rating.toString(), style: const TextStyle(fontSize: 12, color: Colors.white))
                            ]),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (phone != null)
                                IconButton(
                                  icon: const Icon(Icons.phone, color: Colors.white),
                                  onPressed: () async {
                                    final telUrl = 'tel:$phone';
                                    if (await canLaunchUrl(Uri.parse(telUrl))) {
                                      await launchUrl(Uri.parse(telUrl));
                                    }
                                  },
                                ),
                              TextButton.icon(
                                icon: const Icon(Icons.info_outline, color: Colors.white),
                                label: const Text("Details", style: TextStyle(color: Colors.white)),
                                onPressed: () => _showVetModal(vet.placeId),
                              )
                            ],
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}