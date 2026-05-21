import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/chat_provider.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';

class ChatRoomDialog extends StatefulWidget {
  final String tableNumber;
  final String role; // 'customer' or 'admin'

  const ChatRoomDialog({
    super.key,
    required this.tableNumber,
    required this.role,
  });

  @override
  State<ChatRoomDialog> createState() => _ChatRoomDialogState();
}

class _ChatRoomDialogState extends State<ChatRoomDialog> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    // Mark messages as read as soon as the dialog is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChatProvider>(context, listen: false)
          .markAsRead(widget.tableNumber, widget.role);
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final chatProv = Provider.of<ChatProvider>(context, listen: false);
    chatProv.sendMessage(widget.tableNumber, widget.role, text);
    _messageController.clear();
    
    // Slight delay to allow message to render before scrolling
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _confirmClearChat(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            'Hapus Obrolan?',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            'Semua riwayat obrolan dengan Meja ${widget.tableNumber} akan dihapus secara permanen untuk pelanggan baru.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                'Batal',
                style: TextStyle(color: AppColors.textHint),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx); // Close confirm dialog
                
                try {
                  await Provider.of<ChatProvider>(context, listen: false)
                      .clearChat(widget.tableNumber);
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Obrolan Meja ${widget.tableNumber} berhasil dihapus.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gagal menghapus obrolan: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.role == 'customer' 
        ? 'Chat dengan Kasir' 
        : 'Chat dengan Meja ${widget.tableNumber}';

    return Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: AppColors.border.withOpacity(0.5)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: SizedBox(
          width: 500,
          height: 600,
          child: Column(
            children: [
              // Chat Header
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                color: widget.role == 'customer' ? AppColors.surfaceDark : AppColors.primary,
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: widget.role == 'customer' ? AppColors.primary : Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.heading3.copyWith(
                          color: widget.role == 'customer' ? AppColors.textPrimary : Colors.white,
                        ),
                      ),
                    ),
                    if (widget.role == 'admin')
                      IconButton(
                        tooltip: 'Hapus Obrolan',
                        icon: const Icon(
                          Icons.delete_sweep_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => _confirmClearChat(context),
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: widget.role == 'customer' ? AppColors.textSecondary : Colors.white70,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Chat Messages Stream
              Expanded(
                child: Container(
                  color: AppColors.backgroundDark,
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _firestoreService.streamTableMessages(widget.tableNumber),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Gagal memuat chat: ${snapshot.error}',
                            style: AppTextStyles.caption,
                          ),
                        );
                      }

                      final messages = snapshot.data ?? [];
                      
                      // Auto scroll to bottom
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToBottom();
                        // Mark as read again when new messages arrive while dialog is active
                        Provider.of<ChatProvider>(context, listen: false)
                            .markAsRead(widget.tableNumber, widget.role);
                      });

                      if (messages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 48,
                                color: AppColors.textHint.withOpacity(0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Kirim pesan pertama untuk memulai chat',
                                style: AppTextStyles.bodySecondary,
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final sender = msg['sender'] ?? '';
                          final messageText = msg['message'] ?? '';
                          final timestamp = msg['timestamp'] as Timestamp?;
                          final isMe = sender == widget.role;

                          return _buildMessageBubble(messageText, isMe, timestamp);
                        },
                      );
                    },
                  ),
                ),
              ),

              // Chat Input
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.5))),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: TextStyle(color: AppColors.textPrimary),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: 'Tulis pesan...',
                            hintStyle: TextStyle(color: AppColors.textHint),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.full),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: AppColors.backgroundDark,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 20),
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isMe, Timestamp? timestamp) {
    String formattedTime = '';
    if (timestamp != null) {
      formattedTime = DateFormat('HH:mm').format(timestamp.toDate());
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                // Avatar representation for counterpart
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: widget.role == 'customer' 
                        ? AppColors.primary.withOpacity(0.2)
                        : AppColors.success.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.role == 'customer' ? 'K' : 'M',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: widget.role == 'customer' ? AppColors.primary : AppColors.success,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe 
                        ? AppColors.primary 
                        : (widget.role == 'customer' ? AppColors.surface : AppColors.surface),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    border: isMe 
                        ? null 
                        : Border.all(color: AppColors.border.withOpacity(0.3)),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isMe ? Colors.white : AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              if (isMe) const SizedBox(width: 8),
            ],
          ),
          if (formattedTime.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 4, left: isMe ? 0 : 36, right: isMe ? 4 : 0),
              child: Text(
                formattedTime,
                style: AppTextStyles.caption.copyWith(fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }
}
