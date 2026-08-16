import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/notification/notification_helper.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  StreamSubscription<DocumentSnapshot>? _userRoleSubscription;

  User? _user;
  String _role = '';
  bool _isRoleLoaded = false;
  String _currentShift = ''; // 'Shift 1 (Pagi)' or 'Shift 2 (Malam)'
  String _bankName = '';
  String _bankAccountNumber = '';
  String _bankAccountName = '';
  bool _isLoading = true; // Start with loading to check auth state
  String? _error;
  bool _isAuthChecked = false;

  String _currentShiftLogId = '';
  DateTime? _currentShiftStartTime;

  User? get user => _user;
  String get role => _role;
  bool get isRoleLoaded => _isRoleLoaded;
  String get currentShift => _currentShift;
  String get currentShiftLogId => _currentShiftLogId;
  DateTime? get currentShiftStartTime => _currentShiftStartTime;
  String get bankName => _bankName;
  String get bankAccountNumber => _bankAccountNumber;
  String get bankAccountName => _bankAccountName;
  bool get isAdmin => _role.toLowerCase() == 'admin';
  bool get isOwner => _role.toLowerCase() == 'owner';
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  bool get isAuthChecked => _isAuthChecked;
  String? get error => _error;
  
  String get cashierName =>
      _user?.displayName ?? _user?.email?.split('@').first ?? 'Kasir';

  Future<void> setShift(String shift, {String? shiftLogId, DateTime? startTime}) async {
    _currentShift = shift;
    if (shiftLogId != null) _currentShiftLogId = shiftLogId;
    _currentShiftStartTime = startTime ?? DateTime.now();
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_shift_${_user?.uid}', shift);
      if (_currentShiftLogId.isNotEmpty) {
        await prefs.setString('active_shift_log_id_${_user?.uid}', _currentShiftLogId);
      }
      if (_currentShiftStartTime != null) {
        await prefs.setString('active_shift_start_${_user?.uid}', _currentShiftStartTime!.toIso8601String());
      }
    } catch (_) {}

    if (_user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
          'currentShift': shift,
          'currentShiftLogId': _currentShiftLogId,
          'shiftStartedAt': _currentShiftStartTime != null ? Timestamp.fromDate(_currentShiftStartTime!) : FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error updating shift on user doc: $e');
      }
    }
  }

  Future<void> clearShift() async {
    final uid = _user?.uid;
    _currentShift = '';
    _currentShiftLogId = '';
    _currentShiftStartTime = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (uid != null) {
        await prefs.remove('active_shift_$uid');
        await prefs.remove('active_shift_log_id_$uid');
        await prefs.remove('active_shift_start_$uid');
      }
    } catch (_) {}

    if (_user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
          'currentShift': '',
          'currentShiftLogId': '',
          'shiftEndedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error clearing shift on user doc: $e');
      }
    }
  }

  Timer? _heartbeatTimer;

  AuthProvider() {
    _initAuth();
  }

  void _initAuth() {
    _authService.authStateChanges.listen((user) async {
      _user = user;
      if (user != null) {
        _isRoleLoaded = false;
        await _fetchUserRole(user.uid);
        _isRoleLoaded = true;
        await saveDeviceInfo(); // Save device info on every login/restart
        await updateOnlineStatus(true); // Mark user as online
        _startHeartbeat();
      } else {
        _stopHeartbeat();
        _role = '';
        _isRoleLoaded = true;
        _currentShift = '';
        _currentShiftLogId = '';
        _currentShiftStartTime = null;
      }
      _isLoading = false;
      _isAuthChecked = true;
      notifyListeners();
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_user != null) {
        updateOnlineStatus(true);
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
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

    // 1. Cek cache lokal SharedPreferences terlebih dahulu agar instan saat refresh
    try {
      final prefs = await SharedPreferences.getInstance();
      final localShift = prefs.getString('active_shift_$uid');
      if (localShift != null && localShift.isNotEmpty) {
        _currentShift = localShift;
        _currentShiftLogId = prefs.getString('active_shift_log_id_$uid') ?? '';
        final localStart = prefs.getString('active_shift_start_$uid');
        if (localStart != null) _currentShiftStartTime = DateTime.tryParse(localStart);
      }
    } catch (_) {}

    // 2. Baca dari Firestore untuk mendapatkan status shift & role terkini
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        _role = (data['role']?.toString() ?? 'kasir').trim().toLowerCase();
        _bankName = data['bankName'] ?? '';
        _bankAccountNumber = data['bankAccountNumber'] ?? '';
        _bankAccountName = data['bankAccountName'] ?? '';
        
        final remoteShift = data['currentShift'] as String? ?? '';
        if (remoteShift.isNotEmpty) {
          _currentShift = remoteShift;
          _currentShiftLogId = data['currentShiftLogId'] as String? ?? '';
          final sTime = data['shiftStartedAt'];
          if (sTime is Timestamp) {
            _currentShiftStartTime = sTime.toDate();
          } else if (sTime is DateTime) {
            _currentShiftStartTime = sTime;
          }
        } else if (_currentShift.isEmpty) {
          _currentShift = '';
          _currentShiftLogId = '';
          _currentShiftStartTime = null;
        }
      }
    } catch (e) {
      debugPrint('Error fetching role (initial): $e');
    }

    // 3. Listener realtime Firestore
    _userRoleSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final data = doc.data() ?? {};
        final newRole = (data['role']?.toString() ?? 'kasir').trim().toLowerCase();
        final newBankName = data['bankName'] ?? '';
        final newBankAccNum = data['bankAccountNumber'] ?? '';
        final newBankAccName = data['bankAccountName'] ?? '';
        final newShift = data['currentShift'] as String? ?? '';
        final newShiftLogId = data['currentShiftLogId'] as String? ?? '';

        if (_role != newRole ||
            _bankName != newBankName ||
            _bankAccountNumber != newBankAccNum ||
            _bankAccountName != newBankAccName ||
            _currentShift != newShift) {
          _role = newRole;
          _bankName = newBankName;
          _bankAccountNumber = newBankAccNum;
          _bankAccountName = newBankAccName;
          _currentShift = newShift;
          _currentShiftLogId = newShiftLogId;
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
    _isRoleLoaded = false;
    _error = null;
    notifyListeners();

    try {
      final cred = await _authService.signIn(email, password);
      if (cred.user != null) {
        _user = cred.user;
        await _fetchUserRole(cred.user!.uid);
        await saveDeviceInfo();
        await updateOnlineStatus(true);
      }
      _isLoading = false;
      _isAuthChecked = true;
      _isRoleLoaded = true;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _isAuthChecked = true;
      _isRoleLoaded = true;
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
        // Force refresh the auth token to ensure the Firestore client is aware of the new authenticated session
        await cred.user!.getIdToken(true);
        // Small delay to let the Firestore client state update propagate
        await Future.delayed(const Duration(milliseconds: 300));

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
    _currentShift = '';
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
