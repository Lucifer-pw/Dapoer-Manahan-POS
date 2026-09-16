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
  connectSerial: async function(baudRate = 9600, forcePicker = false) {
    if (!navigator.serial) {
      throw new Error("Web Serial tidak didukung pada browser ini. Gunakan Google Chrome atau Microsoft Edge terbaru di Laptop.");
    }

    try {
      let port = null;

      // Check for previously authorized ports first (Smart Reconnect without popup)
      if (!forcePicker && navigator.serial.getPorts) {
        try {
          const authorizedPorts = await navigator.serial.getPorts();
          if (authorizedPorts && authorizedPorts.length > 0) {
            console.log("[WebSerial] Found " + authorizedPorts.length + " previously authorized port(s). Attempting direct connection...");
            for (let i = 0; i < authorizedPorts.length; i++) {
              const p = authorizedPorts[i];
              try {
                if (p.readable || p.writable) {
                  try { await p.close(); } catch (_) {}
                }
                await p.open({ baudRate: baudRate });
                port = p;
                console.log("[WebSerial] Connected directly to authorized port without popup!");
                break;
              } catch (openErr) {
                console.warn("[WebSerial] Could not open authorized port " + i + ":", openErr.message);
              }
            }
          }
        } catch (getPortsErr) {
          console.warn("[WebSerial] getPorts error:", getPortsErr);
        }
      }

      // If no authorized port connected or forcePicker requested, show browser picker
      if (!port) {
        console.log("[WebSerial] Showing browser port selector popup...");
        port = await navigator.serial.requestPort();
        if (!port) {
          throw new Error("Tidak ada printer / port yang dipilih.");
        }

        try {
          if (port.readable || port.writable) {
            await port.close();
          }
        } catch (_) {}

        await port.open({ baudRate: baudRate });
      }

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

  // Auto connect in background if an authorized device already exists
  autoConnect: async function() {
    if (this.isConnected) return this.deviceName;

    if (navigator.serial && navigator.serial.getPorts) {
      try {
        const ports = await navigator.serial.getPorts();
        if (ports && ports.length > 0) {
          console.log("[AutoConnect] Attempting background reconnect with authorized serial port...");
          return await this.connectSerial(9600, false);
        }
      } catch (e) {
        console.log("[AutoConnect] Serial autoConnect skipped:", e.message);
      }
    }
    return null;
  },

  // 2. Connect via Web Bluetooth (BLE) - Direct Bluetooth for RPP02N on Windows/Chrome
  connectBle: async function() {
    if (!navigator.bluetooth) {
      throw new Error("Web Bluetooth tidak didukung pada browser ini. Gunakan Google Chrome atau Microsoft Edge.");
    }

    const serviceUUIDs = [
      0x18f0,
      0xffe0,
      0xff00,
      0xfff0,
      0xfee7,
      0xae00,
      0xae30,
      0xff02,
      '000018f0-0000-1000-8000-00805f9b34fb',
      '0000ffe0-0000-1000-8000-00805f9b34fb',
      '0000ff00-0000-1000-8000-00805f9b34fb',
      '0000fff0-0000-1000-8000-00805f9b34fb',
      '0000fee7-0000-1000-8000-00805f9b34fb',
      '0000ae00-0000-1000-8000-00805f9b34fb',
      '0000ae30-0000-1000-8000-00805f9b34fb',
      '0000ff02-0000-1000-8000-00805f9b34fb',
      '49535343-fe7d-4ae5-8fa9-9fafd205e455',
      'e7810a71-73ae-499d-8c15-faa9aef0c3f2',
      '6e400001-b5a3-f393-e0a9-e50e24dcca9e'
    ];

    console.log("[BLE] Requesting Bluetooth device...");
    const device = await navigator.bluetooth.requestDevice({
      acceptAllDevices: true,
      optionalServices: serviceUUIDs
    });

    if (!device) {
      throw new Error("Tidak ada perangkat Bluetooth yang dipilih.");
    }

    this.device = device;
    this.deviceName = device.name || "RPP02N Bluetooth Printer";

    console.log("[BLE] Connecting to GATT server for " + this.deviceName + "...");

    let server = null;
    try {
      server = await device.gatt.connect();
    } catch (err1) {
      console.warn("[BLE] First gatt.connect attempt failed, retrying in 600ms:", err1.message);
      await new Promise(r => setTimeout(r, 600));
      try {
        server = await device.gatt.connect();
      } catch (err2) {
        throw new Error("Gagal menyambungkan ke Bluetooth printer (" + err2.message + "). Pastikan printer menyala dan Bluetooth aktif.");
      }
    }

    if (!server || !server.connected) {
      throw new Error("GATT Server printer tidak terhubung. Coba matikan printer 3 detik dan nyalakan kembali.");
    }

    // Wait 300ms for services to be ready
    await new Promise(r => setTimeout(r, 300));

    let foundChar = null;

    // 1. Check known thermal printer service UUIDs individually
    for (const uuid of serviceUUIDs) {
      try {
        const s = await server.getPrimaryService(uuid);
        if (s) {
          const chars = await s.getCharacteristics();
          for (const c of chars) {
            if (c.properties.write || c.properties.writeWithoutResponse) {
              foundChar = c;
              console.log("[BLE] Found writable characteristic in service " + uuid + ":", c.uuid);
              break;
            }
          }
        }
      } catch (_) {}
      if (foundChar) break;
    }

    // 2. Fallback: try getPrimaryServices() if individual lookups did not find it
    if (!foundChar) {
      try {
        const services = await server.getPrimaryServices();
        for (const service of services) {
          try {
            const chars = await service.getCharacteristics();
            for (const char of chars) {
              if (char.properties.write || char.properties.writeWithoutResponse) {
                foundChar = char;
                console.log("[BLE] Found writable char from getPrimaryServices:", char.uuid);
                break;
              }
            }
          } catch (_) {}
          if (foundChar) break;
        }
      } catch (errServices) {
        console.warn("[BLE] getPrimaryServices fallback warning:", errServices.message);
      }
    }

    if (!foundChar) {
      throw new Error("Layanan cetak Bluetooth tidak ditemukan pada perangkat '" + this.deviceName + "'. Pastikan Anda memilih printer RPP02N.");
    }

    this.characteristic = foundChar;
    this.mode = 'bluetooth';
    this.isConnected = true;

    device.addEventListener('gattserverdisconnected', () => {
      console.log("[BLE] Printer disconnected");
      this.isConnected = false;
      this.characteristic = null;
      this.mode = null;
      if (window.onWebBluetoothDisconnected) {
        window.onWebBluetoothDisconnected();
      }
    });

    console.log("[BLE] Successfully connected to " + this.deviceName);
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

    let data;
    if (byteList instanceof Uint8Array) {
      data = byteList;
    } else if (Array.isArray(byteList)) {
      data = new Uint8Array(byteList);
    } else if (byteList && typeof byteList === 'object') {
      const len = byteList.length || 0;
      data = new Uint8Array(len);
      for (let i = 0; i < len; i++) {
        data[i] = byteList[i];
      }
    } else {
      data = new Uint8Array(byteList || []);
    }

    if (this.mode === 'serial' && this.serialPort) {
      if (!this.serialPort.writable) {
        throw new Error("Port serial printer tidak siap menerima data. Coba putus dan hubungkan ulang.");
      }
      const writer = this.serialPort.writable.getWriter();
      try {
        const chunkSize = 256;
        for (let i = 0; i < data.length; i += chunkSize) {
          const chunk = data.slice(i, i + chunkSize);
          await writer.write(chunk);
          await new Promise(r => setTimeout(r, 25));
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
