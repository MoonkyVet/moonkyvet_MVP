import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:google_maps_webservice/places.dart' as places;
import 'package:url_launcher/url_launcher.dart';

class FindVetsPage extends StatefulWidget {
  final String? address;

  const FindVetsPage({Key? key, this.address}) : super(key: key);

  @override
  State<FindVetsPage> createState() => _FindVetsPageState();
}

class VetClinic {
  final places.PlacesSearchResult vet;
  final String? phoneNumber;

  VetClinic({required this.vet, this.phoneNumber});
}

class _FindVetsPageState extends State<FindVetsPage> {
  final TextEditingController _addressController = TextEditingController();
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
    if (widget.address != null && widget.address!.isNotEmpty) {
      currentAddress = widget.address;
      _fetchCoordinates(widget.address!);
    } else {
      _handleLocationOrManual();
    }
  }

  Future<void> _handleLocationOrManual() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();

    if (!serviceEnabled || (permission == LocationPermission.denied && await Geolocator.requestPermission() == LocationPermission.denied)) {
      _showAddressInput();
    } else {
      final position = await Geolocator.getCurrentPosition();
      currentLocation = LatLng(position.latitude, position.longitude);
      _fetchNearbyVets(currentLocation!);
    }
  }

  void _showAddressInput() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Enter your address"),
        content: TextField(
          controller: _addressController,
          decoration: const InputDecoration(hintText: "Your address"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (_addressController.text.isNotEmpty) {
                currentAddress = _addressController.text;
                _fetchCoordinates(currentAddress!);
              }
            },
            child: const Text("Continue"),
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

      if (vets.isEmpty) {
        // Dacă nu s-au găsit cabinete, adaugă un marker pe locația curentă
        setState(() {
          currentLocation = location;
          markers = {
            Marker(
              markerId: const MarkerId("currentLocation"),
              position: location,
              infoWindow: const InfoWindow(title: "Your location"),
            )
          };
          vetClinics = [];
          loading = false;
        });

        // Mută camera spre locația curentă
        mapController.animateCamera(CameraUpdate.newLatLng(location));

        // Afișează mesaj
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No nearby vet clinics found within 3km."),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Dacă s-au găsit cabinete
      final enriched = await Future.wait(vets.map((v) async {
        final phone = await getVetPhoneNumber(v.placeId);
        return VetClinic(vet: v, phoneNumber: phone);
      }));

      final markersSet = vets.map((v) {
        return Marker(
          markerId: MarkerId(v.placeId),
          position: LatLng(v.geometry!.location.lat, v.geometry!.location.lng),
          onTap: () => _showVetModal(v.placeId),
        );
      }).toSet();

      setState(() {
        currentLocation = location;
        vetClinics = enriched;
        markers = markersSet;
        loading = false;
      });

      // Mută camera la primul cabinet
      final firstVet = vets.first.geometry!.location;
      mapController.animateCamera(CameraUpdate.newLatLng(
        LatLng(firstVet.lat, firstVet.lng),
      ));
    } else {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to fetch vets: ${response.errorMessage}")),
      );
    }
  }

  void _showVetModal(String placeId) {
    final vetClinic = vetClinics.firstWhere((v) => v.vet.placeId == placeId);
    final vet = vetClinic.vet;
    final phone = vetClinic.phoneNumber;
    final photos = vet.photos;

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
            mainAxisSize: MainAxisSize.min,
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
              Text(vet.vicinity ?? '', style: const TextStyle(color: Colors.white70)),
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
                      final url = 'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(vet.vicinity ?? vet.name)}';
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
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        title: const Text('Vets Near You', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: currentLocation!,
              zoom: 14,
            ),
            markers: markers,
            onMapCreated: (controller) {
              mapController = controller;
            },
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
