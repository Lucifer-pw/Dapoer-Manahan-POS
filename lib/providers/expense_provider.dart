import 'dart:async';
import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../services/firestore_service.dart';

class ExpenseProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<Expense> _todayExpenses = [];
  bool _isLoading = true;
  StreamSubscription? _expensesSub;

  List<Expense> get todayExpenses => _todayExpenses;
  bool get isLoading => _isLoading;

  int get dailyTotal => _todayExpenses.fold(0, (sum, e) => sum + e.total);

  void init() {
    _expensesSub = _firestoreService.streamTodayExpenses().listen((data) {
      _todayExpenses = data.map((item) => Expense.fromMap(item, item['id'])).toList();
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addExpense({
    required String name,
    required double qty,
    required int price,
  }) async {
    final total = (qty * price).toInt();
    await _firestoreService.addExpense({
      'name': name,
      'qty': qty,
      'price': price,
      'total': total,
      'date': DateTime.now(),
    });
  }

  Future<void> deleteExpense(String id) async {
    await _firestoreService.deleteExpense(id);
  }

  @override
  void dispose() {
    _expensesSub?.cancel();
    super.dispose();
  }
}
