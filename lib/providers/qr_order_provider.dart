import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firestore_service.dart';
import '../models/order_item.dart';
import 'cart_provider.dart';
import 'navigation_provider.dart';

class QrOrderProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<Map<String, dynamic>> _pendingOrders = [];
  bool _isLoading = true;
  StreamSubscription? _qrOrderSub;

  List<Map<String, dynamic>> get pendingOrders => _pendingOrders;
  bool get isLoading => _isLoading;
  int get pendingCount => _pendingOrders.length;

  void init() {
    _qrOrderSub?.cancel();
    _qrOrderSub = _firestoreService.streamPendingQrOrders().listen((orders) {
      final bool hasNewOrder = orders.length > _pendingOrders.length;
      _pendingOrders = orders;
      _isLoading = false;
      notifyListeners();

      if (hasNewOrder) {
        _playAlertSound();
      }
    });
  }

  void _playAlertSound() {
    SystemSound.play(SystemSoundType.click);
    Future.delayed(const Duration(milliseconds: 150), () {
      SystemSound.play(SystemSoundType.click);
    });
    HapticFeedback.vibrate();
  }

  Future<void> acceptQrOrder(
    String qrOrderId, 
    BuildContext context, 
    CartProvider cartProv, 
    NavigationProvider navProv
  ) async {
    // Find the order details
    final order = _pendingOrders.firstWhere((o) => o['id'] == qrOrderId, orElse: () => {});
    if (order.isEmpty) return;

    final int tableNum = order['tableNumber'] as int? ?? 0;
    final List<dynamic> rawItems = order['items'] as List<dynamic>? ?? [];
    
    final List<OrderItem> orderItems = rawItems.map((itemMap) {
      return OrderItem.fromMap(Map<String, dynamic>.from(itemMap));
    }).toList();

    // Load items and table info to the active CartProvider
    cartProv.loadQrOrder(tableNum, orderItems);

    // Update the QR order status in Firestore
    await _firestoreService.updateQrOrderStatus(qrOrderId, 'accepted');

    // Switch view to the POS/Kasir screen
    navProv.setIndex(1);
  }

  Future<void> rejectQrOrder(String qrOrderId) async {
    await _firestoreService.updateQrOrderStatus(qrOrderId, 'rejected');
  }

  @override
  void dispose() {
    _qrOrderSub?.cancel();
    super.dispose();
  }
}
