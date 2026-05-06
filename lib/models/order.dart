import 'package:cloud_firestore/cloud_firestore.dart';
import 'order_item.dart';

enum OrderStatus { pending, completed, cancelled }

class Order {
  final String id;
  final int tableNumber;
  final String cashierName;
  final String cashierId;
  final List<OrderItem> items;
  final int subtotal;
  final int tax;
  final int total;
  final String paymentMethod;
  final int amountPaid;
  final int change;
  final OrderStatus status;
  final DateTime createdAt;
  final int sequenceNumber; // New: for sequential order numbers

  Order({
    required this.id,
    required this.tableNumber,
    required this.cashierName,
    required this.cashierId,
    required this.items,
    required this.subtotal,
    this.tax = 0,
    required this.total,
    this.paymentMethod = 'Tunai',
    this.amountPaid = 0,
    this.change = 0,
    this.status = OrderStatus.pending,
    DateTime? createdAt,
    this.sequenceNumber = 0, // Default to 0
  }) : createdAt = createdAt ?? DateTime.now();

  factory Order.fromMap(Map<String, dynamic> map, String docId) {
    return Order(
      id: docId,
      tableNumber: map['tableNumber'] ?? 0,
      cashierName: map['cashierName'] ?? '',
      cashierId: map['cashierId'] ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: map['subtotal'] ?? 0,
      tax: map['tax'] ?? 0,
      total: map['total'] ?? 0,
      paymentMethod: map['paymentMethod'] ?? 'Tunai',
      amountPaid: map['amountPaid'] ?? 0,
      change: map['change'] ?? 0,
      status: OrderStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'pending'),
        orElse: () => OrderStatus.pending,
      ),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      sequenceNumber: map['sequenceNumber'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tableNumber': tableNumber,
      'cashierName': cashierName,
      'cashierId': cashierId,
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'paymentMethod': paymentMethod,
      'amountPaid': amountPaid,
      'change': change,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'sequenceNumber': sequenceNumber,
    };
  }

  // Changed: Use sequenceNumber if available, otherwise fallback to ID
  String get orderNumber => sequenceNumber > 0 ? 'DM-$sequenceNumber' : 'DM-${id.substring(0, 8).toUpperCase()}';
  
  // Method to create a copy with a sequence number
  Order withSequenceNumber(int seq) {
    return Order(
      id: id,
      tableNumber: tableNumber,
      cashierName: cashierName,
      cashierId: cashierId,
      items: items,
      subtotal: subtotal,
      tax: tax,
      total: total,
      paymentMethod: paymentMethod,
      amountPaid: amountPaid,
      change: change,
      status: status,
      createdAt: createdAt,
      sequenceNumber: seq,
    );
  }
}
