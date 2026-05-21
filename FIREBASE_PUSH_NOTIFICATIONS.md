# Panduan Setup Push Notifications (Firebase Cloud Messaging)

Dokumen ini berisi panduan untuk mengaktifkan **Notifikasi Push Melayang (Background & Terminated)** untuk HP Android/iOS menggunakan **Firebase Cloud Functions** dan **Firebase Cloud Messaging (FCM)**.

---

## 1. Persyaratan Awal
1. Firebase Project Anda harus berada di **Blaze Plan** (Pay-as-you-go). Firebase mewajibkan verifikasi kartu kredit/debit untuk mengaktifkan fitur Cloud Functions (tenang saja, kuota gratisnya 2.000.000 panggilan per bulan gratis).
2. Sudah menginstal **Node.js** dan **Firebase CLI** di laptop Anda.

---

## 2. Inisialisasi Firebase Functions
Jalankan perintah berikut di terminal komputer Anda pada folder proyek `resto_pos`:

```bash
# Login ke Firebase CLI jika belum
firebase login

# Inisialisasi Firebase Functions
firebase init functions
```

*   Pilih bahasa: **JavaScript** (atau TypeScript).
*   Gunakan ESLint: **No** (untuk kesederhanaan).
*   Instal dependensi dengan npm: **Yes**.

---

## 3. Menulis Kode Trigger Notifikasi
Buka file `functions/index.js` yang baru saja dibuat oleh Firebase CLI, lalu ganti isinya dengan kode JavaScript berikut:

```javascript
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

/**
 * Trigger otomatis setiap ada pesan baru di koleksi 'chats'
 * Jika pengirimnya adalah 'customer', kirim push notification ke semua perangkat Admin/Kasir.
 */
exports.sendChatNotification = functions.firestore
    .document("chats/{chatId}")
    .onCreate(async (snapshot, context) => {
        const messageData = snapshot.data();
        
        // Hanya kirim notifikasi jika pesan dikirim oleh 'customer'
        if (messageData.sender !== "customer") {
            console.log("Pesan dikirim oleh admin/kasir. Abaikan notifikasi.");
            return null;
        }

        const tableNumber = messageData.tableNumber || "Unknown";
        const messageText = messageData.message || "Mengirim pesan baru";

        console.log(`Mengirim notifikasi untuk chat baru dari Meja ${tableNumber}`);

        // 1. Cari semua token perangkat admin yang aktif
        const usersSnapshot = await admin.firestore().collection("users").get();
        const tokens = [];

        for (const userDoc of usersSnapshot.docs) {
            const userData = userDoc.data();
            // Hanya kirim ke pengguna dengan role 'admin' atau 'kasir'
            if (userData.role === "admin" || userData.role === "kasir") {
                const devicesSnapshot = await userDoc.ref.collection("devices").get();
                devicesSnapshot.forEach(deviceDoc => {
                    const deviceData = deviceDoc.data();
                    if (deviceData.fcmToken) {
                        tokens.push(deviceData.fcmToken);
                    }
                });
            }
        }

        if (tokens.length === 0) {
            console.log("Tidak ada token perangkat admin/kasir yang terdaftar.");
            return null;
        }

        // 2. Buat Payload Notifikasi
        const payload = {
            notification: {
                title: `Chat Baru Meja ${tableNumber}`,
                body: messageText,
            },
            data: {
                click_action: "FLUTTER_NOTIFICATION_CLICK",
                tableNumber: tableNumber,
                type: "chat",
            },
        };

        // 3. Kirim ke semua token menggunakan Multicast
        const response = await admin.messaging().sendEachForMulticast({
            tokens: tokens,
            notification: payload.notification,
            data: payload.data,
            android: {
                priority: "high",
                notification: {
                    sound: "default",
                    channelId: "table_chat_channel",
                },
            },
        });

        console.log(`Berhasil mengirim ${response.successCount} notifikasi. Gagal: ${response.failureCount}`);
        return null;
    });
```

---

## 4. Melakukan Deploy ke Firebase
Setelah kode diganti, jalankan perintah berikut untuk mengunggah fungsi tersebut ke server Firebase:

```bash
firebase deploy --only functions
```

Setelah proses deploy berhasil, setiap kali pelanggan mengirim pesan melalui Web QR Code:
1. Pesan masuk ke Firestore.
2. Server Firebase menangkap dokumen baru tersebut.
3. Fungsi Node.js mencari semua perangkat admin/kasir yang terdaftar dan langsung mengirimkan push notifikasi ke HP mereka secara instan di latar belakang!
