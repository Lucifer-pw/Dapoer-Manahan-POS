class OrderItem {
  final String menuItemId;
  final String menuItemName;
  final String? categoryId; // Added to support category stats
  final int quantity;
  final int price;
  final String notes;
  final String? variant; // e.g. "Teh Anget", "Esteh", "Air Mineral"

  OrderItem({
    required this.menuItemId,
    required this.menuItemName,
    this.categoryId,
    required this.quantity,
    required this.price,
    this.notes = '',
    this.variant,
  });

  int get subtotal => price * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      menuItemId: map['menuItemId'] ?? '',
      menuItemName: map['menuItemName'] ?? '',
      categoryId: map['categoryId'],
      quantity: map['quantity'] ?? 0,
      price: map['price'] ?? 0,
      notes: map['notes'] ?? '',
      variant: map['variant'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'menuItemId': menuItemId,
      'menuItemName': menuItemName,
      'categoryId': categoryId,
      'quantity': quantity,
      'price': price,
      'notes': notes,
      'variant': variant,
    };
  }

  OrderItem copyWith({
    String? menuItemId,
    String? menuItemName,
    String? categoryId,
    int? quantity,
    int? price,
    String? notes,
    String? variant,
  }) {
    return OrderItem(
      menuItemId: menuItemId ?? this.menuItemId,
      menuItemName: menuItemName ?? this.menuItemName,
      categoryId: categoryId ?? this.categoryId,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      notes: notes ?? this.notes,
      variant: variant ?? this.variant,
    );
  }
}
