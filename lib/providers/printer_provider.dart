import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/services.dart';

class PrinterProvider extends ChangeNotifier {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isConnected = false;
  bool _isLoading = false;

  List<BluetoothDevice> get devices => _devices;
  BluetoothDevice? get selectedDevice => _selectedDevice;
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;

  PrinterProvider() {
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    try {
      bool? isConnected = await bluetooth.isConnected;
      _isConnected = isConnected ?? false;
      
      _devices = await bluetooth.getBondedDevices();
      
      bluetooth.onStateChanged().listen((state) {
        switch (state) {
          case BlueThermalPrinter.CONNECTED:
            _isConnected = true;
            break;
          case BlueThermalPrinter.DISCONNECTED:
          case BlueThermalPrinter.DISCONNECT_REQUESTED:
          case BlueThermalPrinter.STATE_TURNING_OFF:
          case BlueThermalPrinter.STATE_OFF:
          case BlueThermalPrinter.ERROR:
            _isConnected = false;
            // Optionally _selectedDevice = null;
            break;
          case BlueThermalPrinter.STATE_ON:
            getDevices();
            break;
          default:
            break;
        }
        notifyListeners();
      });
    } catch (e) {
      debugPrint("Bluetooth Init Error: $e");
    }
    
    notifyListeners();
  }

  Future<void> getDevices() async {
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
    _isLoading = true;
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
    try {
      await bluetooth.disconnect();
      _isConnected = false;
      notifyListeners();
    } on PlatformException catch (e) {
      debugPrint("Error disconnecting: $e");
    }
  }
}
