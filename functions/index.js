const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Triggered automatically in real-time whenever a new SOS emergency request
 * is created in Firebase Realtime Database at /sos_requests/{sosId}.
 *
 * This delivers a push notification to all admins even if their app is completely closed.
 */
exports.sendSosAlertToAdmins = functions.database
  .ref("/sos_requests/{sosId}")
  .onCreate(async (snapshot, context) => {
    const sos = snapshot.val();
    if (!sos) {
      console.log("No data found in SOS snapshot");
      return null;
    }

    const sosId = context.params.sosId;
    const userName = sos.userName || "ผู้ประสบภัย";
    const situation = sos.situation || "เหตุฉุกเฉินน้ำท่วม";
    const phone = sos.phoneNumber && sos.phoneNumber !== "-" ? sos.phoneNumber : "ไม่ระบุเบอร์";
    const lat = sos.lat !== undefined && sos.lat !== null ? Number(sos.lat).toFixed(5) : "";
    const lng = sos.lng !== undefined && sos.lng !== null ? Number(sos.lng).toFixed(5) : "";
    const note = sos.note || "";

    const title = `🚨 ด่วน! มีการขอความช่วยเหลือ SOS: ${userName}`;
    const bodyLines = [
      `สถานการณ์: ${situation}`,
      `เบอร์โทร: ${phone}`,
    ];
    if (lat && lng) {
      bodyLines.push(`พิกัด: ${lat}, ${lng}`);
    }
    if (note) {
      bodyLines.push(`หมายเหตุ: ${note}`);
    }
    const body = bodyLines.join(" | ");

    // FCM Payload configured for maximum delivery priority and loud emergency alerts
    const message = {
      topic: "admin_sos",
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: "sos_emergency",
        sosId: String(sosId),
        userName: String(userName),
        phone: String(phone),
        situation: String(situation),
        lat: String(lat),
        lng: String(lng),
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        ttl: 60 * 60 * 24, // 24 hours
        notification: {
          channelId: "sos_emergency_channel",
          priority: "max",
          sound: "default",
          defaultVibrateTimings: true,
          visibility: "public",
          color: "#FF0000",
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: "default",
            badge: 1,
            "interruption-level": "critical",
          },
        },
      },
    };

    try {
      // 1. Send push notification to the admin_sos topic
      const topicResponse = await admin.messaging().send(message);
      console.log("Successfully sent SOS alert to topic 'admin_sos':", topicResponse);

      // 2. Also send directly to any registered admin FCM tokens for redundancy
      try {
        const adminsSnapshot = await admin.database().ref("/admins").once("value");
        if (adminsSnapshot.exists()) {
          const adminsData = adminsSnapshot.val();
          const tokens = [];
          for (const uid in adminsData) {
            const token = adminsData[uid]?.fcm_token;
            if (token && typeof token === "string" && token.length > 10) {
              tokens.push(token);
            }
          }

          if (tokens.length > 0) {
            const multicastMessage = {
              tokens: tokens,
              notification: message.notification,
              data: message.data,
              android: message.android,
              apns: message.apns,
            };
            const directResponse = await admin.messaging().sendEachForMulticast(multicastMessage);
            console.log(`Direct admin tokens delivery: ${directResponse.successCount} succeeded, ${directResponse.failureCount} failed.`);
          }
        }
      } catch (tokenErr) {
        console.warn("Could not send direct admin token messages:", tokenErr);
      }

      // Mark notification as sent in the database
      await admin.database().ref(`/sos_notifications_queue/${sosId}`).update({
        status: "sent",
        sentAt: new Date().toISOString(),
      });

      return { success: true };
    } catch (error) {
      console.error("Error sending SOS notification to admin:", error);
      return { success: false, error: error.message };
    }
  });

/**
 * HTTPS endpoint to test or trigger SOS notification directly via HTTP POST / GET.
 * Useful for debugging, integration tests, or external webhooks.
 */
exports.triggerSosAlertHttp = functions.https.onRequest(async (req, res) => {
  const userName = req.body?.userName || req.query?.userName || "ทดสอบผู้ประสบภัย";
  const situation = req.body?.situation || req.query?.situation || "ทดสอบระบบแจ้งเตือน SOS";
  const phone = req.body?.phone || req.query?.phone || "081-234-5678";

  const message = {
    topic: "admin_sos",
    notification: {
      title: `🚨 [ทดสอบ] มีการขอความช่วยเหลือ SOS: ${userName}`,
      body: `สถานการณ์: ${situation} | เบอร์: ${phone}`,
    },
    data: {
      type: "sos_emergency_test",
      userName: String(userName),
      situation: String(situation),
    },
    android: {
      priority: "high",
      notification: {
        channelId: "sos_emergency_channel",
        priority: "max",
        sound: "default",
      },
    },
  };

  try {
    const response = await admin.messaging().send(message);
    res.status(200).json({ success: true, messageId: response });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});
