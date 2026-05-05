class OrderItem {
  final String menuItemId;
  final String menuItemName;
  final int quantity;
  final int price;
  final String notes;

  OrderItem({
    required this.menuItemId,
    required this.menuItemName,
    required this.quantity,
    required this.price,
    this.notes = '',
  });

  int get subtotal => price * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      menuItemId: map['menuItemId'] ?? '',
      menuItemName: map['menuItemName'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: map['price'] ?? 0,
      notes: map['notes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'menuItemId': menuItemId,
      'menuItemName': menuItemName,
      'quantity': quantity,
      'price': price,
      'notes': notes,
    };
  }

  OrderItem copyWith({
    String? menuItemId,
    String? menuItemName,
    int? quantity,
    int? price,
    String? notes,
  }) {
    return OrderItem(
      menuItemId: menuItemId ?? this.menuItemId,
      menuItemName: menuItemName ?? this.menuItemName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      notes: notes ?? this.notes,
    );
  }
}
