import 'dart:async';
import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/firestore_service.dart';

enum ReportPeriod { daily, weekly, monthly }

class OrderProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<Order> _todayOrders = [];
  List<Order> _allOrders = [];
  bool _isLoading = true;
  
  Map<String, dynamic> _stats = {};
  ReportPeriod _currentPeriod = ReportPeriod.daily;
  DateTime _targetDate = DateTime.now();
  DateTime _currentStart = DateTime.now();
  DateTime _currentEnd = DateTime.now();

  StreamSubscription? _todayOrdersSub;
  StreamSubscription? _allOrdersSub;

  List<Order> get todayOrders => _todayOrders;
  List<Order> get allOrders => _allOrders;
  bool get isLoading => _isLoading;
  
  Map<String, dynamic> get todayStats => _stats;
  ReportPeriod get currentPeriod => _currentPeriod;
  DateTime get targetDate => _targetDate;
  DateTime get currentStart => _currentStart;
  DateTime get currentEnd => _currentEnd;
  List<Map<String, dynamic>> get weeklyRevenue => 
      (_stats['chartData'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  int get todayRevenue => _stats['totalRevenue'] ?? 0;
  int get todayTransactions => _stats['totalTransactions'] ?? 0;
  int get averageTransaction => _stats['averageTransaction'] ?? 0;

  void init() {
    _todayOrdersSub =
        _firestoreService.streamTodayOrders().listen((List<Order> orders) {
      _todayOrders = orders;
      if (_currentPeriod == ReportPeriod.daily) {
        loadStats();
      }
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

  Future<void> changePeriod(ReportPeriod period) async {
    _currentPeriod = period;
    _isLoading = true;
    notifyListeners();
    await loadStats();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setTargetDate(DateTime date) async {
    _targetDate = date;
    _isLoading = true;
    notifyListeners();
    await loadStats();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadStats() async {
    try {
      final target = _targetDate;
      DateTime start, end;

      switch (_currentPeriod) {
        case ReportPeriod.daily:
          start = DateTime(target.year, target.month, target.day);
          end = start.add(const Duration(days: 1));
          break;
        case ReportPeriod.weekly:
          // Start of last 7 days
          start = DateTime(target.year, target.month, target.day).subtract(const Duration(days: 6));
          end = DateTime(target.year, target.month, target.day).add(const Duration(days: 1));
          break;
        case ReportPeriod.monthly:
          // Start of target date's month
          start = DateTime(target.year, target.month, 1);
          end = DateTime(target.year, target.month + 1, 1);
          break;
      }

      _currentStart = start;
      _currentEnd = end;
      _stats = await _firestoreService.getStatsByDateRange(start, end);
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

  Future<Order> createOrder(Order order, {int? sequenceNumber, String cashierRole = 'kasir'}) async {
    // Gunakan nomor urut manual (dari draf) jika ada, jika tidak baru ambil dari database
    final seq = sequenceNumber ?? await _firestoreService.getNextOrderSequence();
    final orderWithSeq = order.withSequenceNumber(seq);
    
    final orderId = await _firestoreService.createOrder(orderWithSeq);
    await loadStats(); // Refresh stats

    // Record attendance for salary tracking (non-blocking)
    // Hanya catat untuk role admin dan kasir, BUKAN owner
    if (cashierRole != 'owner') {
      _firestoreService.recordWorkingDay(
          orderWithSeq.cashierName, orderWithSeq.createdAt);
    }
    
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
