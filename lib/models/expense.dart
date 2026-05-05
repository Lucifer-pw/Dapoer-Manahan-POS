import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String name;
  final String unit; // e.g. "5 Kg", "10 Pcs"
  final int price;
  final DateTime date;

  Expense({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.date,
  });

  factory Expense.fromMap(Map<String, dynamic> map, String id) {
    return Expense(
      id: id,
      name: map['name'] ?? '',
      unit: map['unit'] ?? '',
      price: map['price'] ?? 0,
      date: (map['date'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'unit': unit,
      'price': price,
      'date': Timestamp.fromDate(date),
    };
  }
}
