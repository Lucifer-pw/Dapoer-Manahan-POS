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

    _allOrdersSub =
        _firestoreService.streamOrders().listen((List<Order> orders) {
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

  Future<Map<String, dynamic>> getStatsForDate(DateTime date) async {
    return await _firestoreService.getStatsByDate(date);
  }

  Future<int> getNextSequenceNumber() async {
    return await _firestoreService.getNextOrderSequence();
  }

  Future<Order> createOrder(Order order) async {
    // Get next sequence number (continuous)
    final nextSeq = await _firestoreService.getNextOrderSequence();
    final orderWithSeq = order.withSequenceNumber(nextSeq);
    
    final orderId = await _firestoreService.createOrder(orderWithSeq);
    await loadStats(); // Refresh stats
    
    // Return the full order with the new ID and sequence number
    return Order(
      id: orderId,
      tableNumber: orderWithSeq.tableNumber,
      cashierName: orderWithSeq.cashierName,
      cashierId: orderWithSeq.cashierId,
      items: orderWithSeq.items,
      subtotal: orderWithSeq.subtotal,
      tax: orderWithSeq.tax,
      total: orderWithSeq.total,
      paymentMethod: orderWithSeq.paymentMethod,
      amountPaid: orderWithSeq.amountPaid,
      change: orderWithSeq.change,
      status: orderWithSeq.status,
      createdAt: orderWithSeq.createdAt,
      sequenceNumber: orderWithSeq.sequenceNumber,
    );
  }

  Future<void> cancelOrder(String orderId) async {
    await _firestoreService.updateOrderStatus(orderId, OrderStatus.cancelled);
    await loadStats();
  }

  Future<List<Order>> getOrdersByDateRange(DateTime start, DateTime end) async {
    return await _firestoreService.getOrdersByDateRange(start, end);
  }

  @override
  void dispose() {
    _todayOrdersSub?.cancel();
    _allOrdersSub?.cancel();
    super.dispose();
  }
}
