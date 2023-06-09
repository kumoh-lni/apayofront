import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HospitalSearchPage extends StatefulWidget {
  final String recommendedSpecialistName;

  const HospitalSearchPage({Key? key, required this.recommendedSpecialistName})
      : super(key: key);

  @override
  _HospitalSearchPageState createState() => _HospitalSearchPageState();
}

class _HospitalSearchPageState extends State<HospitalSearchPage> {
  Completer<GoogleMapController> _controller = Completer();
  CameraPosition? _currentPosition;
  LocationData? _locationData;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    Location location = Location();
    bool serviceEnabled;
    PermissionStatus permissionStatus;
    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }
    permissionStatus = await location.hasPermission();
    if (permissionStatus == PermissionStatus.denied) {
      permissionStatus = await location.requestPermission();
      if (permissionStatus != PermissionStatus.granted) {
        return;
      }
    }
    _locationData = await location.getLocation();
    if (_locationData == null) {
      _currentPosition = CameraPosition(
        target: LatLng(37.5665, 126.9780),
        zoom: 10.0,
      );
    } else {
      _currentPosition = CameraPosition(
        target: LatLng(_locationData!.latitude!, _locationData!.longitude!),
        zoom: 10.0,
      );

      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(_currentPosition!));
    }
  }

  Future<void> _searchHospital() async {
    await _getLocation();
    String apiUrl = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
    String location = '${_locationData!.latitude},${_locationData!.longitude}';
    String type = 'hospital';
    String keyword = '병원';
    String apiKey = 'AIzaSyBYQFpEdgAhhjvcsIqb8VrMkOMcwVYCAKs'; // 자신의 API 키로 변경
    Uri uri = Uri.parse('$apiUrl?location=$location&type=$type&keyword=$keyword&radius=5000&key=$apiKey');
    print(uri);
    http.Response response = await http.get(uri);

    if (response.statusCode == 200) {
      dynamic jsonResponse = json.decode(response.body);
      if (jsonResponse['status'] == 'OK') {
        List<dynamic> hospitals = jsonResponse['results'];

        // 검색 결과를 지도에 나타내기
        Set<Marker> markers = Set<Marker>();
        for (dynamic hospital in hospitals) {
          double lat = hospital['geometry']['location']['lat'];
          double lng = hospital['geometry']['location']['lng'];
          String name = hospital['name'];
          MarkerId id = MarkerId(name);
          Marker marker = Marker(
            markerId: id,
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(title: name),
            onTap: () {
              _onMarkerTapped(id);
            },
          );
          markers.add(marker);
        }

        final GoogleMapController controller = await _controller.future;
        controller.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition!.target, 12.0));

        setState(() {
          _markers.clear();
          _markers = markers;
        });

        if (hospitals.isEmpty) {
          _showNoResultDialog();
        }
      } else {
        _showErrorDialog(jsonResponse['status']);
      }
    } else {
      _showErrorDialog('HTTP Error: ${response.statusCode}');
    }
  }

  void _showNoResultDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('검색 결과 없음'),
        content: Text('현재 위치에서 주변에 해당 진료과를 제공하는 병원이 없습니다. 일시적인 오류일 수도 있으니 다른 지도앱을 사용해보세요.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('검색 실패'),
        content: Text(errorMessage),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('확인'),
          ),
        ],
      ),
    );
  }


  void _onMarkerTapped(MarkerId markerId) {}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xff5CCFD4),  // 배경색을 Color(0xff5CCFD4)로 설정
      appBar: AppBar(
        title: Text('병원 찾기'),
        centerTitle: true,
        backgroundColor: Color(0xff5CCFD4),  // AppBar의 배경색을 Color(0xff5CCFD4)로 설정
      ),
      body: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: _currentPosition ?? CameraPosition(
          target: LatLng(37.5665, 126.9780),
          zoom: 10.0,
        ),
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
        markers: _markers,
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _searchHospital,
            backgroundColor: Color(0xff5CCFD4),  // FloatingActionButton의 배경색을 Color(0xff5CCFD4)로 설정
            child: Icon(Icons.search),
          ),
          SizedBox(height: 16.0),
          FloatingActionButton(
            onPressed: () {
              _getLocation();
            },
            backgroundColor: Color(0xff5CCFD4),  // FloatingActionButton의 배경색을 Color(0xff5CCFD4)로 설정
            child: Icon(Icons.my_location),
          ),
          SizedBox(height: 16.0),
          FloatingActionButton(
            onPressed: () {
              Navigator.pop(context);
            },
            backgroundColor: Color(0xff5CCFD4),  // FloatingActionButton의 배경색을 Color(0xff5CCFD4)로 설정
            child: Icon(Icons.arrow_back),
          ),
        ],
      ),
    );
  }

}