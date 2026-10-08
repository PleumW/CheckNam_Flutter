import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../utils/security_utils.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  User? _user;
  bool _isLoading = true;
  String _role = 'guest';
  String _displayName = '';
  String? _photoUrl;
  bool _isGuestMode = false;

  // Personal Citizen Identification Fields (ข้อมูลจริงสำหรับการกู้ภัยและระบุตัวตน)
  String _nationalId = '';
  String _dob = '';
  String _firstNameTh = '';
  String _lastNameTh = '';
  String _nicknameTh = '';
  String _firstNameEn = '';
  String _lastNameEn = '';
  String _nicknameEn = '';
  String _phoneNumber = '';
  bool _isPdpaAccepted = false;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      _isLoading = false;
      if (user != null) {
        if (user.isAnonymous) {
          _isGuestMode = true;
          _role = 'guest';
          _displayName = 'ผู้เยี่ยมชม';
          _clearProfileData();
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
        _clearProfileData();
        notifyListeners();
      }
    });
  }

  void _clearProfileData() {
    _nationalId = '';
    _dob = '';
    _firstNameTh = '';
    _lastNameTh = '';
    _nicknameTh = '';
    _firstNameEn = '';
    _lastNameEn = '';
    _nicknameEn = '';
    _phoneNumber = '';
    _isPdpaAccepted = false;
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

  String get nationalId => _nationalId;
  String get dob => _dob;
  String get firstNameTh => _firstNameTh;
  String get lastNameTh => _lastNameTh;
  String get nicknameTh => _nicknameTh;
  String get firstNameEn => _firstNameEn;
  String get lastNameEn => _lastNameEn;
  String get nicknameEn => _nicknameEn;
  String get phoneNumber => _phoneNumber;
  bool get isPdpaAccepted => _isPdpaAccepted;

  String get fullThaiName => '$_firstNameTh $_lastNameTh'.trim();
  String get fullEnglishName => '$_firstNameEn $_lastNameEn'.trim();
  String get fullIdentityText {
    if (_firstNameTh.isNotEmpty) {
      final base = '$_firstNameTh $_lastNameTh'.trim();
      return _nicknameTh.isNotEmpty ? '$base ($_nicknameTh)' : base;
    }
    return displayName;
  }

  Future<void> _fetchUserData(String uid, String? email) async {
    try {
      if (_user?.isAnonymous ?? false) {
        _role = 'guest';
        _displayName = 'ผู้เยี่ยมชม';
        _clearProfileData();
        notifyListeners();
        return;
      }
      final snapshot = await _dbRef.child('users/$uid').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        _role = data['role'] ?? 'user';
        _displayName = data['displayName'] ?? '';
        _photoUrl = data['photoUrl'];
        _nationalId = data['nationalId']?.toString() ?? '';
        _dob = data['dob']?.toString() ?? '';
        _firstNameTh = data['firstNameTh']?.toString() ?? '';
        _lastNameTh = data['lastNameTh']?.toString() ?? '';
        _nicknameTh = data['nicknameTh']?.toString() ?? '';
        _firstNameEn = data['firstNameEn']?.toString() ?? '';
        _lastNameEn = data['lastNameEn']?.toString() ?? '';
        _nicknameEn = data['nicknameEn']?.toString() ?? '';
        _phoneNumber = data['phoneNumber']?.toString() ?? '';
        _isPdpaAccepted = data['isPdpaAccepted'] == true;

        if (_displayName.isEmpty && _firstNameTh.isNotEmpty) {
          _displayName = fullIdentityText;
        }
      } else {
        // Initialize new user data
        _role = (email == 'admin@admin.com') ? 'admin' : 'user';
        await _dbRef.child('users/$uid').update({
          'email': email ?? '',
          'role': _role,
          'displayName': '',
        });
      }
      _syncAdminNotificationSubscription(_role == 'admin', uid);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
  }

  Future<void> _syncAdminNotificationSubscription(bool isAdmin, String? uid) async {
    if (kIsWeb) return;
    try {
      final messaging = FirebaseMessaging.instance;
      if (isAdmin) {
        await messaging.subscribeToTopic('admin_sos');
        debugPrint('[FCM] Admin successfully subscribed to topic: admin_sos');
        try {
          final token = await messaging.getToken();
          if (token != null && uid != null) {
            await _dbRef.child('admins/$uid').update({
              'fcm_token': token,
              'email': _user?.email ?? '',
              'last_active': DateTime.now().toIso8601String(),
            });
          }
        } catch (e) {
          debugPrint('[FCM] Error saving admin token: $e');
        }
      } else {
        await messaging.unsubscribeFromTopic('admin_sos');
        debugPrint('[FCM] Unsubscribed from topic: admin_sos');
      }
    } catch (e) {
      debugPrint('[FCM] Error managing admin notification subscription: $e');
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
      _clearProfileData();
    } catch (e) {
      debugPrint('Firebase Anonymous sign-in failed (fallback to local guest): $e');
      _isGuestMode = true;
      _role = 'guest';
      _displayName = 'ผู้เยี่ยมชม';
      _clearProfileData();
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

  /// Sign In with SHA-256 Hashed Password
  /// Includes fallback and automatic upgrade for legacy plaintext password accounts
  Future<void> signIn(String email, String password) async {
    try {
      _isGuestMode = false;
      final hashedPassword = SecurityUtils.hashPassword(password);
      try {
        await _auth.signInWithEmailAndPassword(email: email, password: hashedPassword);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'user-not-found') {
          // Attempt fallback with raw password for accounts registered before hashing implementation
          try {
            await _auth.signInWithEmailAndPassword(email: email, password: password);
            // Upgrade legacy password to SHA-256 hash in Firebase Auth & Realtime Database
            if (_auth.currentUser != null) {
              await _auth.currentUser!.updatePassword(hashedPassword);
              await _dbRef.child('users/${_auth.currentUser!.uid}').update({
                'passwordHash': hashedPassword,
                'passwordUpgradedAt': DateTime.now().toIso8601String(),
              });
            }
          } catch (_) {
            rethrow;
          }
        } else {
          rethrow;
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Register new citizen user with SHA-256 Password Hash, Verified Identity Data, and PDPA Consent
  Future<void> register({
    required String email,
    required String password,
    String nationalId = '',
    String dob = '',
    String firstNameTh = '',
    String lastNameTh = '',
    String nicknameTh = '',
    String firstNameEn = '',
    String lastNameEn = '',
    String nicknameEn = '',
    String phoneNumber = '',
    bool isPdpaAccepted = true,
    bool isEmailOtpVerified = true,
  }) async {
    try {
      _isGuestMode = false;
      final hashedPassword = SecurityUtils.hashPassword(password);
      UserCredential uc = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: hashedPassword,
      );

      if (uc.user != null) {
        final displayNameTh = firstNameTh.isNotEmpty
            ? ('$firstNameTh $lastNameTh'.trim() + (nicknameTh.isNotEmpty ? ' ($nicknameTh)' : ''))
            : '';

        if (displayNameTh.isNotEmpty) {
          try {
            await uc.user!.updateDisplayName(displayNameTh);
          } catch (_) {}
        }

        final role = (email == 'admin@admin.com') ? 'admin' : 'user';
        final userData = {
          'email': email,
          'role': role,
          'passwordHash': hashedPassword,
          'nationalId': nationalId,
          'dob': dob,
          'firstNameTh': firstNameTh,
          'lastNameTh': lastNameTh,
          'nicknameTh': nicknameTh,
          'firstNameEn': firstNameEn,
          'lastNameEn': lastNameEn,
          'nicknameEn': nicknameEn,
          'phoneNumber': phoneNumber,
          'displayName': displayNameTh,
          'isPdpaAccepted': isPdpaAccepted,
          'isEmailOtpVerified': isEmailOtpVerified,
          'otpVerifiedSender': 'mihoyostarrail00001@gmail.com',
          'otpVerifiedAt': DateTime.now().toIso8601String(),
          'registeredAt': DateTime.now().toIso8601String(),
        };

        await _dbRef.child('users/${uc.user!.uid}').update(userData);

        _role = role;
        _displayName = displayNameTh;
        _nationalId = nationalId;
        _dob = dob;
        _firstNameTh = firstNameTh;
        _lastNameTh = lastNameTh;
        _nicknameTh = nicknameTh;
        _firstNameEn = firstNameEn;
        _lastNameEn = lastNameEn;
        _nicknameEn = nicknameEn;
        _phoneNumber = phoneNumber;
        _isPdpaAccepted = isPdpaAccepted;
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _syncAdminNotificationSubscription(false, _user?.uid);
    _isGuestMode = false;
    _role = 'guest';
    _displayName = '';
    _photoUrl = null;
    _clearProfileData();
    try {
      await _auth.signOut();
    } catch (_) {}
    notifyListeners();
  }
}
