import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/draft_order.dart';

class DraftProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<DraftOrder> _drafts = [];
  bool _isLoading = false;

  List<DraftOrder> get drafts => _drafts;
  bool get isLoading => _isLoading;

  String? get _uid => _auth.currentUser?.uid;

  Future<void> fetchDrafts() async {
    if (_uid == null) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('drafts')
          .orderBy('createdAt', descending: true)
          .get();

      _drafts = snapshot.docs
          .map((doc) => DraftOrder.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('Error fetching drafts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveDraft(DraftOrder draft) async {
    if (_uid == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('drafts')
          .doc(draft.id)
          .set(draft.toMap());
      
      await fetchDrafts();
    } catch (e) {
      debugPrint('Error saving draft: $e');
    }
  }

  Future<void> deleteDraft(String id) async {
    if (_uid == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('drafts')
          .doc(id)
          .delete();
      
      _drafts.removeWhere((d) => d.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting draft: $e');
    }
  }
}
