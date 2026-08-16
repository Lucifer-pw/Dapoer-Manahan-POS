import 'package:flutter/foundation.dart' hide Category;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category.dart';
import '../models/menu_item.dart';
import '../models/order.dart' as app;
import '../models/table_model.dart';
import '../utils/constants.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final Set<String> _syncingQrOrders = {};

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

  Stream<List<app.Order>> streamOrdersByTable(int tableNumber) {
    return _ordersRef
        .where('tableNumber', isEqualTo: tableNumber)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map<app.Order>((doc) =>
              app.Order.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      // Urutkan di memori untuk menghindari keharusan indeks komposit Firestore
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
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
        'qrUrl': 'https://pos-dapoer-manahan.web.app/table/$i',
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
  // CCTV SETTINGS
  // ============================================================

  Future<Map<String, dynamic>> getCctvSettings() async {
    try {
      final doc = await _db.collection('app_settings').doc('cctv').get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error getting CCTV settings: $e');
    }
    return {
      'alias': 'umkssig5d5vu',
      'platform': 'IPCamLive',
      'type': 'ipcamlive', // 'ipcamlive' atau 'xmeye_p2p' atau 'custom'
      'customUrl': '',
    };
  }

  Future<void> updateCctvSettings(Map<String, dynamic> cctvData) async {
    try {
      await _db.collection('app_settings').doc('cctv').set({
        ...cctvData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating CCTV settings: $e');
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

  Future<void> setStartingCash(DateTime date, int amount, {String? cashierName, String? shift}) async {
    final dateStr = "${date.year}-${date.month}-${date.day}";
    await _db.collection('starting_cash').doc(dateStr).set({
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'updatedAt': FieldValue.serverTimestamp(),
      if (cashierName != null) 'cashierName': cashierName,
      if (shift != null) 'shift': shift,
    }, SetOptions(merge: true));
  }

  // ============================================================
  // SALARY / GAJI KARYAWAN & LOG SHIFT
  // ============================================================

  /// Start a new shift log when cashier selects a shift
  Future<String> startShiftLog({
    required String cashierName,
    String? userId,
    required String shift,
    required int startingCash,
    required DateTime date,
  }) async {
    final dayStr = "${date.year}-${date.month}-${date.day}";
    final docRef = _db.collection('shift_logs').doc();

    await docRef.set({
      'cashierName': cashierName,
      'userId': userId ?? '',
      'shift': shift,
      'startingCash': startingCash,
      'date': dayStr,
      'month': date.month,
      'year': date.year,
      'startTime': FieldValue.serverTimestamp(),
      'endTime': null,
      'closingCash': null,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Close an active shift log with end time and closing cash
  Future<void> closeShiftLog({
    String? shiftLogId,
    required String cashierName,
    required int closingCash,
    DateTime? date,
  }) async {
    try {
      if (shiftLogId != null && shiftLogId.isNotEmpty) {
        await _db.collection('shift_logs').doc(shiftLogId).update({
          'endTime': FieldValue.serverTimestamp(),
          'closingCash': closingCash,
          'status': 'closed',
        });
      } else {
        // Fallback: find active shift for this cashier today
        final today = date ?? DateTime.now();
        final dayStr = "${today.year}-${today.month}-${today.day}";
        final snap = await _db
            .collection('shift_logs')
            .where('cashierName', isEqualTo: cashierName)
            .where('date', isEqualTo: dayStr)
            .where('status', isEqualTo: 'active')
            .limit(1)
            .get();

        if (snap.docs.isNotEmpty) {
          await snap.docs.first.reference.update({
            'endTime': FieldValue.serverTimestamp(),
            'closingCash': closingCash,
            'status': 'closed',
          });
        }
      }
    } catch (e) {
      debugPrint('Error closing shift log: $e');
    }
  }

  /// Get all shift logs for a cashier in a specific month & year
  Future<List<Map<String, dynamic>>> getShiftLogsForMonth(
    String cashierName,
    int month,
    int year,
  ) async {
    try {
      final snap = await _db
          .collection('shift_logs')
          .where('cashierName', isEqualTo: cashierName)
          .where('year', isEqualTo: year)
          .where('month', isEqualTo: month)
          .get();

      final list = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();

      list.sort((a, b) {
        final tA = a['startTime'] as Timestamp?;
        final tB = b['startTime'] as Timestamp?;
        if (tA == null || tB == null) return 0;
        return tA.compareTo(tB);
      });

      return list;
    } catch (e) {
      debugPrint('Error getting shift logs: $e');
      return [];
    }
  }

  /// Record a working day for a cashier (called when shift starts or order is completed)
  /// Uses Firestore document per cashier per month for O(1) reads
  Future<void> recordWorkingDay(
    String cashierName,
    DateTime date, {
    String? shift,
    String? shiftLogId,
    DateTime? startTime,
    int? startingCash,
  }) async {
    final month = date.month;
    final year = date.year;
    final dayStr = "${date.year}-${date.month}-${date.day}";
    final docId = "${cashierName}_${year}_$month";

    final docRef = _db.collection('attendance').doc(docId);
    
    await _db.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      
      if (doc.exists) {
        final data = doc.data()!;
        final dates = List<String>.from(data['dates'] ?? []);
        if (!dates.contains(dayStr)) {
          dates.add(dayStr);
          transaction.update(docRef, {
            'days': dates.length,
            'dates': dates,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
        // Also increment transaction count
        transaction.update(docRef, {
          'totalTransactions': (data['totalTransactions'] ?? 0) + 1,
        });
      } else {
        transaction.set(docRef, {
          'cashierName': cashierName,
          'month': month,
          'year': year,
          'days': 1,
          'dates': [dayStr],
          'totalTransactions': 1,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// Get working days from pre-computed attendance doc (instant - reads 1 doc)
  Future<Map<String, dynamic>> getWorkingDaysFast(
      String cashierName, int month, int year) async {
    final docId = "${cashierName}_${year}_$month";
    final doc = await _db.collection('attendance').doc(docId).get();

    if (doc.exists) {
      final data = doc.data()!;
      return {
        'workingDays': data['days'] ?? 0,
        'totalTransactions': data['totalTransactions'] ?? 0,
        'dates': List<String>.from(data['dates'] ?? []),
      };
    }
    return {'workingDays': 0, 'totalTransactions': 0, 'dates': []};
  }

  /// Fallback: Count working days by scanning orders (used for initial sync)
  Future<Map<String, dynamic>> getWorkingDays(
      String cashierName, DateTime start, DateTime end) async {
    // Try fast path first
    final fast = await getWorkingDaysFast(
        cashierName, start.month, start.year);
    if ((fast['workingDays'] as int) > 0) return fast;

    // Fallback: scan orders and build attendance doc
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

    Set<String> uniqueDays = {};
    for (final doc in completedOrders) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = data['createdAt'] as Timestamp;
      final date = ts.toDate();
      uniqueDays.add("${date.year}-${date.month}-${date.day}");
    }

    // Save to attendance doc so next time it's instant
    if (uniqueDays.isNotEmpty) {
      final docId = "${cashierName}_${start.year}_${start.month}";
      await _db.collection('attendance').doc(docId).set({
        'cashierName': cashierName,
        'month': start.month,
        'year': start.year,
        'days': uniqueDays.length,
        'dates': uniqueDays.toList(),
        'totalTransactions': completedOrders.length,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }

    return {
      'workingDays': uniqueDays.length,
      'totalTransactions': completedOrders.length,
      'dates': uniqueDays.toList(),
    };
  }

  /// Get all unique cashier and admin employee names (excluding owner)
  Future<List<String>> getAllCashierNames() async {
    try {
      // Fast path: read from users collection (only non-owner users)
      final usersSnapshot = await _db.collection('users').get();
      Set<String> names = {};
      Set<String> ownerNames = {};

      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        final role = (data['role'] as String? ?? 'kasir').trim().toLowerCase();
        final name = data['name'] as String?;
        if (name != null && name.isNotEmpty) {
          if (role == 'owner') {
            ownerNames.add(name);
          } else {
            names.add(name);
          }
        }
      }
      if (names.isNotEmpty) return names.toList()..sort();
    } catch (e) {
      debugPrint('Fallback to orders for cashier names: $e');
    }

    // Fallback: scan recent orders (limited)
    final snapshot = await _ordersRef
        .orderBy('createdAt', descending: true)
        .limit(200)
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

  Future<Map<String, dynamic>> getCashierBankDetails(String cashierName) async {
    try {
      final snapshot = await _db.collection('users').where('name', isEqualTo: cashierName).limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        return {
          'bankName': data['bankName'] as String? ?? '',
          'bankAccountNumber': data['bankAccountNumber'] as String? ?? '',
          'bankAccountName': data['bankAccountName'] as String? ?? '',
          'email': data['email'] as String? ?? '',
          'ratePerDay': data['ratePerDay'] as int? ?? 50000,
        };
      }
    } catch (e) {
      debugPrint('Error getting cashier bank details: $e');
    }
    return {
      'bankName': '',
      'bankAccountNumber': '',
      'bankAccountName': '',
      'email': '',
      'ratePerDay': 50000,
    };
  }

  Future<void> updateCashierRate(String cashierName, int rate) async {
    try {
      final snapshot = await _db.collection('users').where('name', isEqualTo: cashierName).limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({'ratePerDay': rate});
      }
    } catch (e) {
      debugPrint('Error updating cashier rate: $e');
      rethrow;
    }
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

  /// Get total paid amount for a specific cashier in a month/year
  Future<int> getTotalPaidForCashier(
      String cashierName, int month, int year) async {
    final snapshot = await _db
        .collection('salary_payments')
        .where('cashierName', isEqualTo: cashierName)
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .get();

    int total = 0;
    for (final doc in snapshot.docs) {
      total += (doc.data()['nominal'] as int? ?? 0);
    }
    return total;
  }

  // ============================================================
  // QR ORDERS (SELF SERVICE)
  // ============================================================

  Stream<List<Map<String, dynamic>>> streamPendingQrOrders() {
    return _db.collection('qr_orders')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    });
  }

  Stream<List<Map<String, dynamic>>> streamActiveQrOrders() {
    return _db.collection('qr_orders')
        .where('status', whereIn: ['pending', 'accepted', 'delivered'])
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    });
  }

  Future<void> updateQrOrderStatus(String orderId, String status, {String? cashierName, String? cashierId}) async {
    await _db.collection('qr_orders').doc(orderId).update({'status': status});
    await syncQrOrderToCompletedOrders(orderId, cashierName: cashierName, cashierId: cashierId);
  }

  Future<void> updateQrOrderPaymentStatus(String orderId, String paymentStatus, {String? cashierName, String? cashierId}) async {
    await _db.collection('qr_orders').doc(orderId).update({'paymentStatus': paymentStatus});
    await syncQrOrderToCompletedOrders(orderId, cashierName: cashierName, cashierId: cashierId);
  }

  Future<void> finalizeQrOrdersForTable(int tableNumber) async {
    try {
      final querySnapshot = await _db.collection('qr_orders')
          .where('status', whereIn: ['pending', 'accepted', 'delivered'])
          .get();

      final batch = _db.batch();
      bool hasUpdates = false;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final tNum = data['tableNumber'];
        if (tNum?.toString() == tableNumber.toString()) {
          batch.update(doc.reference, {
            'status': 'completed',
            'paymentStatus': 'sudah_bayar',
          });
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error finalizing QR orders for table $tableNumber: $e');
    }
  }


  Future<void> syncQrOrderToCompletedOrders(String qrOrderId, {String? cashierName, String? cashierId}) async {
    if (qrOrderId.isEmpty) return;

    // Synchronously check and lock this qrOrderId to prevent concurrent sync operations (race condition)
    if (_syncingQrOrders.contains(qrOrderId)) {
      return;
    }
    _syncingQrOrders.add(qrOrderId);

    try {
      final qrDocRef = _db.collection('qr_orders').doc(qrOrderId);
      final doc = await qrDocRef.get();
      if (!doc.exists) {
        _syncingQrOrders.remove(qrOrderId);
        return;
      }

      final data = doc.data()!;
      final String status = data['status'] as String? ?? 'pending';
      final String paymentStatus = data['paymentStatus'] as String? ?? 'belum_bayar';

      // If the QR order has already been finalized, nothing to do
      if (data['status'] == 'completed') {
        _syncingQrOrders.remove(qrOrderId);
        return;
      }

      // Check if order was already synced to 'orders' collection previously
      final bool alreadySynced = data['orderDocId'] != null;

      final bool isDelivered = status == 'delivered';
      final bool isFullyComplete = isDelivered && paymentStatus == 'sudah_bayar';

      if (alreadySynced) {
        // Order already exists in 'orders' collection — do NOT create another one.
        // But if both delivered AND paid, finalize the QR order to 'completed' so it
        // disappears from the active list.
        if (isFullyComplete) {
          await qrDocRef.update({'status': 'completed'});
        }
        return;
      }

      // First-time sync: only create the order in 'orders' collection when FULLY complete (delivered + paid)
      if (isFullyComplete) {
        // 1. Get next sequence number
        final int seqNum = await getNextOrderSequence();

        // 2. Parse items
        final List<dynamic> rawItems = data['items'] as List<dynamic>? ?? [];
        final List<Map<String, dynamic>> orderItemsMaps = rawItems.map((elem) {
          final Map<String, dynamic> itemMap = Map<String, dynamic>.from(elem);
          final String itemId = itemMap['menuItemId'] ?? itemMap['id'] ?? '';
          final String itemName = itemMap['menuItemName'] ?? itemMap['name'] ?? '';
          final int qty = _toInt(itemMap['quantity'], fallback: 1);
          final int price = _toInt(itemMap['price']);
          final String? variant = itemMap['variant'];
          final String notes = itemMap['notes'] ?? '';
          
          return {
            'menuItemId': itemId,
            'menuItemName': itemName,
            'quantity': qty,
            'price': price,
            'notes': notes,
            'variant': variant,
            'isBonus': itemMap['isBonus'] ?? false,
            'categoryId': itemMap['categoryId'],
          };
        }).toList();

        final int totalPrice = _toInt(data['totalPrice'] ?? data['total']);

        // 3. Create Order map for 'orders' collection
        final Map<String, dynamic> completedOrderMap = {
          'tableNumber': _toInt(data['tableNumber']),
          'cashierName': cashierName ?? 'Self-Service QR',
          'cashierId': cashierId ?? 'self_service_qr',
          'items': orderItemsMaps,
          'subtotal': totalPrice,
          'tax': 0,
          'total': totalPrice,
          'paymentMethod': data['paymentMethod'] ?? 'QRIS',
          'amountPaid': totalPrice,
          'change': 0,
          'status': 'completed',
          'isTakeAway': false,
          'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
          'sequenceNumber': seqNum,
        };

        // 4. Write to 'orders' collection
        final orderDocRef = await _ordersRef.add(completedOrderMap);

        // 5. Save the order doc ID and optionally finalize status
        // Only set status to 'completed' if BOTH delivered AND paid.
        // Otherwise keep the current status so the order stays active for further actions (e.g. mark paid).
        final Map<String, dynamic> updateData = {
          'orderDocId': orderDocRef.id,
        };
        if (isFullyComplete) {
          updateData['status'] = 'completed';
        }
        await qrDocRef.update(updateData);
      }
    } catch (e) {
      debugPrint('Error syncing QR order to completed: $e');
    } finally {
      // Always remove the lock when finished
      _syncingQrOrders.remove(qrOrderId);
    }
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  Future<void> createQrOrder(Map<String, dynamic> orderData) async {
    await _db.collection('qr_orders').add(orderData);
  }

  Stream<List<Map<String, dynamic>>> streamQrOrdersByTable(String tableNumber) {
    return _db.collection('qr_orders')
        .where('tableNumber', isEqualTo: tableNumber)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
      
      // Urutkan di memori untuk menghindari keharusan indeks komposit Firestore
      list.sort((a, b) {
        final aTime = a['createdAt'];
        final bTime = b['createdAt'];
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        
        DateTime aDate;
        if (aTime is Timestamp) {
          aDate = aTime.toDate();
        } else if (aTime is DateTime) {
          aDate = aTime;
        } else {
          aDate = DateTime.tryParse(aTime.toString()) ?? DateTime.now();
        }

        DateTime bDate;
        if (bTime is Timestamp) {
          bDate = bTime.toDate();
        } else if (bTime is DateTime) {
          bDate = bTime;
        } else {
          bDate = DateTime.tryParse(bTime.toString()) ?? DateTime.now();
        }

        return bDate.compareTo(aDate); // Descending (terbaru di atas)
      });
      return list;
    });
  }

  Stream<List<app.Order>> streamTodayOrdersByTable(int tableNumber) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    return _ordersRef
        .where('tableNumber', isEqualTo: tableNumber)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map<app.Order>((doc) =>
              app.Order.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      
      // Filter hari ini dan urutkan di memori
      final todayOrders = list.where((o) => o.createdAt.isAfter(startOfDay)).toList();
      todayOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return todayOrders;
    });
  }

  // ============================================================
  // QRIS IMAGE MANAGEMENT
  // ============================================================

  /// Add a new QRIS image record
  Future<String> addQrisImage(String label, String imageUrl) async {
    final docRef = await _db.collection('qris_images').add({
      'label': label,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Delete a QRIS image record and its storage file
  Future<void> deleteQrisImage(String docId) async {
    await _db.collection('qris_images').doc(docId).delete();
  }

  /// Stream all uploaded QRIS images
  Stream<List<Map<String, dynamic>>> streamQrisImages() {
    return _db.collection('qris_images')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    });
  }

  /// Set a QRIS image as the active one for a given target ('customer' or 'cashier')
  Future<void> setActiveQris(String target, String docId, String label, String imageUrl) async {
    await _db.collection('app_settings').doc('qris_config').set({
      target: {
        'id': docId,
        'label': label,
        'imageUrl': imageUrl,
      },
    }, SetOptions(merge: true));
  }

  /// Get active QRIS config (one-time)
  Future<Map<String, dynamic>> getActiveQrisConfig() async {
    try {
      final doc = await _db.collection('app_settings').doc('qris_config').get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error getting QRIS config: $e');
    }
    return {};
  }

  /// Stream active QRIS config (realtime)
  Stream<Map<String, dynamic>> streamActiveQrisConfig() {
    return _db.collection('app_settings').doc('qris_config')
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return <String, dynamic>{};
    });
  }

  // ============================================================
  // TABLE CHATS
  // ============================================================

  Stream<List<Map<String, dynamic>>> streamTableMessages(String tableNumber) {
    return _db.collection('chats')
        .where('tableNumber', isEqualTo: tableNumber)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();

      // Sort in-memory to bypass Firestore composite index requirement
      list.sort((a, b) {
        final aTime = a['timestamp'];
        final bTime = b['timestamp'];

        DateTime aDate;
        if (aTime == null) {
          aDate = DateTime.now();
        } else if (aTime is Timestamp) {
          aDate = aTime.toDate();
        } else if (aTime is int) {
          aDate = DateTime.fromMillisecondsSinceEpoch(aTime);
        } else if (aTime is DateTime) {
          aDate = aTime;
        } else {
          aDate = DateTime.tryParse(aTime.toString()) ?? DateTime.now();
        }

        DateTime bDate;
        if (bTime == null) {
          bDate = DateTime.now();
        } else if (bTime is Timestamp) {
          bDate = bTime.toDate();
        } else if (bTime is int) {
          bDate = DateTime.fromMillisecondsSinceEpoch(bTime);
        } else if (bTime is DateTime) {
          bDate = bTime;
        } else {
          bDate = DateTime.tryParse(bTime.toString()) ?? DateTime.now();
        }

        return aDate.compareTo(bDate);
      });

      return list;
    });
  }

  Stream<List<Map<String, dynamic>>> streamAllUnreadMessages() {
    return _db.collection('chats')
        .where('sender', isEqualTo: 'customer')
        .where('isReadByAdmin', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    });
  }

  Stream<List<Map<String, dynamic>>> streamCustomerUnreadMessages(String tableNumber) {
    return _db.collection('chats')
        .where('tableNumber', isEqualTo: tableNumber)
        .where('sender', isEqualTo: 'admin')
        .where('isReadByCustomer', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    });
  }

  Future<void> sendChatMessage(String tableNumber, String sender, String messageText) async {
    await _db.collection('chats').add({
      'tableNumber': tableNumber,
      'sender': sender,
      'message': messageText,
      'timestamp': FieldValue.serverTimestamp(),
      'isReadByAdmin': sender == 'admin',
      'isReadByCustomer': sender == 'customer',
    });
  }

  Future<void> markMessagesAsReadByAdmin(String tableNumber) async {
    final query = await _db.collection('chats')
        .where('tableNumber', isEqualTo: tableNumber)
        .where('sender', isEqualTo: 'customer')
        .where('isReadByAdmin', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final doc in query.docs) {
      batch.update(doc.reference, {'isReadByAdmin': true});
    }
    await batch.commit();
  }

  Future<void> markMessagesAsReadByCustomer(String tableNumber) async {
    final query = await _db.collection('chats')
        .where('tableNumber', isEqualTo: tableNumber)
        .where('sender', isEqualTo: 'admin')
        .where('isReadByCustomer', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final doc in query.docs) {
      batch.update(doc.reference, {'isReadByCustomer': true});
    }
    await batch.commit();
  }

  Future<void> clearTableMessages(String tableNumber) async {
    final query = await _db.collection('chats')
        .where('tableNumber', isEqualTo: tableNumber)
        .get();

    final batch = _db.batch();
    for (final doc in query.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ============================================================
  // USER PRESENCE
  // ============================================================

  Stream<List<Map<String, dynamic>>> streamUsers() {
    return _db.collection('users').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
          .toList();
    });
  }
}
