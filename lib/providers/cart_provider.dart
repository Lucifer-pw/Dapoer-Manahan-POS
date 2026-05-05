import 'package:flutter/material.dart';
import '../models/menu_item.dart';
import '../models/order_item.dart';

class CartProvider extends ChangeNotifier {
  final List<OrderItem> _items = [];
  int _tableNumber = 0;

  List<OrderItem> get items => List.unmodifiable(_items);
  int get tableNumber => _tableNumber;
  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.length;

  int get totalQuantity =>
      _items.fold(0, (sum, item) => sum + item.quantity);

  int get subtotal =>
      _items.fold(0, (sum, item) => sum + item.subtotal);

  int get tax => 0; // No tax by default, can be configured

  int get total => subtotal + tax;

  void setTableNumber(int number) {
    _tableNumber = number;
    notifyListeners();
  }

  /// Add menu item to cart. If already exists, increment quantity.
  void addItem(MenuItem menuItem) {
    final existingIndex = _items.indexWhere(
      (item) => item.menuItemId == menuItem.id && item.notes.isEmpty,
    );

    if (existingIndex >= 0) {
      final existing = _items[existingIndex];
      _items[existingIndex] = existing.copyWith(
        quantity: existing.quantity + 1,
      );
    } else {
      _items.add(OrderItem(
        menuItemId: menuItem.id,
        menuItemName: menuItem.name,
        quantity: 1,
        price: menuItem.price,
      ));
    }
    notifyListeners();
  }

  /// Remove item from cart entirely
  void removeItem(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  /// Update quantity of item at index
  void updateQuantity(int index, int quantity) {
    if (index >= 0 && index < _items.length) {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index] = _items[index].copyWith(quantity: quantity);
      }
      notifyListeners();
    }
  }

  /// Increment quantity
  void incrementItem(int index) {
    if (index >= 0 && index < _items.length) {
      final item = _items[index];
      _items[index] = item.copyWith(quantity: item.quantity + 1);
      notifyListeners();
    }
  }

  /// Decrement quantity (removes if 0)
  void decrementItem(int index) {
    if (index >= 0 && index < _items.length) {
      final item = _items[index];
      if (item.quantity <= 1) {
        _items.removeAt(index);
      } else {
        _items[index] = item.copyWith(quantity: item.quantity - 1);
      }
      notifyListeners();
    }
  }

  /// Add/update notes for item
  void updateNotes(int index, String notes) {
    if (index >= 0 && index < _items.length) {
      _items[index] = _items[index].copyWith(notes: notes);
      notifyListeners();
    }
  }

  /// Clear entire cart
  void clear() {
    _items.clear();
    _tableNumber = 0;
    notifyListeners();
  }
}
