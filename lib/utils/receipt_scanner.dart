import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptScanner {
  /// Memindai file gambar bukti transfer menggunakan Google MLKit dan mengembalikan detail parsing.
  static Future<Map<String, dynamic>?> scanReceipt(File file) async {
    final inputImage = InputImage.fromFile(file);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      return parseText(recognizedText.text);
    } catch (e) {
      debugPrint("OCR Processing Error: $e");
      return null;
    } finally {
      textRecognizer.close();
    }
  }

  /// Mengekstraksi tanggal dan nominal transfer dari teks mentah.
  static Map<String, dynamic> parseText(String text) {
    debugPrint("=== SCAN RECEIPT RAW TEXT ===\n$text\n=============================");
    
    DateTime? date;
    // Cari tanggal berformat DD/MM/YYYY atau DD-MM-YYYY
    final dateRegex = RegExp(r'\b(\d{2})[-/](\d{2})[-/](\d{4})\b');
    final dateMatch = dateRegex.firstMatch(text);
    if (dateMatch != null) {
      final day = int.tryParse(dateMatch.group(1)!) ?? 1;
      final month = int.tryParse(dateMatch.group(2)!) ?? 1;
      final year = int.tryParse(dateMatch.group(3)!) ?? 2026;
      date = DateTime(year, month, day);
    }

    int? amount;
    // Cari nominal dengan pola 'Rp 150.000,00', 'Rp. 150.000', 'Total Rp150.000'
    final rpRegex = RegExp(r'(?:Rp\.?\s*|IDR\s*)([0-9\.,]+)', caseSensitive: false);
    final rpMatches = rpRegex.allMatches(text);
    
    for (final match in rpMatches) {
      final matchStr = match.group(1);
      if (matchStr != null) {
        final cleaned = _parseIndonesianNumber(matchStr);
        if (cleaned != null && cleaned >= 1000) { // Anggap nominal transfer rasional minimal 1000 rupiah
          amount = cleaned;
          break; // Ambil kecocokan pertama yang valid
        }
      }
    }

    // Fallback: Jika pola "Rp" tidak ada, cari angka desimal ribuan berurutan (misal: 150.000)
    if (amount == null) {
      final numRegex = RegExp(r'\b\d{1,3}(?:\.\d{3})+\b');
      final numMatches = numRegex.allMatches(text);
      for (final match in numMatches) {
        final matchStr = match.group(0);
        if (matchStr != null) {
          final cleaned = _parseIndonesianNumber(matchStr);
          if (cleaned != null && cleaned >= 1000) {
            amount = cleaned;
            break;
          }
        }
      }
    }

    return {
      'rawText': text,
      'date': date,
      'amount': amount,
    };
  }

  /// Konversi string angka ribuan berformat Indonesia ke integer.
  /// Contoh: "150.000,00" atau "150.000" -> 150000
  static int? _parseIndonesianNumber(String str) {
    try {
      String cleaned = str;
      // Jika struk memiliki desimal sen (koma diikuti 2 angka di akhir seperti ,00)
      if (cleaned.contains(',')) {
        final parts = cleaned.split(',');
        if (parts.length > 1 && parts[1].length <= 2) {
          cleaned = parts[0]; // Buang bagian desimal sen
        }
      }
      // Hapus titik pemisah ribuan dan karakter non-digit lainnya
      cleaned = cleaned.replaceAll('.', '').replaceAll(RegExp(r'\D'), '');
      return int.tryParse(cleaned);
    } catch (_) {
      return null;
    }
  }
}
