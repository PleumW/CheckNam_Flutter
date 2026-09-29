import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  User? _user;
  bool _isLoading = true;
  String _role = 'guest';
  String _displayName = '';
  String? _photoUrl;
  bool _isGuestMode = false;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      _isLoading = false;
      if (user != null) {
        if (user.isAnonymous) {
          _isGuestMode = true;
          _role = 'guest';
          _displayName = 'ผู้เยี่ยมชม';
          notifyListeners();
        } else {
          _isGuestMode = false;
          notifyListeners();
          _fetchUserData(user.uid, user.email);
        }
      } else {
        _isGuestMode = false;
        _role = 'guest';
        _displayName = '';
        _photoUrl = null;
        notifyListeners();
      }
    });
  }

  User? get user => _user;
  bool get isAuthenticated => (_user != null && !_user!.isAnonymous) || _isGuestMode;
  bool get isGuest => _isGuestMode || (_user?.isAnonymous ?? false) || _user == null;
  bool get isLoading => _isLoading;
  String get role => (_isGuestMode || _user == null || (_user?.isAnonymous ?? false)) ? 'guest' : _role;
  String get displayName => isGuest
      ? 'ผู้เยี่ยมชม (Guest)'
      : (_displayName.isNotEmpty ? _displayName : (_user?.email?.split('@').first ?? 'ผู้ใช้งานทั่วไป'));
  String? get photoUrl => isGuest ? null : _photoUrl;
  bool get isAdmin => !isGuest && _role == 'admin';

  Future<void> _fetchUserData(String uid, String? email) async {
    try {
      if (_user?.isAnonymous ?? false) {
        _role = 'guest';
        _displayName = 'ผู้เยี่ยมชม';
        notifyListeners();
        return;
      }
      final snapshot = await _dbRef.child('users/$uid').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        _role = data['role'] ?? 'user';
        _displayName = data['displayName'] ?? '';
        _photoUrl = data['photoUrl'];
      } else {
        // Initialize new user data
        _role = (email == 'admin@admin.com') ? 'admin' : 'user';
        await _dbRef.child('users/$uid').update({
          'email': email ?? '',
          'role': _role,
          'displayName': '',
        });
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
  }

  Future<void> signInAsGuest() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _auth.signInAnonymously();
      _isGuestMode = true;
      _role = 'guest';
      _displayName = 'ผู้เยี่ยมชม';
    } catch (e) {
      debugPrint('Firebase Anonymous sign-in failed (fallback to local guest): $e');
      _isGuestMode = true;
      _role = 'guest';
      _displayName = 'ผู้เยี่ยมชม';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({String? name, String? photoBase64}) async {
    if (_user == null) return;
    try {
      final Map<String, dynamic> updates = {};
      if (name != null) updates['displayName'] = name;
      if (photoBase64 != null) updates['photoUrl'] = photoBase64;
      
      await _dbRef.child('users/${_user!.uid}').update(updates);
      if (name != null) _displayName = name;
      if (photoBase64 != null) _photoUrl = photoBase64;
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating profile: $e');
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      _isGuestMode = false;
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> register(String email, String password, {String? dob}) async {
    try {
      _isGuestMode = false;
      UserCredential uc = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      if (uc.user != null) {
        await _dbRef.child('users/${uc.user!.uid}').update({
          'email': email,
          'role': (email == 'admin@admin.com') ? 'admin' : 'user',
          'displayName': '',
          if (dob != null) 'dob': dob,
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    _isGuestMode = false;
    _role = 'guest';
    _displayName = '';
    _photoUrl = null;
    try {
      await _auth.signOut();
    } catch (_) {}
    notifyListeners();
  }
}
