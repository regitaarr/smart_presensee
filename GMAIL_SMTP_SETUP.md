# 📧 Panduan Setup Gmail SMTP untuk Smart Presensee

## 🎯 Overview

Sistem Smart Presensee menggunakan **Gmail SMTP** untuk mengirim email notifikasi ke orang tua/wali siswa secara otomatis setelah presensi.

### ✅ Kelebihan Gmail SMTP:
- **Gratis** - Tidak perlu bayar
- **Reliable** - Infrastruktur Google yang stabil
- **Support Mobile** - Bisa dari Android/iOS Flutter app
- **Mudah setup** - Hanya perlu email dan App Password

---

## 🚀 Setup Gmail SMTP (5 Menit)

### **Langkah 1: Siapkan Email Gmail**

Gunakan email Gmail yang akan jadi **pengirim** notifikasi.

**Opsi A: Email Sekolah (Rekomendasi)**
```
Contoh: presensee@namasekolah.sch.id
atau:   noreply@namasekolah.com
```

**Opsi B: Email Pribadi**
```
Contoh: yourname@gmail.com
```

> ⚠️ **JANGAN** gunakan email admin pribadi untuk produksi!

---

### **Langkah 2: Aktifkan 2-Step Verification**

Gmail App Password hanya bisa dibuat jika **2-Step Verification** sudah aktif.

#### **Cara Aktifkan:**

1. **Buka:** https://myaccount.google.com/security

2. **Scroll ke:** "2-Step Verification"

3. **Klik "Get Started"**

4. **Ikuti instruksi:**
   - Masukkan nomor HP
   - Verifikasi dengan kode SMS
   - Aktifkan 2-Step Verification

5. **Selesai!** ✅

---

### **Langkah 3: Buat App Password**

**App Password** adalah password khusus untuk aplikasi (bukan password Gmail biasa).

#### **Cara Buat App Password:**

1. **Buka:** https://myaccount.google.com/apppasswords

2. **Login** dengan akun Gmail Anda

3. **Pilih:**
   - App: **Mail**
   - Device: **Other (Custom name)**

4. **Ketik nama:** `Smart Presensee`

5. **Klik "Generate"**

6. **COPY App Password** yang muncul (16 karakter)
   ```
   Contoh: abcd efgh ijkl mnop
   ```

7. **SIMPAN** App Password ini (JANGAN SHARE KE SIAPA PUN!)

---

### **Langkah 4: Update Konfigurasi di Code**

Buka file: `lib/services/email_service.dart`

**Update baris 10-12:**

```dart
// SEBELUM:
static const String _senderEmail = 'your_email@gmail.com';
static const String _senderPassword = 'your_app_password';
static const String _senderName = 'Smart Presensee';

// SESUDAH (ganti dengan data Anda):
static const String _senderEmail = 'presensee@namasekolah.sch.id'; // Email Gmail Anda
static const String _senderPassword = 'abcd efgh ijkl mnop'; // App Password (16 karakter)
static const String _senderName = 'Smart Presensee - SD Negeri 1'; // Nama pengirim
```

**Contoh Lengkap:**
```dart
class EmailService {
  // Konfigurasi SMTP Gmail
  static const String _senderEmail = 'noreply.smartpresensi@gmail.com';
  static const String _senderPassword = 'abcdefghijklmnop'; // Ganti dengan App Password Anda!
  static const String _senderName = 'Smart Presensee - SDN 1 Jakarta';
```

---

### **Langkah 5: Test Email**

#### **A. Rebuild Aplikasi:**
```bash
flutter pub get
flutter run
```

#### **B. Test Kirim Email:**

Lakukan presensi untuk siswa yang sudah punya `email_orangtua`.

#### **C. Cek Console Log:**
```
📧 Memulai proses pengiriman email untuk NISN: 1234567891
📧 Mengirim email ke: parent@email.com untuk siswa: John Doe
✅ Email berhasil dikirim ke: parent@email.com
Send report: [sendReport details]
```

#### **D. Cek Email Inbox:**
- Buka email orang tua
- Cek folder **Inbox** atau **Spam**
- Subject: `✅ Notifikasi Presensi - [Nama Siswa]`

---

## 🔒 Keamanan

### ⚠️ **PENTING - App Password:**

1. **JANGAN share** App Password ke siapa pun
2. **JANGAN commit** ke Git/GitHub
3. **Simpan di tempat aman** (password manager)
4. **Revoke** jika bocor: https://myaccount.google.com/apppasswords

### 🔐 **Best Practices:**

#### **Opsi 1: Environment Variables (Production)**

Jangan hardcode di code! Gunakan environment variables:

```dart
// Lebih aman (tapi butuh setup tambahan)
static final String _senderEmail = 
    const String.fromEnvironment('SMTP_EMAIL', defaultValue: 'your_email@gmail.com');
static final String _senderPassword = 
    const String.fromEnvironment('SMTP_PASSWORD', defaultValue: '');
```

#### **Opsi 2: Firebase Remote Config**

Simpan credentials di Firebase Remote Config (lebih advanced).

#### **Opsi 3: .env File + .gitignore**

Untuk development:
```dart
// 1. Install flutter_dotenv
// 2. Buat .env file
// 3. Tambah .env ke .gitignore
// 4. Load dari .env
```

---

## 📊 Gmail Limits

### **Batas Pengiriman Gmail:**

| Tipe Akun | Limit Per Hari | Limit Per Email |
|-----------|----------------|-----------------|
| Gmail Gratis | 500 email/hari | 500 recipients |
| Google Workspace | 2,000 email/hari | 2,000 recipients |

### **Kalkulasi Kebutuhan:**

**Contoh: Sekolah dengan 300 siswa**
- Jika semua siswa presensi dalam 1 hari: **300 email**
- Status: ✅ **AMAN** (di bawah limit 500)

**Jika lebih dari 500 siswa:**
- Gunakan **Google Workspace** (berbayar)
- Atau pakai multiple Gmail accounts
- Atau pakai SendGrid (5,000 email/bulan gratis)

---

## 🐛 Troubleshooting

### **Error: "Username and Password not accepted"**

**Penyebab:**
- App Password salah
- 2-Step Verification belum aktif
- Copy-paste dengan spasi

**Solusi:**
1. Generate App Password baru
2. Copy tanpa spasi: `abcdefghijklmnop` (16 karakter)
3. Update di code

---

### **Error: "SMTP Connection Failed"**

**Penyebab:**
- Internet tidak stabil
- Firewall block port 587/465
- Gmail server down (jarang)

**Solusi:**
1. Cek koneksi internet
2. Coba pakai WiFi lain
3. Tunggu beberapa menit, coba lagi

---

### **Email Masuk ke Spam**

**Penyebab:**
- Email baru pertama kali kirim
- Isi email mirip spam
- Belum ada SPF/DKIM record

**Solusi:**
1. Minta orang tua **whitelist** email sender
2. Tambahkan ke contact Gmail
3. Mark as "Not Spam"
4. Setelah beberapa kali, otomatis masuk Inbox

---

### **Email Tidak Terkirim (No Error)**

**Debugging:**

1. **Cek log di console:**
   ```
   📧 Memulai proses pengiriman email...
   ❌ Error saat kirim email: [error message]
   ```

2. **Cek Firestore `email_logs`:**
   - `success: false`
   - Lihat `error_message`

3. **Cek email orang tua tersedia:**
   ```dart
   // Di Firestore collection 'siswa'
   {
     "email_orangtua": "parent@email.com" // Harus ada!
   }
   ```

---

## ✅ Testing Checklist

Sebelum deploy:

- [ ] 2-Step Verification aktif di Gmail
- [ ] App Password sudah dibuat
- [ ] Email & App Password sudah di-update di code
- [ ] `flutter pub get` sudah dijalankan
- [ ] Test kirim email berhasil
- [ ] Email masuk ke inbox (bukan spam)
- [ ] Log di Firestore `success: true`
- [ ] HTML email tampil dengan benar

---

## 📧 Format Email yang Dikirim

Email yang diterima orang tua akan terlihat seperti ini:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
From: Smart Presensee - SDN 1 Jakarta
      <presensee@namasekolah.sch.id>
      
To:   parent@email.com

Subject: ✅ Notifikasi Presensi - John Doe
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎓 Smart Presensee
   Sistem Presensi Cerdas

Notifikasi Presensi Siswa

Kepada Yth. Orang Tua/Wali dari John Doe,

Kami informasikan bahwa putra/putri Anda 
telah melakukan presensi:

┌─────────────────────────────────┐
│ 👤 Nama Siswa: John Doe         │
│ 🆔 NISN: 1234567890             │
│ 🏫 Kelas: 5A                    │
│ 📅 Tanggal: Jumat, 3 Okt 2025   │
│ 🕐 Waktu: 07:30 WIB             │
│ ✅ Status: HADIR                │
└─────────────────────────────────┘

✅ Putra/putri Anda telah hadir tepat waktu.
   Terima kasih atas kedisiplinannya!

Hormat kami,
Tim Smart Presensee

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📧 Email ini dikirim secara otomatis.
   Jangan membalas email ini.
```

---

## 🔄 Alternative: SendGrid (Jika Gmail Tidak Cukup)

Jika Gmail limit tidak cukup, gunakan SendGrid:

### **SendGrid Features:**
- ✅ **5,000 email/bulan** gratis
- ✅ Support API
- ✅ Better deliverability
- ✅ Email analytics

### **Setup SendGrid:**
1. Daftar: https://sendgrid.com/
2. Buat API Key
3. Install: `http` package (sudah ada)
4. Ganti SMTP dengan SendGrid API

---

## 📞 Support

Jika ada masalah:

1. **Cek dokumentasi:** File ini
2. **Cek Gmail Help:** https://support.google.com/mail
3. **Cek console logs:** untuk error details
4. **Cek Firestore:** collection `email_logs`

---

## 📝 Summary

### **Yang Perlu Disiapkan:**
1. ✅ Email Gmail
2. ✅ 2-Step Verification aktif
3. ✅ App Password (16 karakter)
4. ✅ Update di `email_service.dart`

### **Limit:**
- 500 email/hari (Gmail gratis)
- 2,000 email/hari (Google Workspace)

### **Keamanan:**
- ⚠️ JANGAN share App Password
- ⚠️ JANGAN commit ke Git
- ✅ Simpan di tempat aman

---

**Version:** 2.0.0 (SMTP)  
**Date:** October 3, 2025  
**Method:** Gmail SMTP (Mailer Package)

**Status:** ✅ READY FOR MOBILE APPS

---

🎉 **Email notifikasi siap digunakan untuk Android & iOS!**
