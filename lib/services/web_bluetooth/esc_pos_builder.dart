import 'dart:convert';

class EscPosBuilder {
  final List<int> _bytes = [];
  final int paperWidth; // 32 for 58mm, 48 for 80mm

  EscPosBuilder({this.paperWidth = 32}) {
    reset();
  }

  /// Initialize / Reset printer
  void reset() {
    _bytes.addAll([0x1B, 0x40]); // ESC @
  }

  /// Set Alignment (0: Left, 1: Center, 2: Right)
  void setAlign(int align) {
    _bytes.addAll([0x1B, 0x61, align.clamp(0, 2)]);
  }

  /// Set Bold
  void setBold(bool isBold) {
    _bytes.addAll([0x1B, 0x45, isBold ? 1 : 0]);
  }

  /// Set Text Size (0: Normal, 1: Double Height, 2: Double Width & Height)
  void setSize(int size) {
    if (size == 1) {
      _bytes.addAll([0x1D, 0x21, 0x01]); // Double height
    } else if (size == 2) {
      _bytes.addAll([0x1D, 0x21, 0x11]); // Double width and height
    } else {
      _bytes.addAll([0x1D, 0x21, 0x00]); // Normal
    }
  }

  /// Print Line of Text
  void text(String text, {int align = 0, bool bold = false, int size = 0}) {
    setAlign(align);
    setBold(bold);
    setSize(size);
    _bytes.addAll(latin1.encode(text));
    _bytes.add(0x0A); // LF
  }

  /// Print Left and Right aligned text on the same line
  void row(String left, String right, {bool bold = false, int size = 0}) {
    setAlign(0); // Left align
    setBold(bold);
    setSize(size);

    final totalLen = paperWidth;
    final rightLen = right.length;
    final maxLeftLen = totalLen - rightLen - 1;

    String cleanLeft = left;
    if (cleanLeft.length > maxLeftLen) {
      cleanLeft = cleanLeft.substring(0, maxLeftLen);
    }

    final spaceCount = totalLen - cleanLeft.length - rightLen;
    final spaces = ' ' * (spaceCount > 0 ? spaceCount : 1);

    final line = cleanLeft + spaces + right;
    _bytes.addAll(latin1.encode(line));
    _bytes.add(0x0A);
  }

  /// Print Divider line
  void divider({String char = '-'}) {
    setAlign(1); // Center
    setBold(false);
    setSize(0);
    final line = char * paperWidth;
    _bytes.addAll(latin1.encode(line));
    _bytes.add(0x0A);
  }

  /// Line feed
  void feed([int lines = 1]) {
    for (int i = 0; i < lines; i++) {
      _bytes.add(0x0A);
    }
  }

  /// Cut paper (or feed extra lines for manual tear)
  void cut() {
    feed(3);
    _bytes.addAll([0x1D, 0x56, 0x41, 0x00]); // GS V A 0 (Cut paper)
  }

  /// Get compiled bytes
  List<int> toBytes() => List.unmodifiable(_bytes);
}
