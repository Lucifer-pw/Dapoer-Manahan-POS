import 'package:flutter/material.dart';
import '../models/order_item.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';

class CartItemWidget extends StatelessWidget {
  final OrderItem item;
  final int index;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final VoidCallback onBonusToggle;
  final Function(String) onNotesChanged;

  const CartItemWidget({
    super.key,
    required this.item,
    required this.index,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onBonusToggle,
    required this.onNotesChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('${item.menuItemId}_$index'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.2),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card.withOpacity(0.5),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Item name + price
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.menuItemName,
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (item.isBonus)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'BONUS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      const SizedBox(height: 2),
                      if (item.variant != null)
                        Text(
                          item.variant!,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      Text(
                        AppFormatter.formatRupiah(item.price),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          decoration: item.isBonus ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ],
                  ),
                ),

                // Bonus Toggle
                IconButton(
                  icon: Icon(
                    item.isBonus ? Icons.star : Icons.star_border,
                    color: item.isBonus ? Colors.amber : AppColors.textHint,
                    size: 20,
                  ),
                  onPressed: onBonusToggle,
                  tooltip: 'Tandai sebagai Bonus',
                ),

                // Quantity controls
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildQtyButton(Icons.remove, onDecrement),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '${item.quantity}',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      _buildQtyButton(Icons.add, onIncrement),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Subtotal
                SizedBox(
                  width: 80,
                  child: Text(
                    AppFormatter.formatRupiah(item.subtotal),
                    style: AppTextStyles.priceSmall,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),

            // Notes
            if (item.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.notes, size: 14, color: AppColors.secondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.notes,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.secondary,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}
