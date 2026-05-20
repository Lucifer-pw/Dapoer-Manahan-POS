import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityProvider extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> _subscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  ConnectivityProvider() {
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    try {
      final ConnectivityResult result = await _connectivity.checkConnectivity();
      _updateStatus(result);
    } catch (e) {
      debugPrint('Connectivity Init Error: $e');
    }

    _subscription = _connectivity.onConnectivityChanged.listen(
      (ConnectivityResult result) {
        _updateStatus(result);
      },
    );
  }

  void _updateStatus(ConnectivityResult result) {
    final bool online = result != ConnectivityResult.none;
    if (_isOnline != online) {
      _isOnline = online;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}