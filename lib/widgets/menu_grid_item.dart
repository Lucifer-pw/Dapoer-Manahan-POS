import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/menu_item.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';

class MenuGridItem extends StatelessWidget {
  final MenuItem menuItem;
  final VoidCallback onTap;
  final int cartQuantity;

  const MenuGridItem({
    super.key,
    required this.menuItem,
    required this.onTap,
    this.cartQuantity = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: menuItem.isAvailable ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: cartQuantity > 0
                ? AppColors.primary.withOpacity(0.6)
                : AppColors.border.withOpacity(0.3),
            width: cartQuantity > 0 ? 2 : 1,
          ),
          boxShadow: cartQuantity > 0 ? AppShadows.glow : null,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.lg),
                      ),
                      color: AppColors.surface,
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.lg),
                      ),
                      child: menuItem.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: menuItem.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  _buildPlaceholderIcon(),
                            )
                          : _buildPlaceholderIcon(),
                    ),
                  ),
                ),
                // Info
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          menuItem.name,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          AppFormatter.formatRupiah(menuItem.price),
                          style: AppTextStyles.priceSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Not available overlay
            if (!menuItem.isAvailable)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Center(
                  child: Text(
                    'HABIS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),

            // Cart quantity badge
            if (cartQuantity > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    boxShadow: AppShadows.glow,
                  ),
                  child: Text(
                    '$cartQuantity',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Center(
      child: Icon(
        Icons.restaurant,
        size: 40,
        color: AppColors.textHint.withOpacity(0.5),
      ),
    );
  }
}
