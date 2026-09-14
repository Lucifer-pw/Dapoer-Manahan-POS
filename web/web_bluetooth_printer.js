window.WebBluetoothPrinter = {
  mode: null, // 'serial' or 'bluetooth'
  
  // Web Serial (Bluetooth SPP / USB)
  serialPort: null,
  serialWriter: null,

  // Web Bluetooth (BLE)
  device: null,
  characteristic: null,

  isConnected: false,
  deviceName: '',

  isSupported: function() {
    return !!(navigator && (navigator.serial || navigator.bluetooth));
  },

  isSerialSupported: function() {
    return !!(navigator && navigator.serial);
  },

  isBleSupported: function() {
    return !!(navigator && navigator.bluetooth);
  },

  // 1. Connect via Web Serial (Bluetooth SPP & USB - 100% compatible with Iware on Windows)
  connectSerial: async function(baudRate = 9600) {
    if (!navigator.serial) {
      throw new Error("Web Serial tidak didukung pada browser ini. Gunakan Google Chrome atau Microsoft Edge terbaru di Laptop.");
    }

    try {
      const port = await navigator.serial.requestPort();
      if (!port) {
        throw new Error("Tidak ada printer / port yang dipilih.");
      }

      try {
        if (port.readable || port.writable) {
          await port.close();
        }
      } catch (_) {}

      await port.open({ baudRate: baudRate });
      this.serialPort = port;
      this.mode = 'serial';
      this.isConnected = true;
      this.deviceName = "Iware Thermal (Bluetooth/USB)";

      if (navigator.serial.addEventListener) {
        navigator.serial.addEventListener('disconnect', (event) => {
          if (event.port === this.serialPort) {
            this.disconnect();
            if (window.onWebBluetoothDisconnected) {
              window.onWebBluetoothDisconnected();
            }
          }
        });
      }

      return this.deviceName;
    } catch (err) {
      this.isConnected = false;
      this.mode = null;
      throw err;
    }
  },

  // 2. Connect via Web Bluetooth (BLE)
  connectBle: async function() {
    if (!navigator.bluetooth) {
      throw new Error("Web Bluetooth tidak didukung pada browser ini. Gunakan Google Chrome atau Microsoft Edge.");
    }

    const serviceUUIDs = [
      '000018f0-0000-1000-8000-00805f9b34fb',
      'e7810a71-73ae-499d-8c15-faa9aef0c3f2',
      '49535343-fe7d-4ae5-8fa9-9fafd205e455',
      '0000ff00-0000-1000-8000-00805f9b34fb',
      '0000fff0-0000-1000-8000-00805f9b34fb',
      '0000ae00-0000-1000-8000-00805f9b34fb',
      '0000ff02-0000-1000-8000-00805f9b34fb',
      '0000ffe0-0000-1000-8000-00805f9b34fb'
    ];

    const device = await navigator.bluetooth.requestDevice({
      acceptAllDevices: true,
      optionalServices: serviceUUIDs
    });

    if (!device) {
      throw new Error("Tidak ada perangkat yang dipilih.");
    }

    this.device = device;
    this.deviceName = device.name || "Iware Bluetooth Printer";

    await new Promise(r => setTimeout(r, 200));

    let server;
    try {
      server = await device.gatt.connect();
    } catch (e) {
      await new Promise(r => setTimeout(r, 500));
      server = await device.gatt.connect();
    }

    let foundChar = null;
    const services = await server.getPrimaryServices();
    for (const service of services) {
      try {
        const chars = await service.getCharacteristics();
        for (const char of chars) {
          if (char.properties.write || char.properties.writeWithoutResponse) {
            foundChar = char;
            break;
          }
        }
      } catch (err) {
        console.warn("Service characteristic scan warning:", err);
      }
      if (foundChar) break;
    }

    if (!foundChar) {
      throw new Error("Printer terdeteksi sebagai Bluetooth Classic (SPP). Silakan gunakan tombol 'Hubungkan Iware (Bluetooth SPP / USB)' untuk menghubungkan.");
    }

    this.characteristic = foundChar;
    this.mode = 'bluetooth';
    this.isConnected = true;

    device.addEventListener('gattserverdisconnected', () => {
      this.isConnected = false;
      this.characteristic = null;
      this.mode = null;
      if (window.onWebBluetoothDisconnected) {
        window.onWebBluetoothDisconnected();
      }
    });

    return this.deviceName;
  },

  // Default connect handler
  connect: async function() {
    if (this.isSerialSupported()) {
      return await this.connectSerial();
    } else if (this.isBleSupported()) {
      return await this.connectBle();
    } else {
      throw new Error("Browser ini tidak mendukung koneksi printer langsung. Gunakan Google Chrome atau Microsoft Edge.");
    }
  },

  disconnect: async function() {
    if (this.mode === 'serial' && this.serialPort) {
      try {
        if (this.serialWriter) {
          await this.serialWriter.close();
          this.serialWriter = null;
        }
        await this.serialPort.close();
      } catch (_) {}
      this.serialPort = null;
    } else if (this.mode === 'bluetooth' && this.device && this.device.gatt && this.device.gatt.connected) {
      try {
        this.device.gatt.disconnect();
      } catch (_) {}
      this.characteristic = null;
      this.device = null;
    }

    this.isConnected = false;
    this.mode = null;
    return true;
  },

  printData: async function(byteList) {
    if (!this.isConnected) {
      throw new Error("Printer belum terhubung.");
    }

    const data = new Uint8Array(byteList);

    if (this.mode === 'serial' && this.serialPort) {
      const writer = this.serialPort.writable.getWriter();
      try {
        const chunkSize = 1024;
        for (let i = 0; i < data.length; i += chunkSize) {
          const chunk = data.slice(i, i + chunkSize);
          await writer.write(chunk);
          await new Promise(r => setTimeout(r, 20));
        }
      } finally {
        writer.releaseLock();
      }
      return true;
    }

    if (this.mode === 'bluetooth' && this.characteristic) {
      const chunkSize = 100;
      for (let i = 0; i < data.length; i += chunkSize) {
        const chunk = data.slice(i, i + chunkSize);
        if (this.characteristic.writeValueWithoutResponse) {
          await this.characteristic.writeValueWithoutResponse(chunk);
        } else {
          await this.characteristic.writeValue(chunk);
        }
        await new Promise(resolve => setTimeout(resolve, 20));
      }
      return true;
    }

    throw new Error("Koneksi printer tidak aktif.");
  }
};
