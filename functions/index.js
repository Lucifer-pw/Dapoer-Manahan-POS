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