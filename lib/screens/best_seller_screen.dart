import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../utils/formatter.dart';

class BestSellerScreen extends StatefulWidget {
  const BestSellerScreen({super.key});

  @override
  State<BestSellerScreen> createState() => _BestSellerScreenState();
}

class _BestSellerScreenState extends State<BestSellerScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();

  // Selected month & year
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  // Data
  List<Map<String, dynamic>> _bestSellers = [];
  int _totalItemsSold = 0;
  int _totalRevenue = 0;
  int _totalTransactions = 0;
  bool _isLoading = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _animController.reset();

    try {
      final start = DateTime(_selectedYear, _selectedMonth, 1);
      final end = DateTime(_selectedYear, _selectedMonth + 1, 1);

      final stats = await _firestoreService.getBestSellersByDateRange(start, end);

      if (!mounted) return;
      setState(() {
        _bestSellers = stats['bestSellers'] as List<Map<String, dynamic>>;
        _totalItemsSold = stats['totalItemsSold'] as int;
        _totalRevenue = stats['totalRevenue'] as int;
        _totalTransactions = stats['totalTransactions'] as int;
        _isLoading = false;
      });
      _animController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('Error loading best sellers: $e');
    }
  }

  void _showMonthYearPicker() {
    int tempMonth = _selectedMonth;
    int tempYear = _selectedYear;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textHint.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text('Pilih Bulan & Tahun',
                      style: AppTextStyles.heading3),
                  const SizedBox(height: 24),

                  // Year selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildArrowButton(
                        Icons.chevron_left_rounded,
                        () => setModalState(() => tempYear--),
                      ),
                      const SizedBox(width: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Text(
                          '$tempYear',
                          style: AppTextStyles.heading2.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      _buildArrowButton(
                        Icons.chevron_right_rounded,
                        tempYear < DateTime.now().year
                            ? () => setModalState(() => tempYear++)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Month grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 2.2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final month = index + 1;
                      final isSelected = month == tempMonth;
                      final isFuture = tempYear == DateTime.now().year &&
                          month > DateTime.now().month;

                      return GestureDetector(
                        onTap: isFuture
                            ? null
                            : () => setModalState(() => tempMonth = month),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? AppColors.primaryGradient
                                : null,
                            color: isSelected
                                ? null
                                : isFuture
                                    ? AppColors.card.withOpacity(0.3)
                                    : AppColors.card,
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                            border: isSelected
                                ? null
                                : Border.all(
                                    color: AppColors.border.withOpacity(0.2)),
                          ),
                          child: Center(
                            child: Text(
                              _getShortMonthName(month),
                              style: AppTextStyles.body.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 13,
                                color: isSelected
                                    ? Colors.white
                                    : isFuture
                                        ? AppColors.textHint.withOpacity(0.4)
                                        : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: AppColors.textHint.withOpacity(0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                          child: Text('Batal',
                              style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _selectedMonth = tempMonth;
                              _selectedYear = tempYear;
                            });
                            _loadData();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('Terapkan',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildArrowButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: onTap != null
              ? AppColors.card
              : AppColors.card.withOpacity(0.3),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border.withOpacity(0.2)),
        ),
        child: Icon(
          icon,
          size: 24,
          color: onTap != null ? AppColors.textPrimary : AppColors.textHint,
        ),
      ),
    );
  }

  String _getShortMonthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return months[month];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary, size: 20),
        ),
        title: Text('Best Seller', style: AppTextStyles.heading3),
        actions: [
          // Calendar picker button
          GestureDetector(
            onTap: _showMonthYearPicker,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '${_getShortMonthName(_selectedMonth)} $_selectedYear',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text('Memuat data...', style: AppTextStyles.bodySecondary),
                ],
              ),
            )
          : FadeTransition(
              opacity: _fadeAnim,
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: [
                    _buildSummaryCards(),
                    const SizedBox(height: 20),
                    if (_bestSellers.isNotEmpty) ...[
                      _buildTopChart(),
                      const SizedBox(height: 20),
                    ],
                    _buildRankingList(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ringkasan ${AppFormatter.getMonthName(_selectedMonth)} $_selectedYear',
          style: AppTextStyles.heading3,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildMiniCard(
                icon: Icons.restaurant_menu_rounded,
                iconColor: AppColors.primary,
                label: 'Item Terjual',
                value: '$_totalItemsSold',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMiniCard(
                icon: Icons.receipt_long_rounded,
                iconColor: AppColors.info,
                label: 'Transaksi',
                value: '$_totalTransactions',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMiniCard(
                icon: Icons.monetization_on_rounded,
                iconColor: AppColors.success,
                label: 'Pendapatan',
                value: AppFormatter.formatCompact(_totalRevenue),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTextStyles.heading3.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTopChart() {
    final topItems = _bestSellers.take(7).toList();
    if (topItems.isEmpty) return const SizedBox.shrink();

    final maxQty =
        topItems.map((e) => e['quantity'] as int).fold(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text('Top Menu', style: AppTextStyles.heading3),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: topItems.length * 48.0 + 20,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxQty.toDouble() * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = topItems[groupIndex];
                      return BarTooltipItem(
                        '${item['name']}\n${item['quantity']} porsi',
                        AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= topItems.length) {
                          return const SizedBox();
                        }
                        final name = topItems[i]['name'] as String;
                        final shortName = name.length > 8
                            ? '${name.substring(0, 7)}..'
                            : name;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            shortName,
                            style: AppTextStyles.caption
                                .copyWith(fontSize: 9),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: List.generate(topItems.length, (i) {
                  return BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: (topItems[i]['quantity'] as int).toDouble(),
                      width: topItems.length <= 5 ? 28 : 18,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6)),
                      gradient: LinearGradient(
                        colors: [
                          _getRankColor(i),
                          _getRankColor(i).withOpacity(0.7),
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ]);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.emoji_events_rounded,
                color: AppColors.secondary, size: 22),
            const SizedBox(width: 8),
            Text('Peringkat Menu', style: AppTextStyles.heading3),
            const Spacer(),
            Text(
              '${_bestSellers.length} menu',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_bestSellers.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: AppColors.card.withOpacity(0.5),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              children: [
                Icon(Icons.sentiment_dissatisfied_rounded,
                    size: 56, color: AppColors.textHint.withOpacity(0.4)),
                const SizedBox(height: 12),
                Text('Belum ada data penjualan',
                    style: AppTextStyles.bodySecondary),
                const SizedBox(height: 4),
                Text(
                  'Pilih bulan lain untuk melihat data',
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          )
        else
          ...List.generate(_bestSellers.length, (index) {
            final item = _bestSellers[index];
            final rank = index + 1;
            final name = item['name'] as String;
            final quantity = item['quantity'] as int;
            final revenue = item['revenue'] as int;
            final percentage = _totalItemsSold > 0
                ? (quantity / _totalItemsSold * 100)
                : 0.0;

            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 300 + (index * 80)),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: rank <= 3
                      ? LinearGradient(
                          colors: [
                            _getRankColor(index).withOpacity(0.08),
                            AppColors.card.withOpacity(0.5),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  color: rank > 3 ? AppColors.card.withOpacity(0.5) : null,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: rank <= 3
                        ? _getRankColor(index).withOpacity(0.3)
                        : AppColors.border.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  children: [
                    // Rank badge
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: rank <= 3
                            ? LinearGradient(
                                colors: [
                                  _getRankColor(index),
                                  _getRankColor(index).withOpacity(0.7),
                                ],
                              )
                            : null,
                        color: rank > 3
                            ? AppColors.card
                            : null,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: rank <= 3
                            ? [
                                BoxShadow(
                                  color:
                                      _getRankColor(index).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: rank <= 3
                            ? const Icon(
                                Icons.emoji_events_rounded,
                                size: 18,
                                color: Colors.white,
                              )
                            : Text(
                                '#$rank',
                                style: AppTextStyles.caption.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentage / 100,
                              minHeight: 4,
                              backgroundColor:
                                  AppColors.border.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getRankColor(index),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppFormatter.formatRupiah(revenue),
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Quantity
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$quantity',
                          style: AppTextStyles.heading3.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _getRankColor(index),
                          ),
                        ),
                        Text(
                          'porsi',
                          style: AppTextStyles.caption.copyWith(fontSize: 10),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Color _getRankColor(int index) {
    const colors = [
      Color(0xFFFFD700), // Gold
      Color(0xFFC0C0C0), // Silver
      Color(0xFFCD7F32), // Bronze
      Color(0xFF42A5F5), // Blue
      Color(0xFF66BB6A), // Green
      Color(0xFFAB47BC), // Purple
      Color(0xFFFF7043), // Deep Orange
    ];
    return colors[index % colors.length];
  }
}
