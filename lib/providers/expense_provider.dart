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

  int get dailyTotal => _todayExpenses.fold(0, (sum, e) => sum + e.price);

  void init() {
    _expensesSub = _firestoreService.streamTodayExpenses().listen((data) {
      _todayExpenses = data.map((item) => Expense.fromMap(item, item['id'])).toList();
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addExpense({
    required String name,
    required String unit,
    required int price,
  }) async {
    await _firestoreService.addExpense({
      'name': name,
      'unit': unit,
      'price': price,
      'date': DateTime.now(),
    });
  }

  Future<void> deleteExpense(String id) async {
    await _firestoreService.deleteExpense(id);
  }

  Future<List<Expense>> getExpensesByDateRange(DateTime start, DateTime end) async {
    final data = await _firestoreService.getExpensesByDateRange(start, end);
    return data.map((item) => Expense.fromMap(item, item['id'])).toList();
  }

  @override
  void dispose() {
    _expensesSub?.cancel();
    super.dispose();
  }
}
