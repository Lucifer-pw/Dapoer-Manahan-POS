import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class StartingCashProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  int _startingCash = 0;
  bool _isLoading = false;

  int get startingCash => _startingCash;
  bool get isLoading => _isLoading;

  Future<void> loadStartingCash(DateTime date) async {
    _isLoading = true;
    notifyListeners();
    try {
      _startingCash = await _firestoreService.getStartingCash(date);
    } catch (e) {
      debugPrint('Error loading starting cash: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateStartingCash(DateTime date, int amount) async {
    try {
      await _firestoreService.setStartingCash(date, amount);
      _startingCash = amount;
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating starting cash: $e');
      rethrow;
    }
  }
}
