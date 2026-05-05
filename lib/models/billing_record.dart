import 'package:cloud_firestore/cloud_firestore.dart';

class BillingRecord {
  final String id;
  final DateTime date;
  final int amount;
  final String status; // e.g., 'Paid', 'Pending'
  final int month;
  final int year;

  BillingRecord({
    required this.id,
    required this.date,
    required this.amount,
    required this.status,
    required this.month,
    required this.year,
  });

  factory BillingRecord.fromMap(Map<String, dynamic> map, String id) {
    return BillingRecord(
      id: id,
      date: (map['date'] as Timestamp).toDate(),
      amount: map['amount'] ?? 0,
      status: map['status'] ?? 'unknown',
      month: map['month'] ?? 0,
      year: map['year'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'amount': amount,
      'status': status,
      'month': month,
      'year': year,
    };
  }
}
