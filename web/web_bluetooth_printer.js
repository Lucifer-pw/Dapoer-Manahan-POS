window.WebBluetoothPrinter = {
  device: null,
  characteristic: null,
  isConnected: false,
  deviceName: '',

  isSupported: function() {
    return !!(navigator && navigator.bluetooth);
  },

  connect: async function() {
    if (!navigator.bluetooth) {
      throw new Error("Web Bluetooth tidak didukung pada browser ini. Gunakan Google Chrome atau Microsoft Edge terbaru di Laptop/PC.");
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

    const server = await device.gatt.connect();

    // Search for a writable characteristic across available services
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
      throw new Error("Koneksi berhasil, tetapi tidak ditemukan port pengiriman data (characteristic) pada printer ini.");
    }

    this.characteristic = foundChar;
    this.isConnected = true;

    device.addEventListener('gattserverdisconnected', () => {
      this.isConnected = false;
      this.characteristic = null;
      if (window.onWebBluetoothDisconnected) {
        window.onWebBluetoothDisconnected();
      }
    });

    return this.deviceName;
  },

  disconnect: async function() {
    if (this.device && this.device.gatt && this.device.gatt.connected) {
      this.device.gatt.disconnect();
    }
    this.isConnected = false;
    this.characteristic = null;
    return true;
  },

  printData: async function(byteList) {
    if (!this.characteristic) {
      throw new Error("Printer Web Bluetooth belum terhubung.");
    }

    const data = new Uint8Array(byteList);
    const chunkSize = 100;

    for (let i = 0; i < data.length; i += chunkSize) {
      const chunk = data.slice(i, i + chunkSize);
      if (this.characteristic.writeValueWithoutResponse) {
        await this.characteristic.writeValueWithoutResponse(chunk);
      } else {
        await this.characteristic.writeValue(chunk);
      }
      // Small delay between chunks to allow thermal printer buffer processing
      await new Promise(resolve => setTimeout(resolve, 20));
    }
    return true;
  }
};
