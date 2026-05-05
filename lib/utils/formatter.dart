import 'package:intl/intl.dart';

class AppFormatter {
  static final _rupiahFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final _dateFormat = DateFormat('dd MMM yyyy', 'id_ID');
  static final _timeFormat = DateFormat('HH:mm', 'id_ID');
  static final _dateTimeFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
  static final _shortDateFormat = DateFormat('dd/MM/yyyy', 'id_ID');

  /// Format angka ke Rupiah: 25000 → Rp 25.000
  static String formatRupiah(int amount) {
    return _rupiahFormat.format(amount);
  }

  /// Format tanggal: 2024-01-15 → 15 Jan 2024
  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  /// Format waktu: 14:30
  static String formatTime(DateTime date) {
    return _timeFormat.format(date);
  }

  /// Format tanggal + waktu: 15 Jan 2024, 14:30
  static String formatDateTime(DateTime date) {
    return _dateTimeFormat.format(date);
  }

  /// Format tanggal pendek: 15/01/2024
  static String formatShortDate(DateTime date) {
    return _shortDateFormat.format(date);
  }

  /// Format angka pendek: 1500000 → 1.5jt
  static String formatCompact(int amount) {
    if (amount >= 1000000) {
      double m = amount / 1000000;
      return '${m.toStringAsFixed(m.truncateToDouble() == m ? 0 : 1)}jt';
    } else if (amount >= 1000) {
      double k = amount / 1000;
      return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}rb';
    }
    return amount.toString();
  }
  static String getMonthName(int month) {
    const months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    if (month < 1 || month > 12) return '';
    return months[month];
  }
}
