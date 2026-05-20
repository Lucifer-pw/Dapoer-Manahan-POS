import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptScanner {
  /// Memindai file gambar bukti transfer menggunakan Google MLKit dan mengembalikan detail parsing.
  /// Mendukung pencocokan inputAmount dan verifikasi bankAccountName (opsional).
  static Future<Map<String, dynamic>?> scanReceipt(File file, {int? inputAmount, String? bankAccountName}) async {
    final inputImage = InputImage.fromFile(file);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      return parseText(recognizedText.text, inputAmount: inputAmount, bankAccountName: bankAccountName);
    } catch (e) {
      debugPrint("OCR Processing Error: $e");
      return null;
    } finally {
      textRecognizer.close();
    }
  }

  /// Mengekstraksi tanggal, nominal, dan verifikasi nama pemilik rekening dari teks mentah.
  static Map<String, dynamic> parseText(String text, {int? inputAmount, String? bankAccountName}) {
    debugPrint("=== SCAN RECEIPT RAW TEXT ===\n$text\n=============================");
    
    final normalizedText = text.toLowerCase();
    
    // Pre-proses OCR teks untuk memperbaiki salah baca tulisan tangan (seperti '|' atau 'l' dibaca sebagai '1' sebelum digit)
    String processedText = normalizedText;
    processedText = processedText.replaceAllMapped(
      RegExp(r'(?:^|[\s:;.-])([lLiI|/\\\[])(?=\d)'),
      (match) {
        final prefix = match.group(0)![0];
        if (RegExp(r'[\s:;.-]').hasMatch(prefix)) {
          return '${prefix}1';
        }
        return '1';
      }
    );

    // List kandidat tanggal dan nominal beserta posisinya
    final dateCandidates = <Map<String, dynamic>>[];
    final amountCandidates = <Map<String, dynamic>>[];
    
    // 1. CARI SEMUA KANDIDAT TANGGAL
    const monthWords = r'(jan(?:uari)?|feb(?:ruari)?|mar(?:et)?|apr(?:il)?|mei|me[iy]|jun(?:i)?|jul(?:i)?|agu(?:stus)?|ags|sep(?:tember)?|okt(?:ober)?|nov(?:ember)?|des(?:ember)?|january|february|march|april|may|june|july|august|september|october|november|december)';
    
    // Pola A1: Tanggal dengan nama bulan Indonesia/Inggris (misal: 20 Mei 2026 atau 20 May 2026)
    final wordDateRegex1 = RegExp(
      r'\b(\d{1,2})\s*[-/,\s]\s*' + monthWords + r'\s*[-/,\s]\s*(\d{4}|\d{2})\b',
      caseSensitive: false,
    );
    for (final match in wordDateRegex1.allMatches(processedText)) {
      final day = int.tryParse(match.group(1)!) ?? 1;
      final monthStr = match.group(2)!;
      final yearStr = match.group(3)!;
      
      int month = _mapMonthNameToNumber(monthStr);
      int year = int.tryParse(yearStr) ?? DateTime.now().year;
      if (year < 100) year += 2000;
      dateCandidates.add({'date': DateTime(year, month, day), 'index': match.start});
    }

    // Pola A2: Nama bulan di depan (misal: Mei 20, 2026 atau May 20 2026)
    final wordDateRegex2 = RegExp(
      r'\b' + monthWords + r'\s*[-/,\s]\s*(\d{1,2})\s*[-/,\s]\s*(\d{4}|\d{2})\b',
      caseSensitive: false,
    );
    for (final match in wordDateRegex2.allMatches(processedText)) {
      final monthStr = match.group(1)!;
      final day = int.tryParse(match.group(2)!) ?? 1;
      final yearStr = match.group(3)!;
      
      int month = _mapMonthNameToNumber(monthStr);
      int year = int.tryParse(yearStr) ?? DateTime.now().year;
      if (year < 100) year += 2000;
      dateCandidates.add({'date': DateTime(year, month, day), 'index': match.start});
    }

    // Pola B: DD/MM/YYYY atau DD-MM-YYYY (format angka)
    final dateRegex = RegExp(r'\b(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})\b');
    for (final match in dateRegex.allMatches(processedText)) {
      final day = int.tryParse(match.group(1)!) ?? 1;
      final month = int.tryParse(match.group(2)!) ?? 1;
      final yearStr = match.group(3)!;
      int year = int.tryParse(yearStr) ?? DateTime.now().year;
      if (year < 100) year += 2000;
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        dateCandidates.add({'date': DateTime(year, month, day), 'index': match.start});
      }
    }

    // Pola C: YYYY-MM-DD atau YYYY/MM/DD (format ISO)
    final dateRegexISO = RegExp(r'\b(\d{4})[-/](\d{1,2})[-/](\d{1,2})\b');
    for (final match in dateRegexISO.allMatches(processedText)) {
      final year = int.tryParse(match.group(1)!) ?? DateTime.now().year;
      final month = int.tryParse(match.group(2)!) ?? 1;
      final day = int.tryParse(match.group(3)!) ?? 1;
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        dateCandidates.add({'date': DateTime(year, month, day), 'index': match.start});
      }
    }

    // 2. CARI SEMUA KANDIDAT NOMINAL
    // Pola 1: Kata kunci + angka. Contoh: "jumlah transfer: Rp. 150.000"
    final keywordRegex = RegExp(
      r'(?:jumlah|nominal|total|transfer|rp|idr|amount|bayar|value)\s*[:\.-]?\s*(?:rp\.?\s*|idr\s*)?([0-9\.,]+)',
      caseSensitive: false,
    );
    for (final match in keywordRegex.allMatches(processedText)) {
      final matchStr = match.group(1);
      if (matchStr != null) {
        final val = _parseIndonesianNumber(matchStr);
        if (val != null && val >= 1000 && val <= 50000000) {
          amountCandidates.add({'amount': val, 'index': match.start});
        }
      }
    }

    // Pola 2: Angka berformat ribuan umum (misal: 150.000 atau 1,500,000)
    final numRegex = RegExp(r'\b\d{1,3}(?:[\.,]\d{3})+\b');
    for (final match in numRegex.allMatches(processedText)) {
      final matchStr = match.group(0);
      if (matchStr != null) {
        final val = _parseIndonesianNumber(matchStr);
        if (val != null && val >= 1000 && val <= 50000000) {
          amountCandidates.add({'amount': val, 'index': match.start});
        }
      }
    }

    // Pola 3: Angka polos berurutan (misal: 150000)
    final plainNumRegex = RegExp(r'\b\d{4,8}\b');
    for (final match in plainNumRegex.allMatches(processedText)) {
      final matchStr = match.group(0);
      if (matchStr != null) {
        final val = int.tryParse(matchStr);
        if (val != null && val >= 1000 && val <= 50000000) {
          amountCandidates.add({'amount': val, 'index': match.start});
        }
      }
    }

    // 3. PILIH NOMINAL TERBAIK (SELECTION LOGIC)
    int? amount;
    int? amountIndex;

    if (inputAmount != null && inputAmount > 0) {
      // Prioritas 1: Jika nominal input cocok persis dengan salah satu kandidat
      final exactMatch = amountCandidates.firstWhere(
        (c) => c['amount'] == inputAmount,
        orElse: () => <String, dynamic>{},
      );
      if (exactMatch.isNotEmpty) {
        amount = exactMatch['amount'] as int;
        amountIndex = exactMatch['index'] as int;
      } else {
        // Coba cari kecocokan substring mentah di text
        final formattedInput = _formatNumberWithDots(inputAmount);
        final rawIndex = processedText.indexOf(formattedInput);
        if (rawIndex != -1) {
          amount = inputAmount;
          amountIndex = rawIndex;
        } else {
          final plainIndex = processedText.indexOf(inputAmount.toString());
          if (plainIndex != -1) {
            amount = inputAmount;
            amountIndex = plainIndex;
          }
        }
      }
    }

    if (amount == null && amountCandidates.isNotEmpty) {
      // Prioritas 2: Cari kelipatan Rp 50.000 (rate per hari kerja)
      final rateMultiples = amountCandidates.where((c) => (c['amount'] as int) % 50000 == 0).toList();
      if (rateMultiples.isNotEmpty) {
        amount = rateMultiples.first['amount'] as int;
        amountIndex = rateMultiples.first['index'] as int;
      } else {
        amount = amountCandidates.first['amount'] as int;
        amountIndex = amountCandidates.first['index'] as int;
      }
    }

    // 4. PASANGKAN DENGAN TANGGAL TERDEKAT (PROXIMITY PAIRING)
    DateTime? date;
    if (dateCandidates.isNotEmpty) {
      if (amountIndex != null) {
        // Cari tanggal yang paling dekat lokasinya di dalam teks dengan nominal terpilih
        Map<String, dynamic> closestDateCandidate = dateCandidates.first;
        int minDistance = (amountIndex - (closestDateCandidate['index'] as int)).abs();
        
        for (final candidate in dateCandidates) {
          final dist = (amountIndex - (candidate['index'] as int)).abs();
          if (dist < minDistance) {
            minDistance = dist;
            closestDateCandidate = candidate;
          }
        }
        date = closestDateCandidate['date'] as DateTime;
      } else {
        // Jika tidak ada nominal, ambil tanggal pertama
        date = dateCandidates.first['date'] as DateTime;
      }
    }

    // 5. VERIFIKASI NAMA PENERIMA REKENING
    bool? isNameMatched;
    if (bankAccountName != null && bankAccountName.trim().isNotEmpty) {
      final cleanName = bankAccountName.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), ' ').trim();
      final cleanProcessedText = processedText.replaceAll(RegExp(r'[^\w\s]'), ' ');
      
      if (cleanProcessedText.contains(cleanName)) {
        isNameMatched = true;
      } else {
        // Fallback: pecah kata per kata dan pastikan setiap kata dengan panjang > 2 karakter ada dalam teks
        final words = cleanName.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
        if (words.isNotEmpty) {
          isNameMatched = words.every((word) => cleanProcessedText.contains(word));
        } else {
          isNameMatched = false;
        }
      }
    }

    return {
      'rawText': text,
      'date': date,
      'amount': amount,
      'isNameMatched': isNameMatched,
    };
  }

  /// Memetakan nama bulan ke nomor bulannya.
  static int _mapMonthNameToNumber(String monthStr) {
    monthStr = monthStr.toLowerCase();
    if (monthStr.startsWith('jan')) return 1;
    if (monthStr.startsWith('feb')) return 2;
    if (monthStr.startsWith('mar')) return 3;
    if (monthStr.startsWith('apr')) return 4;
    if (monthStr.startsWith('mei') || monthStr.startsWith('may')) return 5;
    if (monthStr.startsWith('jun')) return 6;
    if (monthStr.startsWith('jul')) return 7;
    if (monthStr.startsWith('agu') || monthStr.startsWith('ags') || monthStr.startsWith('aug')) return 8;
    if (monthStr.startsWith('sep')) return 9;
    if (monthStr.startsWith('okt') || monthStr.startsWith('oct')) return 10;
    if (monthStr.startsWith('nov')) return 11;
    if (monthStr.startsWith('des') || monthStr.startsWith('dec')) return 12;
    return 1;
  }

  /// Mengubah nominal angka ke format ribuan bertitik (misal: 150000 -> "150.000")
  static String _formatNumberWithDots(int number) {
    final str = number.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.writeCharCode(str.codeUnitAt(i));
    }
    return buffer.toString();
  }

  /// Konversi string angka ribuan berformat Indonesia atau Inggris ke integer.
  static int? _parseIndonesianNumber(String str) {
    try {
      String cleaned = str.trim();
      // Hapus desimal sen di paling akhir, misal: ,00 atau .00 atau ,-
      cleaned = cleaned.replaceAll(RegExp(r'[,.](?:00|-)\b'), '');
      // Hapus semua karakter non-digit
      cleaned = cleaned.replaceAll(RegExp(r'\D'), '');
      return int.tryParse(cleaned);
    } catch (_) {
      return null;
    }
  }
}
