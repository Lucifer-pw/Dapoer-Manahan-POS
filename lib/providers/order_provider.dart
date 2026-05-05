import 'dart:async';
import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/firestore_service.dart';

class OrderProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<Order> _todayOrders = [];
  List<Order> _allOrders = [];
  bool _isLoading = true;
  Map<String, dynamic> _todayStats = {};
  List<Map<String, dynamic>> _weeklyRevenue = [];

  StreamSubscription? _todayOrdersSub;
  StreamSubscription? _allOrdersSub;

  List<Order> get todayOrders => _todayOrders;
  List<Order> get allOrders => _allOrders;
  bool get isLoading => _isLoading;
  Map<String, dynamic> get todayStats => _todayStats;
  List<Map<String, dynamic>> get weeklyRevenue => _weeklyRevenue;

  int get todayRevenue => _todayStats['totalRevenue'] ?? 0;
  int get todayTransactions => _todayStats['totalTransactions'] ?? 0;
  int get averageTransaction => _todayStats['averageTransaction'] ?? 0;

  void init() {
    _todayOrdersSub =
        _firestoreService.streamTodayOrders().listen((List<Order> orders) {
      _todayOrders = orders;
      _isLoading = false;
      notifyListeners();
    });

    _allOrdersSub = _firestoreService.streamOrders().listen((List<Order> orders) {
      _allOrders = orders;
      notifyListeners();
    });

    loadStats();
  }

  Future<void> loadStats() async {
    try {
      _todayStats = await _firestoreService.getTodayStats();
      _weeklyRevenue = await _firestoreService.getWeeklyRevenue();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<String> createOrder(Order order) async {
    final orderId = await _firestoreService.createOrder(order);
    await loadStats(); // Refresh stats
    return orderId;
  }

  Future<void> cancelOrder(String orderId) async {
    await _firestoreService.updateOrderStatus(
        orderId, OrderStatus.cancelled);
    await loadStats();
  }

  Future<List<Order>> getOrdersByDateRange(
      DateTime start, DateTime end) async {
    return await _firestoreService.getOrdersByDateRange(start, end);
  }

  @override
  void dispose() {
    _todayOrdersSub?.cancel();
    _allOrdersSub?.cancel();
    super.dispose();
  }
}
