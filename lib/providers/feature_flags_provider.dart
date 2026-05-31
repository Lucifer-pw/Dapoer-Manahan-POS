import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeatureFlagsProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _subscription;

  // Cache of features. Key is role (owner/kasir), Value is map of featureId -> bool
  final Map<String, Map<String, bool>> _flags = {
    'owner': {
      'dashboard': true,
      'pos': true,
      'table': true,
      'menu': true,
      'expense': true,
      'order_history': true,
      'cctv': true,
      'best_seller': true,
      'salary': true,
      'user_guide': true,
      'online_users': true,
      'sales_chart': true,
    },
    'kasir': {
      'dashboard': true,
      'pos': true,
      'table': true,
      'menu': true,
      'expense': true,
      'order_history': true,
      'cctv': false,
      'best_seller': true,
      'salary': false,
      'user_guide': true,
      'online_users': false,
      'sales_chart': true,
    }
  };

  bool _isLoading = true;

  Map<String, Map<String, bool>> get flags => _flags;
  bool get isLoading => _isLoading;

  FeatureFlagsProvider() {
    _initListener();
  }

  void _initListener() {
    _subscription = _db.collection('settings').doc('feature_flags').snapshots().listen((doc) {
      _isLoading = false;
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          // Parse owner flags
          if (data['owner'] != null) {
            final ownerData = data['owner'] as Map<String, dynamic>;
            ownerData.forEach((key, value) {
              if (value is bool) {
                _flags['owner']?[key] = value;
              }
            });
          }
          // Parse kasir flags
          if (data['kasir'] != null) {
            final kasirData = data['kasir'] as Map<String, dynamic>;
            kasirData.forEach((key, value) {
              if (value is bool) {
                _flags['kasir']?[key] = value;
              }
            });
          }
        }
      } else {
        // If document does not exist, let's create it with defaults so it's initialized in Firestore
        _initializeDocumentWithDefaults();
      }
      notifyListeners();
    }, onError: (e) {
      debugPrint('Error listening to feature flags: $e');
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> _initializeDocumentWithDefaults() async {
    try {
      await _db.collection('settings').doc('feature_flags').set(_flags);
    } catch (e) {
      debugPrint('Error initializing feature flags in Firestore: $e');
    }
  }

  bool isFeatureEnabled(String role, String featureId) {
    // Admin always has access to all features
    if (role.toLowerCase() == 'admin') return true;
    
    final roleFlags = _flags[role.toLowerCase()];
    if (roleFlags != null) {
      return roleFlags[featureId] ?? true; // Default to true if not specified
    }
    
    return true; // Default fallback
  }

  Future<void> updateFeature(String role, String featureId, bool enabled) async {
    final normalizedRole = role.toLowerCase();
    if (normalizedRole != 'owner' && normalizedRole != 'kasir') return;

    // Optimistic update
    _flags[normalizedRole]?[featureId] = enabled;
    notifyListeners();

    try {
      await _db.collection('settings').doc('feature_flags').set({
        normalizedRole: {
          featureId: enabled,
        }
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating feature flag in Firestore: $e');
      // Revert in case of error
      _initListener(); // Reload from Firestore
      rethrow;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
