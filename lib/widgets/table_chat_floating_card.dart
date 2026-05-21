import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/table_provider.dart';
import '../utils/constants.dart';
import 'chat_room_dialog.dart';

class TableChatFloatingCard extends StatefulWidget {
  const TableChatFloatingCard({super.key});

  @override
  State<TableChatFloatingCard> createState() => _TableChatFloatingCardState();
}

class _TableChatFloatingCardState extends State<TableChatFloatingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0.0, end: -6.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ChatProvider, TableProvider>(
      builder: (context, chatProv, tableProv, child) {
        final hasUnread = chatProv.unreadCount > 0;

        Widget cardContent = InkWell(
          onTap: () => _showChatTablesBottomSheet(context, chatProv, tableProv),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasUnread
                    ? [AppColors.secondary, AppColors.secondaryLight]
                    : [AppColors.surfaceDark, AppColors.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: hasUnread ? null : Border.all(color: AppColors.border.withOpacity(0.5)),
              boxShadow: hasUnread ? AppShadows.glow : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: hasUnread ? Colors.white.withOpacity(0.2) : AppColors.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_rounded,
                    color: hasUnread ? Colors.white : AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  hasUnread ? 'Chat Meja (${chatProv.unreadCount})' : 'Chat Meja',
                  style: TextStyle(
                    color: hasUnread ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: hasUnread ? Colors.white : AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    'BUKA',
                    style: TextStyle(
                      color: hasUnread ? AppColors.secondary : AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        if (!hasUnread) {
          return cardContent;
        }

        return AnimatedBuilder(
          animation: _bounceAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _bounceAnimation.value),
              child: child,
            );
          },
          child: cardContent,
        );
      },
    );
  }

  void _showChatTablesBottomSheet(
    BuildContext context,
    ChatProvider chatProv,
    TableProvider tableProv,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            final unreadCounts = chatProv.unreadCountByTable;
            final activeTables = unreadCounts.keys.toList();

            // All tables from TableProvider
            final allTables = tableProv.tables;

            return Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: AppColors.secondary,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Chat Meja Pelanggan',
                        style: AppTextStyles.heading3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: allTables.isEmpty ? activeTables.length : allTables.length,
                    itemBuilder: (context, index) {
                      String tableNum = '';
                      int unread = 0;

                      if (allTables.isNotEmpty) {
                        final table = allTables[index];
                        tableNum = table.number.toString();
                        unread = unreadCounts[tableNum] ?? 0;
                      } else {
                        tableNum = activeTables[index];
                        unread = unreadCounts[tableNum] ?? 0;
                      }

                      final hasUnread = unread > 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: hasUnread 
                              ? AppColors.secondary.withOpacity(0.08) 
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: hasUnread 
                                ? AppColors.secondary.withOpacity(0.3) 
                                : AppColors.border.withOpacity(0.2),
                            width: hasUnread ? 1.5 : 1.0,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: hasUnread 
                                  ? AppColors.secondary 
                                  : AppColors.surfaceDark,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.table_bar_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          title: Text(
                            'Meja $tableNum',
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.bold,
                              color: hasUnread ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            hasUnread 
                                ? '$unread pesan baru belum dibaca' 
                                : 'Mulai chat dengan meja $tableNum',
                            style: AppTextStyles.caption.copyWith(
                              color: hasUnread ? AppColors.secondary : AppColors.textHint,
                            ),
                          ),
                          trailing: hasUnread
                              ? Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: AppColors.secondary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    unread.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.textHint,
                                ),
                          onTap: () {
                            Navigator.pop(context); // Close bottom sheet
                            showDialog(
                              context: context,
                              builder: (_) => ChatRoomDialog(
                                tableNumber: tableNum,
                                role: 'admin',
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
