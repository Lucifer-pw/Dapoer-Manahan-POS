import 'dart:async';
import 'package:flutter/material.dart';
import '../models/table_model.dart';
import '../services/firestore_service.dart';

class TableProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<RestaurantTable> _tables = [];
  bool _isLoading = true;
  StreamSubscription? _tableSub;

  List<RestaurantTable> get tables => _tables;
  bool get isLoading => _isLoading;

  List<RestaurantTable> get availableTables =>
      _tables.where((t) => t.status == TableStatus.available).toList();

  List<RestaurantTable> get occupiedTables =>
      _tables.where((t) => t.status == TableStatus.occupied).toList();

  int get availableCount => availableTables.length;
  int get occupiedCount => occupiedTables.length;

  void init() {
    _tableSub = _firestoreService.streamTables().listen((tables) {
      _tables = tables;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> updateStatus(
      String tableId, TableStatus status, String? orderId) async {
    await _firestoreService.updateTableStatus(tableId, status, orderId);
  }

  Future<void> setOccupied(String tableId, String orderId) async {
    await updateStatus(tableId, TableStatus.occupied, orderId);
  }

  Future<void> setAvailable(String tableId) async {
    await updateStatus(tableId, TableStatus.available, null);
  }

  Future<void> setReserved(String tableId) async {
    await updateStatus(tableId, TableStatus.reserved, null);
  }

  RestaurantTable? getTableByNumber(int number) {
    try {
      return _tables.firstWhere((t) => t.number == number);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _tableSub?.cancel();
    super.dispose();
  }
}
