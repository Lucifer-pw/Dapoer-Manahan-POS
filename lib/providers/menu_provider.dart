import 'dart:async';
import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/menu_item.dart';
import '../services/firestore_service.dart';

class MenuProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<Category> _categories = [];
  List<MenuItem> _menuItems = [];
  String? _selectedCategoryId;
  String _searchQuery = '';
  bool _isLoading = true;

  StreamSubscription? _categorySub;
  StreamSubscription? _menuSub;

  List<Category> get categories => _categories;
  List<MenuItem> get allMenuItems => _menuItems;
  String? get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  /// Filtered menu items based on selected category and search query
  List<MenuItem> get filteredMenuItems {
    var items = _menuItems;

    if (_selectedCategoryId != null) {
      items = items
          .where((item) => item.categoryId == _selectedCategoryId)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      items = items
          .where((item) =>
              item.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    return items;
  }

  /// Available menu items only (for POS screen)
  List<MenuItem> get availableMenuItems {
    return filteredMenuItems.where((item) => item.isAvailable).toList();
  }

  void init() async {
    // Memastikan kategori bawaan dan meja terisi saat aplikasi pertama kali dijalankan
    await _firestoreService.seedDefaultData();

    _categorySub = _firestoreService.streamCategories().listen((List<Category> cats) {
      _categories = cats;
      notifyListeners();
    });

    _menuSub = _firestoreService.streamMenuItems().listen((List<MenuItem> items) {
      _menuItems = items;
      _isLoading = false;
      notifyListeners();
    });
  }

  void selectCategory(String? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearFilters() {
    _selectedCategoryId = null;
    _searchQuery = '';
    notifyListeners();
  }

  Future<void> addCategory(Category category) async {
    try {
      await _firestoreService.addCategory(category);
    } catch (e) {
      debugPrint('Error adding category: $e');
      rethrow;
    }
  }

  Future<void> updateCategory(Category category) async {
    try {
      await _firestoreService.updateCategory(category);
    } catch (e) {
      debugPrint('Error updating category: $e');
      rethrow;
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      await _firestoreService.deleteCategory(categoryId);
      // Jika kategori yang dihapus sedang dipilih, reset filter
      if (_selectedCategoryId == categoryId) {
        _selectedCategoryId = null;
      }
    } catch (e) {
      debugPrint('Error deleting category: $e');
      rethrow;
    }
  }

  String getCategoryName(String categoryId) {
    final cat = _categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => Category(id: '', name: 'Lainnya'),
    );
    return cat.name;
  }

  @override
  void dispose() {
    _categorySub?.cancel();
    _menuSub?.cancel();
    super.dispose();
  }
}
