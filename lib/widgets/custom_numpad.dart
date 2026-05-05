import 'package:flutter/material.dart';
import '../utils/constants.dart';

class CustomNumpad extends StatelessWidget {
  final Function(String) onNumberTap;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  const CustomNumpad({
    super.key,
    required this.onNumberTap,
    required this.onDelete,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow(['1', '2', '3']),
        const SizedBox(height: 8),
        _buildRow(['4', '5', '6']),
        const SizedBox(height: 8),
        _buildRow(['7', '8', '9']),
        const SizedBox(height: 8),
        _buildSpecialRow(),
      ],
    );
  }

  Widget _buildRow(List<String> numbers) {
    return Row(
      children: numbers.map((number) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildNumberButton(number),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSpecialRow() {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildActionButton(
              'C',
              onClear,
              AppColors.error.withOpacity(0.2),
              AppColors.error,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildNumberButton('0'),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildActionButton(
              '⌫',
              onDelete,
              AppColors.warning.withOpacity(0.2),
              AppColors.warning,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberButton(String number) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onNumberTap(number),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(
              number,
              style: AppTextStyles.heading3.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    VoidCallback onTap,
    Color bgColor,
    Color textColor,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
