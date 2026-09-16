class WebBluetoothPrinterService {
  static final WebBluetoothPrinterService instance = WebBluetoothPrinterService._();
  WebBluetoothPrinterService._();

  bool get isSupported => false;
  bool get isConnected => false;
  String get deviceName => '';

  void setOnDisconnectedCallback(void Function() callback) {}

  Future<String?> connect() async {
    return null;
  }

  Future<String?> autoConnect() async {
    return null;
  }

  Future<String?> connectSerial({bool forcePicker = false}) async {
    return null;
  }

  Future<String?> connectBle() async {
    return null;
  }

  Future<bool> disconnect() async {
    return false;
  }

  Future<bool> printBytes(List<int> bytes) async {
    return false;
  }
}
