class OrderItem {
  final String menuItemId;
  final String menuItemName;
  final String? categoryId; // Added to support category stats
  final int quantity;
  final int price;
  final String notes;
  final bool isBonus;
  final String? variant; // e.g. "Teh Anget", "Esteh", "Air Mineral"

  OrderItem({
    required this.menuItemId,
    required this.menuItemName,
    this.categoryId,
    required this.quantity,
    required this.price,
    this.notes = '',
    this.isBonus = false,
    this.variant,
  });

  int get subtotal => isBonus ? 0 : price * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      menuItemId: map['menuItemId'] ?? map['id'] ?? '',
      menuItemName: map['menuItemName'] ?? map['name'] ?? '',
      categoryId: map['categoryId'],
      quantity: _toInt(map['quantity']),
      price: _toInt(map['price']),
      notes: map['notes'] ?? '',
      isBonus: map['isBonus'] ?? false,
      variant: map['variant'],
    );
  }

  /// Safely converts a dynamic value to int.
  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }


  Map<String, dynamic> toMap() {
    return {
      'menuItemId': menuItemId,
      'menuItemName': menuItemName,
      'categoryId': categoryId,
      'quantity': quantity,
      'price': price,
      'notes': notes,
      'isBonus': isBonus,
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
    bool? isBonus,
    String? variant,
  }) {
    return OrderItem(
      menuItemId: menuItemId ?? this.menuItemId,
      menuItemName: menuItemName ?? this.menuItemName,
      categoryId: categoryId ?? this.categoryId,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      notes: notes ?? this.notes,
      isBonus: isBonus ?? this.isBonus,
      variant: variant ?? this.variant,
    );
  }
}
