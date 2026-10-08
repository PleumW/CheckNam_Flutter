const admin = require("firebase-admin");

/**
 * SOS Emergency Push Worker (Standalone Daemon)
 * สามารถรันสคริปต์นี้บนคอมพิวเตอร์หรือ Server ได้ทันที:
 *   node sos_push_worker.js
 *
 * สคริปต์นี้จะคอยเฝ้าดู /sos_requests บน Firebase Realtime Database
 * และยิง Push Notification เข้ามือถือของ Admin ทันทีโดยไม่ต้องเปิดใช้ Cloud Functions (ฟรี 100%)
 */

admin.initializeApp({
  projectId: "water-flood-iot",
  databaseURL: "https://water-flood-iot-default-rtdb.asia-southeast1.firebasedatabase.app",
});

const db = admin.database();
console.log("🌊 [SOS Emergency Worker] เริ่มต้นทำงานเรียบร้อย... กำลังเฝ้าระวังเหตุฉุกเฉิน SOS ตลอด 24 ชม.");

const startTime = Date.now() - 30000; // เฉพาะเคสหลังจากเริ่มรัน (ย้อนหลังไม่เกิน 30 วินาที)

db.ref("/sos_requests").on("child_added", async (snapshot) => {
  const sos = snapshot.val();
  const sosId = snapshot.key;
  if (!sos) return;

  const itemTime = sos.timestamp ? new Date(sos.timestamp).getTime() : Date.now();
  if (itemTime < startTime && sos.status !== "pending") return;

  const userName = sos.userName || "ผู้ประสบภัย";
  const situation = sos.situation || "เหตุฉุกเฉินน้ำท่วม";
  const phone = sos.phoneNumber && sos.phoneNumber !== "-" ? sos.phoneNumber : "ไม่ระบุเบอร์โทร";
  const lat = sos.lat !== undefined && sos.lat !== null ? Number(sos.lat).toFixed(5) : "";
  const lng = sos.lng !== undefined && sos.lng !== null ? Number(sos.lng).toFixed(5) : "";

  console.log(`🚨 ตรวจพบการขอความช่วยเหลือ SOS ใหม่: ${userName} (สถานการณ์: ${situation})`);

  const message = {
    topic: "admin_sos",
    notification: {
      title: `🚨 ด่วน! มีการขอความช่วยเหลือ SOS: ${userName}`,
      body: `สถานการณ์: ${situation} | เบอร์: ${phone}${lat ? ` | พิกัด: ${lat}, ${lng}` : ""}`,
    },
    data: {
      type: "sos_emergency",
      sosId: String(sosId),
      userName: String(userName),
      phone: String(phone),
      situation: String(situation),
      lat: String(lat),
      lng: String(lng),
    },
    android: {
      priority: "high",
      notification: {
        channelId: "sos_emergency_channel",
        priority: "max",
        sound: "default",
        color: "#FF0000",
      },
    },
    apns: {
      payload: {
        aps: {
          alert: {
            title: `🚨 ด่วน! มีการขอความช่วยเหลือ SOS: ${userName}`,
            body: `สถานการณ์: ${situation} | เบอร์: ${phone}`,
          },
          sound: "default",
          badge: 1,
        },
      },
    },
  };

  try {
    const res = await admin.messaging().send(message);
    console.log("✅ ยิง Push Notification ไปยัง Admin (topic admin_sos) สำเร็จ:", res);
  } catch (err) {
    console.error("❌ ไม่สามารถยิง Push Notification ได้:", err.message);
  }
});
