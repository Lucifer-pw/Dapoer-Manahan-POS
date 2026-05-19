import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
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

  /// Upload image to Firebase Storage with progress tracking
  Future<String> uploadMenuImage(File file, String menuItemId, {Function(double)? onProgress}) async {
    try {
      // Use a unique filename with timestamp to avoid caching/indexing issues
      final fileName = '${menuItemId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('menu_images').child(fileName);
      
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Listen to progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        if (onProgress != null) onProgress(progress);
      });
      
      await uploadTask;
      
      // Delay to ensure server indexing is complete
      await Future.delayed(const Duration(milliseconds: 500));
      
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }

  /// Upload salary payment proof image to Firebase Storage
  Future<String> uploadSalaryProofImage(File file, String cashierName, {Function(double)? onProgress}) async {
    try {
      final fileName = 'proof_${cashierName}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('salary_proofs').child(fileName);
      
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }
      
      await uploadTask;
      await Future.delayed(const Duration(milliseconds: 500));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading salary proof: $e');
      rethrow;
    }
  }

  /// Delete image from Firebase Storage by URL
  Future<void> deleteImageByUrl(String url) async {
    if (url.isEmpty || !url.contains('firebase')) return;
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete().catchError((e) => debugPrint('Silent error deleting: $e'));
    } catch (e) {
      debugPrint('Error getting ref from URL: $e');
    }
  }

  /// Delete image from Firebase Storage by ID (deprecated for unique filenames)
  Future<void> deleteMenuImage(String menuItemId) async {
    try {
      final ref = _storage.ref().child('menu_images').child('$menuItemId.jpg');
      await ref.delete().catchError((e) => debugPrint('Silent error deleting by ID: $e'));
    } catch (_) {
      // Image might not exist, ignore
    }
  }
}
