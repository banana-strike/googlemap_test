import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert'; // เพิ่ม import สำหรับ JSON
import 'package:http/http.dart' as http; // เพิ่ม import สำหรับยิง HTTP

void main() {
  runApp(const MaterialApp(home: Googlemap()));
}

const String openRouteServiceAPIKey = '5b3ce3597851110001cf624817b960660ee84ddbaaf8ea6a63a449bc'; // ใส่ OpenRouteService API Key ของคุณตรงนี้

const LatLng currentLocation = LatLng(20.0404, 99.8903); // MFU
const LatLng d1 = LatLng(20.047561, 99.893789); // จุด D1
const LatLng e1 = LatLng(20.045840, 99.893658); // จุด E1

late GoogleMapController mapController;
Set<Marker> markers = {};
Set<Polyline> polylines = {}; // เพิ่มตัวแปรสำหรับเก็บ Polyline

class Googlemap extends StatefulWidget {
  const Googlemap({super.key});

  @override
  State<Googlemap> createState() => _GooglemapState();
}

class _GooglemapState extends State<Googlemap> {
  Position? currentPosition;
  LatLng? selectedDestination;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    PermissionStatus status = await Permission.location.request();
    if (status.isGranted) {
      _getCurrentLocation();
    } else {
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Permission required"),
          content: const Text("Location permission is required to use this feature."),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      currentPosition = position;
    });

    LatLng userLocation = LatLng(position.latitude, position.longitude);

    setState(() {
      markers.add(Marker(
        markerId: const MarkerId("userLocation"),
        position: userLocation,
        infoWindow: const InfoWindow(title: 'Your Location'),
      ));
    });

    mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: userLocation,
          zoom: 18,
        ),
      ),
    );
  }

  // เปลี่ยนฟังก์ชันนี้ให้ใช้ OpenRouteService API สำหรับเส้นทางเดิน
  Future<void> _createWalkingRoute(LatLng start, LatLng end) async {
    final String url = 'https://api.openrouteservice.org/v2/directions/foot-walking?api_key=$openRouteServiceAPIKey&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}';

    try {
      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['features'] != null) {
        final points = data['features'][0]['geometry']['coordinates'];
        final List<LatLng> polylineCoordinates = _convertToLatLng(points);

        setState(() {
          polylines.clear(); // ล้างเส้นทางเก่าก่อน
          polylines.add(Polyline(
            polylineId: const PolylineId('route'),
            points: polylineCoordinates, // พิกัดที่ได้จาก OpenRouteService
            width: 5,
            color: Colors.blue, // กำหนดสีเส้นทาง
          ));
        });

        // ขยับกล้องไปตามเส้นทาง
        _animateCameraAlongPolyline(polylineCoordinates);
        _animateMarkerAlongPolyline(polylineCoordinates);
      } else {
        print('Error fetching directions: ${data['error']['message']}');
        _showErrorDialog('Error fetching directions: ${data['error']['message']}');
      }
    } catch (e) {
      print('Exception: $e');
      _showErrorDialog('An error occurred while fetching directions.');
    }
  }

  // ฟังก์ชันแปลงข้อมูล Polyline จาก OpenRouteService
  List<LatLng> _convertToLatLng(List<dynamic> coordinates) {
    List<LatLng> polyline = [];
    for (var point in coordinates) {
      polyline.add(LatLng(point[1], point[0])); // OpenRouteService ให้ค่าเป็น [longitude, latitude]
    }
    return polyline;
  }

  // ฟังก์ชันขยับกล้องตามเส้นทาง (Polyline) พร้อมมุมมองเอียง
  void _animateCameraAlongPolyline(List<LatLng> polylineCoordinates) {
    for (int i = 0; i < polylineCoordinates.length; i++) {
      Future.delayed(Duration(seconds: i), () {
        mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: polylineCoordinates[i],
              zoom: 18,
              tilt: 45,  // การตั้งค่า tilt เป็นมุมเอียงที่ 45 องศา
            ),
          ),
        );
      });
    }
  }

  // ฟังก์ชันขยับ Marker ไปตามเส้นทาง (Polyline)
  void _animateMarkerAlongPolyline(List<LatLng> polylineCoordinates) {
    for (int i = 0; i < polylineCoordinates.length; i++) {
      Future.delayed(Duration(seconds: i), () {
        setState(() {
          markers.clear(); // ลบ Marker เก่าก่อน
          markers.add(Marker(
            markerId: const MarkerId("userLocation"),
            position: polylineCoordinates[i], // อัปเดตตำแหน่งของ Marker
            infoWindow: const InfoWindow(title: 'Your Location'),
          ));
        });
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Error"),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  // ฟังก์ชันแสดง Dialog เลือกจุดที่ต้องการนำทาง
  void _showDestinationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Select Destination"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text("D1 (20.047561, 99.893789)"),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    selectedDestination = d1;
                  });
                  if (currentPosition != null) {
                    _createWalkingRoute(
                      LatLng(currentPosition!.latitude, currentPosition!.longitude),
                      d1,
                    );
                  }
                },
              ),
              ListTile(
                title: const Text("E1 (20.045840, 99.893658)"),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    selectedDestination = e1;
                  });
                  if (currentPosition != null) {
                    _createWalkingRoute(
                      LatLng(currentPosition!.latitude, currentPosition!.longitude),
                      e1,
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Map")),
      body: Stack(
        children: [
          SizedBox.expand(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: currentLocation,
                zoom: 10,
              ),
              mapType: MapType.normal,
              markers: markers,
              polylines: polylines,
              onMapCreated: (controller) {
                mapController = controller;
                mapController.animateCamera(CameraUpdate.newLatLng(currentLocation));
              },
            ),
          ),
          Positioned(
            bottom: 30,
            left: 30,
            child: FloatingActionButton(
              onPressed: _showDestinationDialog,
              child: const Icon(Icons.directions),
              backgroundColor: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}
