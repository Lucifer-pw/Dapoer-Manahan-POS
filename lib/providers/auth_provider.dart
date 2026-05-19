import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  User? _user;
  String _role = 'kasir';
  bool _isLoading = true; // Start with loading to check auth state
  String? _error;
  bool _isAuthChecked = false;

  User? get user => _user;
  String get role => _role;
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
      } else {
        _role = 'kasir';
      }
      _isLoading = false;
      _isAuthChecked = true;
      notifyListeners();
    });
  }

  Future<void> _fetchUserRole(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        _role = doc.data()?['role'] ?? 'kasir';
      }
    } catch (e) {
      debugPrint('Error fetching role: $e');
    }
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

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .collection('devices')
          .doc(deviceData['deviceId'] ?? 'current_device')
          .set({
            ...deviceData,
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
    await _authService.signOut();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
