import 'package:flutter/foundation.dart' hide Category;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category.dart';
import '../models/menu_item.dart';
import '../models/order.dart' as app;
import '../models/table_model.dart';
import '../utils/constants.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ============================================================
  // CATEGORIES
  // ============================================================

  CollectionReference get _categoriesRef => _db.collection('categories');

  Stream<List<Category>> streamCategories() {
    return _categoriesRef.orderBy('sortOrder').snapshots().map((snapshot) {
      return snapshot.docs
          .map<Category>((doc) =>
              Category.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  Future<void> addCategory(Category category) async {
    await _categoriesRef.add(category.toMap());
  }

  Future<void> updateCategory(Category category) async {
    await _categoriesRef.doc(category.id).update(category.toMap());
  }

  Future<void> deleteCategory(String id) async {
    await _categoriesRef.doc(id).delete();
  }

  // ============================================================
  // MENU ITEMS
  // ============================================================

  CollectionReference get _menuItemsRef => _db.collection('menu_items');

  Stream<List<MenuItem>> streamMenuItems() {
    return _menuItemsRef.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs
          .map<MenuItem>((doc) =>
              MenuItem.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  Stream<List<MenuItem>> streamMenuItemsByCategory(String categoryId) {
    return _menuItemsRef
        .where('categoryId', isEqualTo: categoryId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map<MenuItem>((doc) =>
              MenuItem.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  Future<void> addMenuItem(MenuItem item) async {
    await _menuItemsRef.add(item.toMap());
  }

  Future<void> addMenuItemWithId(MenuItem item) async {
    await _menuItemsRef.doc(item.id).set(item.toMap());
  }

  Future<void> updateMenuItem(MenuItem item) async {
    await _menuItemsRef.doc(item.id).update(item.toMap());
  }

  Future<void> deleteMenuItem(String id) async {
    await _menuItemsRef.doc(id).delete();
  }

  Future<void> toggleMenuItemAvailability(String id, bool isAvailable) async {
    await _menuItemsRef.doc(id).update({'isAvailable': isAvailable});
  }

  // ============================================================
  // TABLES
  // ============================================================

  CollectionReference get _tablesRef => _db.collection('tables');

  Stream<List<RestaurantTable>> streamTables() {
    return _tablesRef.orderBy('number').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => RestaurantTable.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  Future<void> addTable(RestaurantTable table) async {
    await _tablesRef.add(table.toMap());
  }

  Future<void> updateTableStatus(
      String id, TableStatus status, String? orderId) async {
    await _tablesRef.doc(id).update({
      'status': status.name,
      'currentOrderId': orderId,
    });
  }

  Future<void> deleteTable(String id) async {
    await _tablesRef.doc(id).delete();
  }

  Future<void> updateTable(String id, Map<String, dynamic> data) async {
    await _tablesRef.doc(id).update(data);
  }

  // ============================================================
  // ORDERS
  // ============================================================

  CollectionReference get _ordersRef => _db.collection('orders');

  Stream<List<app.Order>> streamTodayOrders() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _ordersRef
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map<app.Order>((doc) =>
              app.Order.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  Stream<List<app.Order>> streamOrders({int limit = 50}) {
    return _ordersRef
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map<app.Order>((doc) =>
              app.Order.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  Future<List<app.Order>> getOrdersByDateRange(
      DateTime start, DateTime end) async {
    final snapshot = await _ordersRef
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) =>
            app.Order.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<int> getNextOrderSequence() async {
    try {
      final snapshot = await _ordersRef
          .orderBy('sequenceNumber', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return 1;
      }

      final lastOrder = snapshot.docs.first.data() as Map<String, dynamic>;
      final lastSeq = lastOrder['sequenceNumber'] as int? ?? 0;
      return lastSeq + 1;
    } catch (e) {
      debugPrint('Error getting next sequence: $e');
      // Fallback: count documents if ordering fails
      final snapshot = await _ordersRef.get();
      return snapshot.docs.length + 1;
    }
  }

  Future<String> createOrder(app.Order order) async {
    final docRef = await _ordersRef.add(order.toMap());
    return docRef.id;
  }

  Future<void> updateOrderStatus(
      String id, app.OrderStatus status) async {
    await _ordersRef.doc(id).update({'status': status.name});
  }

  // ============================================================
  // SEEDING - Initialize default data
  // ============================================================

  Future<void> seedDefaultData() async {
    // Check if categories already exist
    final catSnapshot = await _categoriesRef.limit(1).get();
    if (catSnapshot.docs.isNotEmpty) return; // Already seeded

    final batch = _db.batch();

    // Seed categories
    for (final cat in DefaultData.categories) {
      final docRef = _categoriesRef.doc();
      batch.set(docRef, {
        ...cat,
        'createdAt': Timestamp.now(),
      });
    }

    // Seed tables
    for (int i = 1; i <= DefaultData.defaultTableCount; i++) {
      final docRef = _tablesRef.doc();
      batch.set(docRef, {
        'number': i,
        'capacity': i <= 6 ? 4 : 6,
        'status': 'available',
        'currentOrderId': null,
      });
    }

    await batch.commit();
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Future<Map<String, dynamic>> getTodayStats() async {
    return getStatsByDate(DateTime.now());
  }

  Future<Map<String, dynamic>> getStatsByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getStatsByDateRange(startOfDay, endOfDay);
  }

  Future<Map<String, dynamic>> getStatsByDateRange(DateTime start, DateTime end) async {
    final snapshot = await _ordersRef
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .get();

    final allOrders = snapshot.docs
        .map((doc) =>
            app.Order.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    final orders = allOrders.where((o) => o.status.name == 'completed').toList();

    int totalRevenue = 0;
    Map<String, int> menuCount = {};
    
    // Group by day for chart
    Map<String, int> dailyRevenue = {};

    for (final order in orders) {
      totalRevenue += order.total;
      for (final item in order.items) {
        menuCount[item.menuItemName] =
            (menuCount[item.menuItemName] ?? 0) + item.quantity;
      }
      
      final dateKey = "${order.createdAt.year}-${order.createdAt.month}-${order.createdAt.day}";
      dailyRevenue[dateKey] = (dailyRevenue[dateKey] ?? 0) + order.total;
    }

    // Sort by most popular
    final sortedMenu = menuCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Calculate chart data
    List<Map<String, dynamic>> chartData = [];
    int dayCount = end.difference(start).inDays;
    if (dayCount == 0) dayCount = 1;

    for (int i = 0; i < dayCount; i++) {
      final date = start.add(Duration(days: i));
      final key = "${date.year}-${date.month}-${date.day}";
      chartData.add({
        'date': date,
        'revenue': dailyRevenue[key] ?? 0,
      });
    }

    return {
      'totalRevenue': totalRevenue,
      'totalTransactions': orders.length,
      'averageTransaction':
          orders.isEmpty ? 0 : totalRevenue ~/ orders.length,
      'averageDailyRevenue':
          dayCount == 0 ? totalRevenue : totalRevenue ~/ dayCount,
      'topMenuItems': sortedMenu.take(5).toList(),
      'orders': allOrders,
      'chartData': chartData,
    };
  }

  Future<List<Map<String, dynamic>>> getWeeklyRevenue() async {
    final now = DateTime.now();
    List<Map<String, dynamic>> weeklyData = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _ordersRef
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      final completedDocs = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['status'] == 'completed';
      }).toList();

      int dayRevenue = 0;
      for (final doc in completedDocs) {
        dayRevenue += (doc.data() as Map<String, dynamic>)['total'] as int;
      }

      weeklyData.add({
        'date': startOfDay,
        'revenue': dayRevenue,
        'transactions': completedDocs.length,
      });
    }

    return weeklyData;
  }

  // ============================================================
  // BEST SELLER ANALYTICS
  // ============================================================

  Future<Map<String, dynamic>> getBestSellersByDateRange(
      DateTime start, DateTime end) async {
    final snapshot = await _ordersRef
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .get();

    final allOrders = snapshot.docs
        .map((doc) =>
            app.Order.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    final completedOrders =
        allOrders.where((o) => o.status.name == 'completed').toList();

    // Aggregate item data
    Map<String, Map<String, dynamic>> menuAgg = {};
    int totalItemsSold = 0;
    int totalRevenue = 0;

    for (final order in completedOrders) {
      totalRevenue += order.total;
      for (final item in order.items) {
        totalItemsSold += item.quantity;
        final key = item.menuItemName;
        if (menuAgg.containsKey(key)) {
          menuAgg[key]!['quantity'] =
              (menuAgg[key]!['quantity'] as int) + item.quantity;
          menuAgg[key]!['revenue'] =
              (menuAgg[key]!['revenue'] as int) + item.subtotal;
        } else {
          menuAgg[key] = {
            'name': item.menuItemName,
            'menuItemId': item.menuItemId,
            'quantity': item.quantity,
            'revenue': item.subtotal,
          };
        }
      }
    }

    // Sort by quantity descending
    final bestSellers = menuAgg.values.toList()
      ..sort((a, b) =>
          (b['quantity'] as int).compareTo(a['quantity'] as int));

    return {
      'bestSellers': bestSellers,
      'totalItemsSold': totalItemsSold,
      'totalRevenue': totalRevenue,
      'totalTransactions': completedOrders.length,
    };
  }

  // ============================================================
  // BILLING / SUBSCRIPTION
  // ============================================================

  Future<Map<String, dynamic>> getBillingStatus() async {
    try {
      final doc = await _db.collection('app_settings').doc('billing').get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error getting billing status: $e');
    }
    return {};
  }

  Stream<List<Map<String, dynamic>>> streamBillingHistory() {
    return _db
        .collection('billing_history')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    });
  }

  Future<void> addBillingRecordIfNotExist(Map<String, dynamic> data, String docId) async {
    final docRef = _db.collection('billing_history').doc(docId);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> updateBillingStatus(int month, int year) async {
    await _db.collection('app_settings').doc('billing').set({
      'lastPaidMonth': month,
      'lastPaidYear': year,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ============================================================
  // APP VERSION (UPDATE NOTIFICATION)
  // ============================================================

  /// Mendapatkan info versi terbaru dari Firestore
  Future<Map<String, dynamic>> getAppVersionInfo() async {
    try {
      final doc = await _db.collection('app_settings').doc('app_version').get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error getting app version info: $e');
    }
    return {};
  }

  /// Update info versi terbaru (untuk admin)
  Future<void> setAppVersionInfo({
    required String latestVersion,
    String? downloadUrl,
    String? message,
    bool forceUpdate = false,
  }) async {
    await _db.collection('app_settings').doc('app_version').set({
      'latestVersion': latestVersion,
      'downloadUrl': downloadUrl ?? '',
      'message': message ?? '',
      'forceUpdate': forceUpdate,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // WIFI INFO
  // ============================================================

  Future<Map<String, dynamic>> getWifiInfo() async {
    try {
      final doc = await _db.collection('app_settings').doc('wifi').get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error getting WiFi info: $e');
    }
    return {
      'ssid': 'Dapoer_MNH',
      'password': 'Tinggalnyambungkak',
    };
  }

  Future<void> updateWifiInfo(String ssid, String password) async {
    try {
      await _db.collection('app_settings').doc('wifi').set({
        'ssid': ssid,
        'password': password,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating WiFi info: $e');
      rethrow;
    }
  }

  // ============================================================
  // EXPENSES (BELANJA)
  // ============================================================

  CollectionReference get _expensesRef => _db.collection('expenses');

  Stream<List<Map<String, dynamic>>> streamTodayExpenses() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _expensesRef
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
          .toList();
    });
  }

  Future<void> addExpense(Map<String, dynamic> expenseData) async {
    await _expensesRef.add({
      ...expenseData,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteExpense(String id) async {
    await _expensesRef.doc(id).delete();
  }

  Future<List<Map<String, dynamic>>> getExpensesByDateRange(
      DateTime start, DateTime end) async {
    final query = await _expensesRef
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .get();

    return query.docs
        .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
        .toList();
  }

  // ============================================================
  // STARTING CASH (MODAL AWAL)
  // ============================================================

  Future<int> getStartingCash(DateTime date) async {
    final dateStr = "${date.year}-${date.month}-${date.day}";
    final doc = await _db.collection('starting_cash').doc(dateStr).get();
    if (doc.exists) {
      return (doc.data() as Map<String, dynamic>)['amount'] ?? 0;
    }
    return 0;
  }

  Future<void> setStartingCash(DateTime date, int amount) async {
    final dateStr = "${date.year}-${date.month}-${date.day}";
    await _db.collection('starting_cash').doc(dateStr).set({
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // SALARY / GAJI KARYAWAN
  // ============================================================

  /// Count unique working days for a cashier in a date range
  Future<Map<String, dynamic>> getWorkingDays(
      String cashierName, DateTime start, DateTime end) async {
    final snapshot = await _ordersRef
        .where('cashierName', isEqualTo: cashierName)
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .get();

    final completedOrders = snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['status'] == 'completed';
    }).toList();

    // Count unique days
    Set<String> uniqueDays = {};
    for (final doc in completedOrders) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = data['createdAt'] as Timestamp;
      final date = ts.toDate();
      uniqueDays.add("${date.year}-${date.month}-${date.day}");
    }

    return {
      'workingDays': uniqueDays.length,
      'totalTransactions': completedOrders.length,
      'dates': uniqueDays.toList(),
    };
  }

  /// Get all unique cashier names from orders
  Future<List<String>> getAllCashierNames() async {
    final snapshot = await _ordersRef
        .where('status', isEqualTo: 'completed')
        .get();

    Set<String> names = {};
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data['cashierName'] as String?;
      if (name != null && name.isNotEmpty) {
        names.add(name);
      }
    }
    return names.toList()..sort();
  }

  /// Save a salary payment record
  Future<void> addSalaryPayment(Map<String, dynamic> data) async {
    await _db.collection('salary_payments').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream salary payments
  Stream<List<Map<String, dynamic>>> streamSalaryPayments() {
    return _db
        .collection('salary_payments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    });
  }

  /// Delete salary payment
  Future<void> deleteSalaryPayment(String id) async {
    await _db.collection('salary_payments').doc(id).delete();
  }
}
