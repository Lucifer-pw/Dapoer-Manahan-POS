import 'dart:async';
import 'package:flutter/material.dart';
import '../models/table_model.dart';
import '../services/firestore_service.dart';

class TableProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<RestaurantTable> _tables = [];
  bool _isLoading = true;
  StreamSubscription? _tableSub;
  int? _pendingHighlightTableNumber;

  List<RestaurantTable> get tables => _tables;
  bool get isLoading => _isLoading;
  int? get pendingHighlightTableNumber => _pendingHighlightTableNumber;

  set pendingHighlightTableNumber(int? val) {
    _pendingHighlightTableNumber = val;
    notifyListeners();
  }

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

  Future<void> addTable(int number, int capacity) async {
    final qrUrl = 'https://pos-dapoer-manahan.web.app/table/$number';
    final table = RestaurantTable(
      id: '', // Firestore will generate
      number: number,
      capacity: capacity,
      status: TableStatus.available,
      qrUrl: qrUrl,
    );
    await _firestoreService.addTable(table);
  }

  Future<void> updateTable(String id, int number, int capacity) async {
    final qrUrl = 'https://pos-dapoer-manahan.web.app/table/$number';
    await _firestoreService.updateTable(id, {
      'number': number,
      'capacity': capacity,
      'qrUrl': qrUrl,
    });
  }

  Future<void> deleteTable(String id) async {
    await _firestoreService.deleteTable(id);
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
