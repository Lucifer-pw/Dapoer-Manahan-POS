enum TableStatus { available, occupied, reserved }

class RestaurantTable {
  final String id;
  final int number;
  final int capacity;
  final TableStatus status;
  final String? currentOrderId;
  final String? qrUrl;

  RestaurantTable({
    required this.id,
    required this.number,
    this.capacity = 4,
    this.status = TableStatus.available,
    this.currentOrderId,
    this.qrUrl,
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
      qrUrl: map['qrUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'number': number,
      'capacity': capacity,
      'status': status.name,
      'currentOrderId': currentOrderId,
      'qrUrl': qrUrl,
    };
  }

  RestaurantTable copyWith({
    String? id,
    int? number,
    int? capacity,
    TableStatus? status,
    String? currentOrderId,
    String? qrUrl,
  }) {
    return RestaurantTable(
      id: id ?? this.id,
      number: number ?? this.number,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      currentOrderId: currentOrderId ?? this.currentOrderId,
      qrUrl: qrUrl ?? this.qrUrl,
    );
  }
}
