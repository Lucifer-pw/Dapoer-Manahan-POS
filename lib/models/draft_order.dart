import 'order_item.dart';

class DraftOrder {
  final String id;
  final String customerName;
  final int? tableNumber;
  final bool isTakeAway;
  final List<OrderItem> items;
  final DateTime createdAt;

  DraftOrder({
    required this.id,
    required this.customerName,
    this.tableNumber,
    this.isTakeAway = false,
    required this.items,
    required this.createdAt,
  });

  int get total => items.fold(0, (sum, item) => sum + item.subtotal);
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerName': customerName,
      'tableNumber': tableNumber,
      'isTakeAway': isTakeAway,
      'items': items.map((x) => x.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DraftOrder.fromMap(Map<String, dynamic> map) {
    return DraftOrder(
      id: map['id'] ?? '',
      customerName: map['customerName'] ?? '',
      tableNumber: map['tableNumber'],
      isTakeAway: map['isTakeAway'] ?? false,
      items: List<OrderItem>.from(map['items']?.map((x) => OrderItem.fromMap(x))),
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
