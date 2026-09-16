import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/services.dart';
import '../services/web_bluetooth/web_bluetooth_printer.dart';
import '../services/web_bluetooth/esc_pos_builder.dart';

class PrinterProvider extends ChangeNotifier {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  final WebBluetoothPrinterService _webBt = WebBluetoothPrinterService.instance;

  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isConnected = false;
  bool _isLoading = false;
  bool _isWeb = false;

  // Web Bluetooth state
  bool _isWebConnected = false;
  String _webDeviceName = '';

  /// Flag to prevent auto-reconnect when user explicitly disconnects.
  bool _userRequestedDisconnect = false;

  /// Whether an auto-reconnect attempt is currently in progress.
  bool _isReconnecting = false;

  /// Timer used to debounce rapid disconnect/reconnect cycles caused
  /// by Bluetooth state fluctuations (e.g. Android doze mode, signal hiccup).
  Timer? _reconnectDebounce;

  /// Maximum number of auto-reconnect retries before giving up.
  static const int _maxReconnectAttempts = 3;

  /// Delay between successive reconnect attempts.
  static const Duration _reconnectDelay = Duration(seconds: 3);

  /// Debounce duration — how long we wait after a DISCONNECTED event
  /// before treating it as a real disconnection and attempting reconnect.
  static const Duration _debounceDuration = Duration(seconds: 2);

  List<BluetoothDevice> get devices => _devices;
  BluetoothDevice? get selectedDevice => _selectedDevice;
  bool get isConnected => _isWeb ? _isWebConnected : _isConnected;
  bool get isLoading => _isLoading;
  bool get isWeb => _isWeb;
  bool get isWebSupported => _webBt.isSupported;
  bool get isWebConnected => _isWebConnected;
  String get webDeviceName => _webDeviceName;

  PrinterProvider() {
    _isWeb = kIsWeb;
    if (_isWeb) {
      _webBt.setOnDisconnectedCallback(() {
        _isWebConnected = false;
        _webDeviceName = '';
        notifyListeners();
      });
      // Try background auto-connect on startup
      Future.delayed(const Duration(milliseconds: 600), () {
        tryAutoConnectWeb();
      });
    } else {
      _initBluetooth();
    }
  }

  // ── Web Bluetooth / Serial Methods ──
  Future<bool> tryAutoConnectWeb() async {
    if (!_isWeb || _isWebConnected || _isLoading) return false;
    try {
      final name = await _webBt.autoConnect();
      if (name != null && name.isNotEmpty) {
        _webDeviceName = name;
        _isWebConnected = true;
        notifyListeners();
        debugPrint("Web POS: Auto-connected to printer $name");
        return true;
      }
    } catch (e) {
      debugPrint("Web POS: Auto-connect check error: $e");
    }
    return false;
  }

  Future<bool> connectWebSerial({bool forcePicker = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final name = await _webBt.connectSerial(forcePicker: forcePicker);
      if (name != null && name.isNotEmpty) {
        _webDeviceName = name;
        _isWebConnected = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Web Serial connect error: $e");
      _isWebConnected = false;
      _webDeviceName = '';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> connectWebBle() async {
    _isLoading = true;
    notifyListeners();

    try {
      final name = await _webBt.connectBle();
      if (name != null && name.isNotEmpty) {
        _webDeviceName = name;
        _isWebConnected = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Web BLE connect error: $e");
      _isWebConnected = false;
      _webDeviceName = '';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> connectWebBluetooth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final name = await _webBt.connect();
      if (name != null && name.isNotEmpty) {
        _webDeviceName = name;
        _isWebConnected = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Web Bluetooth connect error: $e");
      _isWebConnected = false;
      _webDeviceName = '';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> disconnectWebBluetooth() async {
    try {
      await _webBt.disconnect();
    } catch (e) {
      debugPrint("Web Bluetooth disconnect error: $e");
    }
    _isWebConnected = false;
    _webDeviceName = '';
    notifyListeners();
  }

  Future<bool> printWebBytes(List<int> bytes) async {
    if (!_isWebConnected) return false;
    try {
      return await _webBt.printBytes(bytes);
    } catch (e) {
      debugPrint("Web Bluetooth print error: $e");
      rethrow;
    }
  }

  Future<void> _initBluetooth() async {
    try {
      bool? isConnected = await bluetooth.isConnected;
      _isConnected = isConnected ?? false;
      
      _devices = await bluetooth.getBondedDevices();
      
      bluetooth.onStateChanged().listen((state) {
        switch (state) {
          case BlueThermalPrinter.CONNECTED:
            // Connection confirmed — cancel any pending reconnect debounce.
            _reconnectDebounce?.cancel();
            _isReconnecting = false;
            _isConnected = true;
            notifyListeners();
            break;

          case BlueThermalPrinter.DISCONNECTED:
          case BlueThermalPrinter.ERROR:
            // Don't react instantly. Debounce to avoid reacting to transient
            // Bluetooth signal fluctuations (common in Android Doze mode).
            _reconnectDebounce?.cancel();
            _reconnectDebounce = Timer(_debounceDuration, () {
              _handleDisconnection();
            });
            break;

          case BlueThermalPrinter.DISCONNECT_REQUESTED:
          case BlueThermalPrinter.STATE_TURNING_OFF:
          case BlueThermalPrinter.STATE_OFF:
            // Bluetooth itself is turning off — mark as disconnected immediately,
            // no point in trying to reconnect.
            _reconnectDebounce?.cancel();
            _isConnected = false;
            _isReconnecting = false;
            notifyListeners();
            break;

          case BlueThermalPrinter.STATE_ON:
            // Bluetooth was just turned back on — refresh devices and
            // attempt reconnect to the last-used printer if applicable.
            getDevices();
            if (_selectedDevice != null && !_userRequestedDisconnect) {
              _attemptAutoReconnect();
            }
            break;

          default:
            break;
        }
      });
    } catch (e) {
      debugPrint("Bluetooth Init Error: $e");
    }
    
    notifyListeners();
  }

  /// Called when a debounced DISCONNECTED/ERROR event fires.
  void _handleDisconnection() {
    _isConnected = false;
    notifyListeners();

    // Only auto-reconnect if the user didn't explicitly request disconnect
    // and we have a known device to reconnect to.
    if (!_userRequestedDisconnect && _selectedDevice != null) {
      _attemptAutoReconnect();
    }
  }

  /// Tries to reconnect to [_selectedDevice] up to [_maxReconnectAttempts] times.
  Future<void> _attemptAutoReconnect() async {
    if (_isReconnecting || _selectedDevice == null) return;
    _isReconnecting = true;

    debugPrint("🔄 Auto-reconnect: starting reconnect to ${_selectedDevice!.name}");

    for (int attempt = 1; attempt <= _maxReconnectAttempts; attempt++) {
      // Safety checks before each attempt.
      if (_isConnected || _userRequestedDisconnect || _selectedDevice == null) {
        _isReconnecting = false;
        return;
      }

      debugPrint("🔄 Auto-reconnect: attempt $attempt/$_maxReconnectAttempts");

      try {
        // First verify we're actually disconnected to avoid double-connect.
        bool? alreadyConnected = await bluetooth.isConnected;
        if (alreadyConnected == true) {
          _isConnected = true;
          _isReconnecting = false;
          notifyListeners();
          debugPrint("✅ Auto-reconnect: already connected!");
          return;
        }

        bool? result = await bluetooth.connect(_selectedDevice!);
        if (result == true) {
          _isConnected = true;
          _isReconnecting = false;
          notifyListeners();
          debugPrint("✅ Auto-reconnect: successfully reconnected!");
          return;
        }
      } on PlatformException catch (e) {
        debugPrint("⚠️ Auto-reconnect attempt $attempt failed: $e");
      } catch (e) {
        debugPrint("⚠️ Auto-reconnect attempt $attempt error: $e");
      }

      // Wait before next retry (unless it's the last attempt).
      if (attempt < _maxReconnectAttempts) {
        await Future.delayed(_reconnectDelay);
      }
    }

    _isReconnecting = false;
    debugPrint("❌ Auto-reconnect: gave up after $_maxReconnectAttempts attempts");
    notifyListeners();
  }

  Future<void> getDevices() async {
    if (_isWeb) return;

    _isLoading = true;
    notifyListeners();
    
    try {
      _devices = await bluetooth.getBondedDevices();
    } on PlatformException catch (e) {
      debugPrint("Error getting bonded devices: $e");
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> connect(BluetoothDevice device) async {
    if (_isWeb) return false;

    _isLoading = true;
    _userRequestedDisconnect = false; // User is actively connecting.
    notifyListeners();
    
    bool? result = false;
    try {
      result = await bluetooth.connect(device);
      if (result == true) {
        _selectedDevice = device;
        _isConnected = true;
      }
    } on PlatformException catch (e) {
      debugPrint("Error connecting: $e");
    }
    
    _isLoading = false;
    notifyListeners();
    return result ?? false;
  }

  Future<void> disconnect() async {
    if (_isWeb) return;

    // Mark as user-initiated so auto-reconnect does NOT kick in.
    _userRequestedDisconnect = true;
    _reconnectDebounce?.cancel();
    _isReconnecting = false;

    try {
      await bluetooth.disconnect();
      _isConnected = false;
      notifyListeners();
    } on PlatformException catch (e) {
      debugPrint("Error disconnecting: $e");
    }
  }

  Future<bool> printTestReceipt() async {
    if (_isWeb) {
      if (!_isWebConnected) {
        throw 'Printer Web Bluetooth/Serial belum terhubung. Silakan hubungkan terlebih dahulu.';
      }
      try {
        final builder = EscPosBuilder();
        builder.feed(1);
        builder.text("DAPOER MANAHAN", align: 1, bold: true, size: 2);
        builder.text("TES KONEKSI PRINTER", align: 1, bold: true);
        builder.divider();
        builder.row("Status:", "BERHASIL (TERKONEKSI)");
        builder.row("Printer:", _webDeviceName.isNotEmpty ? _webDeviceName : "Iware Thermal");
        builder.row("Waktu:", DateTime.now().toString().substring(0, 19));
        builder.divider();
        builder.text("Printer Iware Siap Digunakan!", align: 1, bold: true);
        builder.text("Cetak Struk dari Laptop Lancar", align: 1);
        builder.cut();

        return await _webBt.printBytes(builder.toBytes());
      } catch (e) {
        debugPrint("Error printing web test receipt: $e");
        rethrow;
      }
    }

    if (!_isConnected) return false;
    try {
      bluetooth.printNewLine();
      bluetooth.printCustom("DAPOER MANAHAN", 3, 1);
      bluetooth.printCustom("TES KONEKSI PRINTER", 1, 1);
      bluetooth.printCustom("--------------------------------", 1, 1);
      bluetooth.printLeftRight("Status:", "BERHASIL", 1);
      bluetooth.printLeftRight("Waktu:", DateTime.now().toString().substring(0, 19), 0);
      bluetooth.printCustom("--------------------------------", 1, 1);
      bluetooth.printCustom("Printer siap digunakan!", 1, 1);
      bluetooth.printCustom("Koneksi Bluetooth Lancar", 0, 1);
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.paperCut();
      return true;
    } catch (e) {
      debugPrint("Error printing test receipt: $e");
      return false;
    }
  }

  @override
  void dispose() {
    _reconnectDebounce?.cancel();
    super.dispose();
  }
}
