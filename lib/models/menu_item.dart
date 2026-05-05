import 'package:cloud_firestore/cloud_firestore.dart';

class MenuItem {
  final String id;
  final String categoryId;
  final String name;
  final int price;
  final String description;
  final String imageUrl;
  final bool isAvailable;
  final DateTime createdAt;

  MenuItem({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.price,
    this.description = '',
    this.imageUrl = '',
    this.isAvailable = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MenuItem.fromMap(Map<String, dynamic> map, String docId) {
    return MenuItem(
      id: docId,
      categoryId: map['categoryId'] ?? '',
      name: map['name'] ?? '',
      price: map['price'] ?? 0,
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      isAvailable: map['isAvailable'] ?? true,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'name': name,
      'price': price,
      'description': description,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  MenuItem copyWith({
    String? id,
    String? categoryId,
    String? name,
    int? price,
    String? description,
    String? imageUrl,
    bool? isAvailable,
  }) {
    return MenuItem(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt,
    );
  }
}
