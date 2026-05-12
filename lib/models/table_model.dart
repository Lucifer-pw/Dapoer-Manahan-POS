enum TableStatus { available, occupied, reserved }

class RestaurantTable {
  final String id;
  final int number;
  final int capacity;
  final TableStatus status;
  final String? currentOrderId;

  RestaurantTable({
    required this.id,
    required this.number,
    this.capacity = 4,
    this.status = TableStatus.available,
    this.currentOrderId,
  });

  factory RestaurantTable.fromMap(Map<String, dynamic> map, String docId) {
    return RestaurantTable(
      id: docId,
      number: map['number'] ?? 0,
      capacity: map['capacity'] ?? 4,
      status: TableStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'available'),
        orElse: () => TableStatus.available,
      ),
      currentOrderId: map['currentOrderId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'number': number,
      'capacity': capacity,
      'status': status.name,
      'currentOrderId': currentOrderId,
    };
  }

  RestaurantTable copyWith({
    String? id,
    int? number,
    int? capacity,
    TableStatus? status,
    String? currentOrderId,
  }) {
    return RestaurantTable(
      id: id ?? this.id,
      number: number ?? this.number,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      currentOrderId: currentOrderId ?? this.currentOrderId,
    );
  }
}
