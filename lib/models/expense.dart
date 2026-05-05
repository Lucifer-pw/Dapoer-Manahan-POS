import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String name;
  final double qty;
  final int price;
  final int total;
  final DateTime date;

  Expense({
    required this.id,
    required this.name,
    required this.qty,
    required this.price,
    required this.total,
    required this.date,
  });

  factory Expense.fromMap(Map<String, dynamic> map, String id) {
    return Expense(
      id: id,
      name: map['name'] ?? '',
      qty: (map['qty'] ?? 0).toDouble(),
      price: map['price'] ?? 0,
      total: map['total'] ?? 0,
      date: (map['date'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'qty': qty,
      'price': price,
      'total': total,
      'date': Timestamp.fromDate(date),
    };
  }
}
