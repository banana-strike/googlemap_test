import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MaterialApp(home: Googlemap()));
}

const LatLng currentLocation = LatLng(20.0404, 99.8903); // MFU
const LatLng d1 = LatLng(20.047561, 99.893789); // จุด D1
const LatLng e1 = LatLng(20.045840, 99.893658); // จุด E1

late GoogleMapController googleMapController;
Set<Marker> marker = {};
Set<Polyline> polylines = {}; // เพิ่มตัวแปรสำหรับเก็บ Polyline

class Googlemap extends StatefulWidget {
  const Googlemap({super.key});

  @override
  State<Googlemap> createState() => _GooglemapState();
}

class _GooglemapState extends State<Googlemap> {
  late GoogleMapController mapController;
  Position? currentPosition;
  LatLng? selectedDestination; // จัดเก็บจุดที่เลือก

  @override
  void initState() {
    super.initState();
    // เรียกขอ permission เมื่อแอปถูกเปิดครั้งแรก
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    PermissionStatus status = await Permission.location.request();
    if (status.isGranted) {
      print("Location permission granted");
      // สามารถใช้งานตำแหน่งได้
      _getCurrentLocation();
    } else {
      print("Location permission denied");
      // แจ้งเตือนผู้ใช้ให้อนุญาต
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

  // ดึงตำแหน่งปัจจุบันของผู้ใช้
  Future<void> _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      currentPosition = position;
    });

    LatLng userLocation = LatLng(position.latitude, position.longitude);

    // อัพเดตตำแหน่ง Marker
    setState(() {
      marker.add(Marker(
        markerId: MarkerId("userLocation"),
        position: userLocation,
        infoWindow: InfoWindow(title: 'Your Location'),
      ));
    });

    // เลื่อนแผนที่ไปยังตำแหน่งผู้ใช้ พร้อมซูมเข้า
    mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: userLocation,
          zoom: 18,  
        ),
      ),
    );
  }

  // ฟังก์ชันสร้าง Polyline
  void _createPolyline(LatLng start, LatLng end) {
    setState(() {
      polylines.clear(); // ลบ polyline เก่าออก
      polylines.add(Polyline(
        polylineId: PolylineId('route'),
        visible: true,
        points: [start, end], // เชื่อมต่อตำแหน่ง start และ end
        width: 5,
        color: Colors.blue,
      ));
    });
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
                    selectedDestination = d1; // กำหนดจุดที่เลือก
                  });
                  if (currentPosition != null) {
                    // เชื่อม Polyline ระหว่าง currentLocation และ D1
                    _createPolyline(LatLng(currentPosition!.latitude, currentPosition!.longitude), d1);
                  }
                },
              ),
              ListTile(
                title: const Text("E1 (20.045840, 99.893658)"),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    selectedDestination = e1; // กำหนดจุดที่เลือก
                  });
                  if (currentPosition != null) {
                    // เชื่อม Polyline ระหว่าง currentLocation และ E1
                    _createPolyline(LatLng(currentPosition!.latitude, currentPosition!.longitude), e1);
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
      appBar: AppBar(title: const Text("Google Map")),
      body: Stack(
        children: [
          SizedBox.expand(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: currentLocation,
                zoom: 10,
              ),
              mapType: MapType.normal,
              markers: marker, // เพิ่ม Marker
              polylines: polylines, // เพิ่ม Polyline
              onMapCreated: (controller) {
                mapController = controller;
                print("Map created!");
                // เริ่มต้นแสดงตำแหน่ง
                mapController.animateCamera(CameraUpdate.newLatLng(currentLocation));
              },
            ),
          ),
          // ปุ่มที่ขวามือ
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
