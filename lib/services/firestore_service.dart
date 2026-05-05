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

    final snapshot = await _ordersRef
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    final allOrders = snapshot.docs
        .map((doc) =>
            app.Order.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    final orders = allOrders.where((o) => o.status.name == 'completed').toList();

    int totalRevenue = 0;
    Map<String, int> menuCount = {};

    for (final order in orders) {
      totalRevenue += order.total;
      for (final item in order.items) {
        menuCount[item.menuItemName] =
            (menuCount[item.menuItemName] ?? 0) + item.quantity;
      }
    }

    // Sort by most popular
    final sortedMenu = menuCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'totalRevenue': totalRevenue,
      'totalTransactions': orders.length,
      'averageTransaction':
          orders.isEmpty ? 0 : totalRevenue ~/ orders.length,
      'topMenuItems': sortedMenu.take(5).toList(),
      'orders': allOrders, // Include orders for history summary
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
}
