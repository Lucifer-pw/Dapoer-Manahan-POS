import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/auth_service.dart';
import '../services/notification/notification_helper.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  StreamSubscription<DocumentSnapshot>? _userRoleSubscription;

  User? _user;
  String _role = 'kasir';
  String _bankName = '';
  String _bankAccountNumber = '';
  String _bankAccountName = '';
  bool _isLoading = true; // Start with loading to check auth state
  String? _error;
  bool _isAuthChecked = false;

  User? get user => _user;
  String get role => _role;
  String get bankName => _bankName;
  String get bankAccountNumber => _bankAccountNumber;
  String get bankAccountName => _bankAccountName;
  bool get isAdmin => _role == 'admin';
  bool get isOwner => _role == 'owner';
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  bool get isAuthChecked => _isAuthChecked;
  String? get error => _error;
  
  String get cashierName =>
      _user?.displayName ?? _user?.email?.split('@').first ?? 'Kasir';

  AuthProvider() {
    _initAuth();
  }

  void _initAuth() {
    _authService.authStateChanges.listen((user) async {
      _user = user;
      if (user != null) {
        await _fetchUserRole(user.uid);
        await saveDeviceInfo(); // Save device info on every login/restart
        await updateOnlineStatus(true); // Mark user as online
      } else {
        _role = 'kasir';
      }
      _isLoading = false;
      _isAuthChecked = true;
      notifyListeners();
    });
  }

  Future<void> updateOnlineStatus(bool isOnline) async {
    if (_user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
        'isOnline': isOnline,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating online status: $e');
    }
  }

  Future<void> _fetchUserRole(String uid) async {
    // Cancel any existing listener first
    await _userRoleSubscription?.cancel();

    // Do an initial one-shot read for fast startup
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        _role = data['role'] ?? 'kasir';
        _bankName = data['bankName'] ?? '';
        _bankAccountNumber = data['bankAccountNumber'] ?? '';
        _bankAccountName = data['bankAccountName'] ?? '';
      }
    } catch (e) {
      debugPrint('Error fetching role (initial): $e');
    }

    // Then start a realtime listener to keep role in sync
    _userRoleSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final data = doc.data() ?? {};
        final newRole = data['role'] ?? 'kasir';
        final newBankName = data['bankName'] ?? '';
        final newBankAccNum = data['bankAccountNumber'] ?? '';
        final newBankAccName = data['bankAccountName'] ?? '';

        // Only notify if something actually changed
        if (_role != newRole ||
            _bankName != newBankName ||
            _bankAccountNumber != newBankAccNum ||
            _bankAccountName != newBankAccName) {
          _role = newRole;
          _bankName = newBankName;
          _bankAccountNumber = newBankAccNum;
          _bankAccountName = newBankAccName;
          notifyListeners();
        }
      }
    }, onError: (e) {
      debugPrint('Error in role listener: $e');
    });
  }

  Future<void> saveDeviceInfo() async {
    if (_user == null) return;
    
    try {
      Map<String, dynamic> deviceData = {};
      
      if (kIsWeb) {
        WebBrowserInfo webInfo = await _deviceInfo.webBrowserInfo;
        deviceData = {
          'platform': 'web',
          'browser': webInfo.browserName.name,
          'userAgent': webInfo.userAgent,
        };
      } else if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        deviceData = {
          'platform': 'android',
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'manufacturer': androidInfo.manufacturer,
          'hardware': androidInfo.hardware,
          'version': androidInfo.version.release,
          'sdk': androidInfo.version.sdkInt,
          'deviceId': androidInfo.id,
        };
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        deviceData = {
          'platform': 'ios',
          'model': iosInfo.model,
          'name': iosInfo.name,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
          'identifierForVendor': iosInfo.identifierForVendor,
        };
      }

      // Get device FCM token if available
      final String? fcmToken = await NotificationHelper.instance.getDeviceToken();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .collection('devices')
          .doc(deviceData['deviceId'] ?? 'current_device')
          .set({
            ...deviceData,
            if (fcmToken != null) 'fcmToken': fcmToken,
            'lastLogin': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          
      // Also update last login on user doc
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
        'lastDevice': deviceData['model'] ?? deviceData['platform'],
      });
      
    } catch (e) {
      debugPrint('Error saving device info: $e');
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.signIn(email, password);
      // Device info will be saved by the listener
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(String name, String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cred = await _authService.createUser(email, password);
      await _authService.updateDisplayName(name);
      
      if (cred.user != null) {
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
          'name': name,
          'email': email,
          'role': 'kasir',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.sendPasswordResetEmail(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await updateOnlineStatus(false);
    await _userRoleSubscription?.cancel();
    _userRoleSubscription = null;
    await _authService.signOut();
  }

  @override
  void dispose() {
    _userRoleSubscription?.cancel();
    super.dispose();
  }

  Future<bool> updateProfile(String name, String bankName, String bankAccountNumber, String bankAccountName) async {
    if (_user == null) return false;
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.updateDisplayName(name);
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
        'name': name,
        'bankName': bankName,
        'bankAccountNumber': bankAccountNumber,
        'bankAccountName': bankAccountName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _bankName = bankName;
      _bankAccountNumber = bankAccountNumber;
      _bankAccountName = bankAccountName;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
