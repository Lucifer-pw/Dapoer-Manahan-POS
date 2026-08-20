import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/billing_record.dart';
import '../services/firestore_service.dart';

enum SubscriptionStatus { active, warning, blocked }

class SubscriptionProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  SubscriptionStatus _status = SubscriptionStatus.active;
  bool _isLoading = true;
  List<BillingRecord> _history = [];
  DateTime? _activeUntil;
  int _lastPaidMonth = 0;
  int _lastPaidYear = 0;

  SubscriptionStatus get status => _status;
  bool get isLoading => _isLoading;
  List<BillingRecord> get history => _history;
  DateTime? get activeUntil => _activeUntil;
  int get lastPaidMonth => _lastPaidMonth;
  int get lastPaidYear => _lastPaidYear;

  DateTime? get effectiveExpiryDate {
    if (_activeUntil != null) return _activeUntil;
    if (_lastPaidMonth > 0 && _lastPaidYear > 0) {
      return DateTime(_lastPaidYear, _lastPaidMonth + 1, 0, 23, 59, 59);
    }
    return null;
  }

  int get remainingDays {
    final expiry = effectiveExpiryDate;
    if (expiry == null) return 0;
    final now = DateTime.now();
    if (expiry.isBefore(now)) return 0;
    final diff = expiry.difference(now);
    final days = diff.inDays;
    return (days == 0 && diff.inHours > 0) ? 1 : days;
  }

  SubscriptionProvider() {
    _initHistoryStream();
    checkStatus();
  }
  void _initHistoryStream() {
    _firestoreService.streamBillingHistory().listen((data) {
      _history =
          data.map((item) => BillingRecord.fromMap(item, item['id'])).toList();
      notifyListeners();
    });
  }

  Future<void> checkStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _firestoreService.getBillingStatus();
      final now = DateTime.now();

      // Mengambil data dengan konversi yang lebih aman (mendukung string atau int dari Firebase)
      int lastPaidMonth = 0;
      int lastPaidYear = 0;

      if (data['lastPaidMonth'] != null) {
        lastPaidMonth = data['lastPaidMonth'] is int
            ? data['lastPaidMonth']
            : int.tryParse(data['lastPaidMonth'].toString()) ?? 0;
      }

      if (data['lastPaidYear'] != null) {
        lastPaidYear = data['lastPaidYear'] is int
            ? data['lastPaidYear']
            : int.tryParse(data['lastPaidYear'].toString()) ?? 0;
      }

      final activeUntilTs = data['activeUntil'] as Timestamp?;
      final activeUntil = activeUntilTs?.toDate();

      _lastPaidMonth = lastPaidMonth;
      _lastPaidYear = lastPaidYear;
      _activeUntil = activeUntil;

      final isPaidByMonthYear = (lastPaidYear > now.year) ||
          (lastPaidYear == now.year && lastPaidMonth >= now.month);
      final isPaidByExpiry = activeUntil != null && now.isBefore(activeUntil);

      if (isPaidByMonthYear || isPaidByExpiry) {
        _status = SubscriptionStatus.active;

        final month = lastPaidMonth > 0 ? lastPaidMonth : now.month;
        final year = lastPaidYear > 0 ? lastPaidYear : now.year;
        final recordId =
            'pay_${year}_${month.toString().padLeft(2, '0')}';
        await _firestoreService.addBillingRecordIfNotExist({
          'amount': 50000,
          'date': Timestamp.now(),
          'month': month,
          'year': year,
          'status': 'Lunas',
        }, recordId);
      } else {
        if (now.day >= 4 && now.day <= 5) {
          _status = SubscriptionStatus.warning;
        } else if (now.day > 5) {
          _status = SubscriptionStatus.blocked;
        } else {
          _status = SubscriptionStatus.active;
        }
      }
    } catch (e) {
      debugPrint('Error checking subscription: $e');
      _status = SubscriptionStatus.active; // Fail safe
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
