import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  /// Pick image from gallery
  Future<File?> pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (image != null) {
      return File(image.path);
    }
    return null;
  }

  /// Pick image from camera
  Future<File?> takePhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (image != null) {
      return File(image.path);
    }
    return null;
  }

  /// Upload image to Firebase Storage
  Future<String> uploadMenuImage(File file, String menuItemId) async {
    final ref = _storage.ref().child('menu_images/$menuItemId.jpg');
    final uploadTask = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await uploadTask.ref.getDownloadURL();
  }

  /// Delete image from Firebase Storage
  Future<void> deleteMenuImage(String menuItemId) async {
    try {
      final ref = _storage.ref().child('menu_images/$menuItemId.jpg');
      await ref.delete();
    } catch (_) {
      // Image might not exist, ignore
    }
  }
}
