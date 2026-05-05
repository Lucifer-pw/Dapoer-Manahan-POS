import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class SettingsProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  String _wifiSsid = 'Dapoer_MNH';
  String _wifiPassword = 'Tinggalnyambungkak';
  bool _isLoading = false;

  String get wifiSsid => _wifiSsid;
  String get wifiPassword => _wifiPassword;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final info = await _firestoreService.getWifiInfo();
      _wifiSsid = info['nama'] ?? 'Dapoer_MNH';
      _wifiPassword = info['password'] ?? 'Tinggalnyambungkak';
    } catch (e) {
      debugPrint('Error initializing settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateWifi(String ssid, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firestoreService.updateWifiInfo(ssid, password);
      _wifiSsid = ssid;
      _wifiPassword = password;
    } catch (e) {
      debugPrint('Error updating WiFi: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
