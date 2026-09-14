import 'dart:html' as html;
import 'dart:js_util' as js_util;

class WebBluetoothPrinterService {
  static final WebBluetoothPrinterService instance = WebBluetoothPrinterService._();
  WebBluetoothPrinterService._() {
    _initListener();
  }

  bool _isConnected = false;
  String _deviceName = '';
  void Function()? _onDisconnected;

  bool get isSupported {
    final jsObj = js_util.getProperty(html.window, 'WebBluetoothPrinter');
    if (jsObj == null) return false;
    try {
      final res = js_util.callMethod(jsObj, 'isSupported', []);
      return res == true;
    } catch (_) {
      return false;
    }
  }

  bool get isConnected => _isConnected;
  String get deviceName => _deviceName;

  void setOnDisconnectedCallback(void Function() callback) {
    _onDisconnected = callback;
  }

  void _initListener() {
    try {
      js_util.setProperty(html.window, 'onWebBluetoothDisconnected', js_util.allowInterop(() {
        _isConnected = false;
        _deviceName = '';
        _onDisconnected?.call();
      }));
    } catch (_) {}
  }

  Future<String?> connect() async {
    final jsObj = js_util.getProperty(html.window, 'WebBluetoothPrinter');
    if (jsObj == null) {
      throw 'Web Bluetooth library belum terinisialisasi. Silakan refresh browser.';
    }

    try {
      final promise = js_util.callMethod(jsObj, 'connect', []);
      final result = await js_util.promiseToFuture(promise);
      _deviceName = result?.toString() ?? 'Printer Iware Bluetooth';
      _isConnected = true;
      return _deviceName;
    } catch (e) {
      _isConnected = false;
      _deviceName = '';
      rethrow;
    }
  }

  Future<bool> disconnect() async {
    final jsObj = js_util.getProperty(html.window, 'WebBluetoothPrinter');
    if (jsObj == null) return false;

    try {
      final promise = js_util.callMethod(jsObj, 'disconnect', []);
      await js_util.promiseToFuture(promise);
      _isConnected = false;
      _deviceName = '';
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> printBytes(List<int> bytes) async {
    final jsObj = js_util.getProperty(html.window, 'WebBluetoothPrinter');
    if (jsObj == null) {
      throw 'Web Bluetooth tidak tersedia.';
    }

    try {
      final promise = js_util.callMethod(jsObj, 'printData', [bytes]);
      final result = await js_util.promiseToFuture(promise);
      return result == true;
    } catch (e) {
      rethrow;
    }
  }
}
