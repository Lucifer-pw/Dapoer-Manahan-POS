import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firestore_service.dart';

class ChatProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<Map<String, dynamic>> _unreadMessages = [];
  bool _isLoading = true;
  StreamSubscription? _unreadSub;

  List<Map<String, dynamic>> get unreadMessages => _unreadMessages;
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadMessages.length;

  /// Map of table number to list of unread message count
  Map<String, int> get unreadCountByTable {
    final Map<String, int> counts = {};
    for (final msg in _unreadMessages) {
      final String tableNum = msg['tableNumber']?.toString() ?? '';
      if (tableNum.isNotEmpty) {
        counts[tableNum] = (counts[tableNum] ?? 0) + 1;
      }
    }
    return counts;
  }

  void init() {
    _unreadSub?.cancel();
    _unreadSub = _firestoreService.streamAllUnreadMessages().listen((messages) {
      final bool hasNewMessage = messages.length > _unreadMessages.length;
      _unreadMessages = messages;
      _isLoading = false;
      notifyListeners();

      if (hasNewMessage) {
        _playAlertSound();
      }
    });
  }

  void _playAlertSound() {
    SystemSound.play(SystemSoundType.click);
    Future.delayed(const Duration(milliseconds: 150), () {
      SystemSound.play(SystemSoundType.click);
    });
    HapticFeedback.vibrate();
  }

  Future<void> sendMessage(String tableNumber, String sender, String messageText) async {
    if (messageText.trim().isEmpty) return;
    await _firestoreService.sendChatMessage(tableNumber, sender, messageText.trim());
  }

  Future<void> markAsRead(String tableNumber, String role) async {
    if (role == 'admin') {
      await _firestoreService.markMessagesAsReadByAdmin(tableNumber);
    } else {
      await _firestoreService.markMessagesAsReadByCustomer(tableNumber);
    }
  }

  Future<void> clearChat(String tableNumber) async {
    await _firestoreService.clearTableMessages(tableNumber);
  }

  @override
  void dispose() {
    _unreadSub?.cancel();
    super.dispose();
  }
}
