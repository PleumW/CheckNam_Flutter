# คู่มือการติดตั้ง Firebase Cloud Functions สำหรับระบบแจ้งเตือน SOS ถึง Admin

ไฟล์ในโฟลเดอร์นี้เป็นระบบ **Cloud Functions** ที่จะทำงานอยู่บน Firebase อัตโนมัติ 24 ชม.
เมื่อมี User ส่งข้อมูลขอความช่วยเหลือ (SOS) ระบบนี้จะส่ง **Push Notification** ไปยังโทรศัพท์มือถือของ Admin ทันที **แม้ว่า Admin จะปิดแอพอยู่ก็ตาม**

---

## วิธีการ Deploy ขึ้น Firebase

### ขั้นตอนที่ 1: ตรวจสอบ Firebase CLI
เปิด Terminal หรือ PowerShell แล้วพิมพ์:
```bash
firebase --version
```
(ถ้ายังไม่มี ให้พิมพ์ `npm install -g firebase-tools`)

### ขั้นตอนที่ 2: ล็อกอิน Firebase (ถ้ายังไม่ได้ล็อกอิน)
```bash
firebase login
```

### ขั้นตอนที่ 3: ติดตั้ง Dependencies ของโฟลเดอร์ functions
```bash
cd functions
npm install
cd ..
```

### ขั้นตอนที่ 4: Deploy ขึ้น Cloud
```bash
firebase deploy --only functions
```

---

## ฟังก์ชันที่มีให้ใช้งาน
1. **`sendSosAlertToAdmins`**: ทำงานอัตโนมัติทันทีที่มีข้อมูลเข้ามาที่ `/sos_requests/{sosId}` โดยจะส่งแจ้งเตือนไปยัง Topic `admin_sos` และส่งไปยัง FCM Token ของ Admin แต่ละคน
2. **`triggerSosAlertHttp`**: ลิงก์ HTTP สำหรับใช้ทดสอบยิง Noti ได้ทันทีโดยไม่ต้องกดผ่านแอพ
