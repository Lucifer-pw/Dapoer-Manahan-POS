import 'package:flutter/material.dart';
import '../models/table_model.dart';
import '../utils/constants.dart';

class TableCard extends StatelessWidget {
  final RestaurantTable table;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const TableCard({
    super.key,
    required this.table,
    required this.onTap,
    this.onLongPress,
  });

  Color get _statusColor {
    switch (table.status) {
      case TableStatus.available:
        return AppColors.success;
      case TableStatus.occupied:
        return AppColors.error;
      case TableStatus.reserved:
        return AppColors.warning;
    }
  }

  String get _statusText {
    switch (table.status) {
      case TableStatus.available:
        return 'Tersedia';
      case TableStatus.occupied:
        return 'Terisi';
      case TableStatus.reserved:
        return 'Reserved';
    }
  }

  IconData get _statusIcon {
    switch (table.status) {
      case TableStatus.available:
        return Icons.check_circle_outline;
      case TableStatus.occupied:
        return Icons.people;
      case TableStatus.reserved:
        return Icons.bookmark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: _statusColor.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _statusColor.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Table icon with status glow
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.table_restaurant,
                size: 28,
                color: _statusColor,
              ),
            ),
            const SizedBox(height: 10),

            // Table number
            Text(
              'Meja ${table.number}',
              style: AppTextStyles.subtitle.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),

            // Capacity
            Text(
              '${table.capacity} kursi',
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 8),

            // Status chip
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_statusIcon, size: 12, color: _statusColor),
                  const SizedBox(width: 4),
                  Text(
                    _statusText,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
