import 'package:flutter/material.dart';
import '../models/table_model.dart';
import '../utils/constants.dart';

class TableCard extends StatelessWidget {
  final RestaurantTable table;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final List<Map<String, dynamic>> activeOrders;

  const TableCard({
    super.key,
    required this.table,
    required this.onTap,
    this.onLongPress,
    this.activeOrders = const [],
  });

  bool get _hasActiveOrders => activeOrders.isNotEmpty;

  // Menentukan pesanan teraktif/paling mendesak
  Map<String, dynamic>? get _mostUrgentOrder {
    if (activeOrders.isEmpty) return null;
    
    // 1. Prioritas tertinggi: Sudah Diantar (Delivered) tapi belum bayar (Belum Bayar)
    final unpaidDelivered = activeOrders.where((o) {
      final st = o['status'] as String? ?? '';
      final paySt = o['paymentStatus'] as String? ?? '';
      return st == 'delivered' && paySt != 'sudah_bayar';
    });
    if (unpaidDelivered.isNotEmpty) return unpaidDelivered.first;

    // 2. Prioritas kedua: Pesanan Baru (Pending) yang belum diterima kasir
    final pendingOrders = activeOrders.where((o) => o['status'] == 'pending');
    if (pendingOrders.isNotEmpty) return pendingOrders.first;

    // 3. Prioritas ketiga: Pesanan sedang diproses (Accepted) oleh dapur
    final acceptedOrders = activeOrders.where((o) => o['status'] == 'accepted');
    if (acceptedOrders.isNotEmpty) return acceptedOrders.first;

    return activeOrders.first;
  }

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

  Color get _activeOrderColor {
    final urgent = _mostUrgentOrder;
    if (urgent == null) return _statusColor;

    final String status = urgent['status'] as String? ?? '';
    final String paymentStatus = urgent['paymentStatus'] as String? ?? '';

    if (status == 'delivered' && paymentStatus != 'sudah_bayar') {
      return AppColors.error; // Merah untuk Belum Bayar
    } else if (status == 'pending') {
      return AppColors.warning; // Oranye untuk Pesanan Baru
    } else if (status == 'accepted') {
      return AppColors.info; // Biru untuk Diproses Dapur
    }
    return AppColors.primary;
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
    final highlightColor = _hasActiveOrders ? _activeOrderColor : _statusColor;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;
    
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              gradient: AppColors.cardGradient,
              borderRadius: BorderRadius.circular(isMobile ? AppRadius.md : AppRadius.lg),
              border: Border.all(
                color: highlightColor.withOpacity(_hasActiveOrders ? 0.7 : 0.4),
                width: _hasActiveOrders ? 2.2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: highlightColor.withOpacity(_hasActiveOrders ? 0.25 : 0.1),
                  blurRadius: _hasActiveOrders ? (isMobile ? 10 : 16) : (isMobile ? 8 : 12),
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: isMobile ? 6 : 8), // Memberikan sedikit ruang di atas
                // Table icon with status glow
                Container(
                  padding: EdgeInsets.all(isMobile ? 8 : 12),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.table_restaurant,
                    size: isMobile ? 20 : 24,
                    color: _statusColor,
                  ),
                ),
                SizedBox(height: isMobile ? 6 : 8),

                // Table number
                Text(
                  'Meja ${table.number}',
                  style: AppTextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: isMobile ? 13 : 15,
                  ),
                ),
                SizedBox(height: isMobile ? 2 : 4),

                // Capacity
                Text(
                  '${table.capacity} kursi',
                  style: AppTextStyles.caption.copyWith(fontSize: isMobile ? 10 : 11),
                ),
                SizedBox(height: isMobile ? 6 : 8),

                // Status chip
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 10,
                    vertical: isMobile ? 3 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon, size: isMobile ? 10 : 12, color: _statusColor),
                      SizedBox(width: isMobile ? 3 : 4),
                      Text(
                        _statusText,
                        style: TextStyle(
                          color: _statusColor,
                          fontSize: isMobile ? 10 : 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isMobile ? 2 : 4),
              ],
            ),
          ),
          
          // Badge Pesanan Aktif di Pojok Kanan Atas
          if (_hasActiveOrders)
            Positioned(
              top: isMobile ? 6 : 8,
              right: isMobile ? 6 : 8,
              child: _buildActiveOrdersIndicator(isMobile),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveOrdersIndicator(bool isMobile) {
    final urgent = _mostUrgentOrder;
    if (urgent == null) return const SizedBox.shrink();

    final String status = urgent['status'] as String? ?? '';
    final String paymentStatus = urgent['paymentStatus'] as String? ?? '';

    Color badgeColor;
    IconData badgeIcon;
    String badgeText;

    if (status == 'delivered' && paymentStatus != 'sudah_bayar') {
      badgeColor = AppColors.error;
      badgeIcon = Icons.payment_rounded;
      badgeText = isMobile ? '' : 'Belum Bayar';
    } else if (status == 'pending') {
      badgeColor = AppColors.warning;
      badgeIcon = Icons.new_releases_rounded;
      badgeText = isMobile ? '' : 'Baru';
    } else if (status == 'accepted') {
      badgeColor = AppColors.info;
      badgeIcon = Icons.restaurant_rounded;
      badgeText = isMobile ? '' : 'Diproses';
    } else {
      badgeColor = AppColors.primary;
      badgeIcon = Icons.receipt_long_rounded;
      badgeText = isMobile ? '' : 'Aktif';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 5 : 6,
        vertical: isMobile ? 5 : 3,
      ),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(isMobile ? 4 : 6),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withOpacity(0.4),
            blurRadius: isMobile ? 4 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: isMobile ? 11 : 9, color: Colors.white),
          if (badgeText.isNotEmpty) ...[
            const SizedBox(width: 3),
            Text(
              badgeText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
