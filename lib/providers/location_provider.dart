import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';

class LocationProvider with ChangeNotifier {
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('user_locations');
  String? _userId;

  Position? get currentPosition => _currentPosition;

  LocationProvider() {
    _startTracking();
  }

  void updateUserId(String? uid) {
    _userId = uid;
    if (_userId != null && _currentPosition != null) {
      _pushToFirebase(_currentPosition!);
    }
  }

  void _pushToFirebase(Position position) {
    if (_userId != null) {
      _dbRef.child(_userId!).set({
        'lat': position.latitude,
        'lng': position.longitude,
        'timestamp': ServerValue.timestamp,
      });
    }
  }

  Future<void> _startTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied.');
        return;
      } 

      final locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // update when moved 10 meters
      );

      _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position? position) {
          if (position != null) {
            _currentPosition = position;
            notifyListeners();
            _pushToFirebase(position);
          }
        },
        onError: (error) {
          debugPrint('Geolocator error stream: $error');
        },
      );
    } catch (e) {
      debugPrint('Error starting location tracking: $e');
    }
  }

  void _stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _currentPosition = null;
  }

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }
}
