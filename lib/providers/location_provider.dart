import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';

class LocationProvider with ChangeNotifier {
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('user_locations');
  String? _userId;
  String? _placeName;

  Position? get currentPosition => _currentPosition;
  String? get placeName => _placeName;
  bool get isGpsActive => _currentPosition != null;

  String get coordinatesText {
    if (_currentPosition != null) {
      return '${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}';
    }
    return '13.7563, 100.5018';
  }

  String get locationDisplayText {
    if (_placeName != null && _placeName!.isNotEmpty) {
      return '$_placeName ($coordinatesText)';
    }
    return 'พิกัด $coordinatesText';
  }

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

      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && _currentPosition == null) {
          _currentPosition = lastKnown;
          _reverseGeocode(lastKnown.latitude, lastKnown.longitude);
          notifyListeners();
        }
        final initial = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 4),
        );
        _currentPosition = initial;
        _reverseGeocode(initial.latitude, initial.longitude);
        notifyListeners();
        _pushToFirebase(initial);
      } catch (e) {
        debugPrint('Initial location capture note: $e');
      }

      final locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // update when moved 10 meters
      );

      _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position? position) {
          if (position != null) {
            _currentPosition = position;
            _reverseGeocode(position.latitude, position.longitude);
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

  Future<void> refreshLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      _currentPosition = pos;
      await _reverseGeocode(pos.latitude, pos.longitude);
      notifyListeners();
      _pushToFirebase(pos);
    } catch (e) {
      debugPrint('Error refreshing location: $e');
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
          'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lng&localityLanguage=th');
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final locality = data['locality']?.toString() ?? '';
        final city = data['city']?.toString() ?? data['principalSubdivision']?.toString() ?? '';
        if (locality.isNotEmpty && city.isNotEmpty && locality != city) {
          _placeName = '$locality, $city';
        } else if (city.isNotEmpty) {
          _placeName = city;
        } else if (locality.isNotEmpty) {
          _placeName = locality;
        }
        notifyListeners();
      }
    } catch (_) {}
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
