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
        fit: StackFit.expand,
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
                SizedBox(height: isMobile ? 6 : 8),
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
                    fontSize: isMobile ? 12 : 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isMobile ? 2 : 4),

                // Capacity
                Text(
                  '${table.capacity} kursi',
                  style: AppTextStyles.caption.copyWith(fontSize: isMobile ? 9 : 11),
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
                          fontSize: isMobile ? 9.5 : 11,
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
          
          // Badge Multi-Status Pesanan Aktif di Pojok Kanan Atas
          if (_hasActiveOrders)
            Positioned(
              top: isMobile ? 4 : 6,
              right: isMobile ? 4 : 6,
              child: _buildMultiStatusBadges(isMobile),
            ),
        ],
      ),
    );
  }

  /// Menghitung dan menampilkan badge per kategori status pesanan
  Widget _buildMultiStatusBadges(bool isMobile) {
    // Hitung jumlah pesanan per kategori
    int pendingCount = 0;    // Pesanan Masuk (menunggu konfirmasi)
    int acceptedCount = 0;   // Sedang Diproses (dapur)
    int deliveredCount = 0;  // Sudah Diantar
    int unpaidCount = 0;     // Belum Dibayar

    for (final order in activeOrders) {
      final String status = order['status'] as String? ?? '';
      final String paymentStatus = order['paymentStatus'] as String? ?? '';

      if (status == 'pending') {
        pendingCount++;
      } else if (status == 'accepted') {
        acceptedCount++;
      } else if (status == 'delivered') {
        deliveredCount++;
        if (paymentStatus != 'sudah_bayar') {
          unpaidCount++;
        }
      }
    }

    final List<Widget> badges = [];

    if (pendingCount > 0) {
      badges.add(_buildMiniBadge(
        color: AppColors.warning,
        icon: Icons.notification_important_rounded,
        count: pendingCount,
        label: isMobile ? 'Masuk' : 'Pesanan Masuk',
        isMobile: isMobile,
      ));
    }

    if (acceptedCount > 0) {
      badges.add(_buildMiniBadge(
        color: AppColors.info,
        icon: Icons.restaurant_rounded,
        count: acceptedCount,
        label: isMobile ? 'Proses' : 'Diproses',
        isMobile: isMobile,
      ));
    }

    if (deliveredCount > 0 && unpaidCount == 0) {
      badges.add(_buildMiniBadge(
        color: AppColors.success,
        icon: Icons.check_circle_rounded,
        count: deliveredCount,
        label: isMobile ? 'Antar' : 'Diantar',
        isMobile: isMobile,
      ));
    }

    if (unpaidCount > 0) {
      badges.add(_buildMiniBadge(
        color: AppColors.error,
        icon: Icons.payment_rounded,
        count: unpaidCount,
        label: isMobile ? 'Bayar' : 'Belum Bayar',
        isMobile: isMobile,
      ));
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < badges.length; i++) ...[
          badges[i],
          if (i < badges.length - 1) SizedBox(height: isMobile ? 3 : 4),
        ],
      ],
    );
  }

  Widget _buildMiniBadge({
    required Color color,
    required IconData icon,
    required int count,
    required String label,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 4 : 6,
        vertical: isMobile ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(isMobile ? 4 : 6),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: isMobile ? 3 : 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isMobile ? 8 : 9, color: Colors.white),
          SizedBox(width: isMobile ? 2 : 3),
          Text(
            isMobile ? '$count' : '$label ($count)',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 7.5 : 8.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
