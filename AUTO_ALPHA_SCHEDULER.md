# 🤖 Auto-Alpha Scheduler - Dokumentasi

Sistem otomatis untuk menandai siswa yang belum presensi sebagai **ALPHA** pada jam yang ditentukan.

## 📋 Fitur

✅ Scheduler otomatis yang berjalan setiap hari  
✅ Generate alpha untuk siswa yang belum presensi  
✅ Kirim email notifikasi ke orang tua  
✅ Data tersimpan di Firestore dan muncul di laporan  
✅ Manual trigger dari Admin Dashboard  
✅ Status monitoring real-time  

## 🎯 Cara Kerja

### 1. **Flutter App Scheduler** (Lokal)

Scheduler yang berjalan di aplikasi Flutter. Akan aktif selama aplikasi berjalan.

#### Cara Kerja:
- Cek setiap 30 detik apakah sudah waktunya generate alpha
- Waktu eksekusi: **1 menit setelah jam selesai presensi**
  - Contoh: Jika jam selesai `13:55`, maka alpha akan di-generate pada `13:56`
- Hanya dijalankan sekali per hari
- Data tersimpan dengan `metode: 'auto_generated'`

#### Kode Implementasi:
```dart
// lib/services/alpha_scheduler_service.dart
AlphaSchedulerService.startScheduler();
```

#### Sudah Diaktifkan di:
- `lib/main.dart` - Otomatis start saat aplikasi dimulai

#### Kelebihan:
- ✅ Mudah di-setup
- ✅ Terintegrasi langsung dengan app
- ✅ Bisa manual trigger dari dashboard

#### Kekurangan:
- ⚠️ Hanya berjalan saat aplikasi aktif
- ⚠️ Jika app ditutup, scheduler berhenti

---

### 2. **Cloud Functions** (Server Firebase) - RECOMMENDED ⭐

Scheduled function yang berjalan di server Firebase. **Paling reliable dan recommended**.

#### Cara Kerja:
- Berjalan otomatis di server Firebase (tidak perlu app aktif)
- Menggunakan Cloud Scheduler (cron job)
- Default waktu: **Setiap hari jam 13:56 WIB**
- Data tersimpan dengan `metode: 'auto_generated_cloud'`

#### Setup Cloud Functions:

**Step 1: Install Dependencies**
```bash
cd functions
npm install
```

**Step 2: Deploy ke Firebase**
```bash
# Login ke Firebase (jika belum)
firebase login

# Deploy functions
firebase deploy --only functions
```

**Step 3: Verifikasi**
Setelah deploy, Anda akan melihat:
```
✔  Deploy complete!

Functions:
  scheduledAutoAlpha(asia-southeast2)
  manualAutoAlpha(asia-southeast2)
  checkAutoAlphaStatus(asia-southeast2)
```

#### Mengubah Jadwal:
Edit file `functions/index.js`, baris 24:
```javascript
.schedule('56 13 * * *') // Ubah ini untuk mengubah jadwal
```

Format cron: `'minute hour * * *'`
- `'56 13 * * *'` = Setiap hari jam 13:56
- `'0 14 * * *'` = Setiap hari jam 14:00
- `'30 15 * * *'` = Setiap hari jam 15:30

#### Kelebihan:
- ✅ **Sangat reliable** - Berjalan otomatis di server
- ✅ Tidak perlu aplikasi aktif
- ✅ Berjalan 24/7
- ✅ Scalable dan performant

#### Kekurangan:
- ⚠️ Perlu setup Firebase Blaze Plan (pay-as-you-go)
- ⚠️ Ada biaya minimal (tapi sangat murah untuk penggunaan ini)

---

## 🎮 Admin Dashboard

Dashboard admin menyediakan kontrol penuh untuk auto-alpha:

### 1. **Status Scheduler Card**
Menampilkan:
- Status scheduler (Aktif/Tidak Aktif)
- Status eksekusi hari ini
- Tombol manual trigger

### 2. **Manual Trigger**
Admin dapat menjalankan generate alpha kapan saja dengan klik tombol "Jalankan"

### 3. **Monitoring**
Lihat jumlah siswa yang belum presensi secara real-time

---

## 📊 Data yang Tersimpan

Ketika auto-alpha dijalankan, data disimpan di Firestore:

### Collection: `presensi`

```javascript
{
  id_presensi: "idpr040123",      // Auto-generated ID
  nisn: "1234567890",              // NISN siswa
  tanggal_waktu: Timestamp,        // Waktu generate
  status: "alpha",                 // Status presensi
  metode: "auto_generated"         // Atau "auto_generated_cloud"
}
```

### Data Muncul di:
1. ✅ **Data Presensi** - Admin dapat melihat di menu "Data Presensi"
2. ✅ **Laporan** - Data alpha muncul di laporan kehadiran
3. ✅ **Email** - Orang tua menerima notifikasi email otomatis

---

## 🔧 Konfigurasi

### Mengatur Jam Presensi:
1. Login sebagai Admin
2. Lihat card "Pembatasan Waktu Presensi" di Dashboard
3. Jam selesai presensi akan menentukan kapan alpha di-generate
   - Contoh: Jam selesai `13:55` → Alpha generate `13:56`

### Setting di Firestore:
Collection: `attendance_settings`  
Document: `default_settings`

```javascript
{
  id: "default_settings",
  jam_mulai: "06:30",        // Jam mulai presensi
  jam_selesai: "13:55",      // Jam selesai presensi
  aktif: true                // true = restriction aktif
}
```

---

## 🧪 Testing

### Test Flutter Scheduler:
1. Ubah waktu di `alpha_scheduler_service.dart` untuk testing
2. Atau gunakan manual trigger di dashboard

### Test Cloud Functions:
```bash
# Test di local emulator
firebase emulators:start --only functions

# Atau test manual trigger dengan HTTP
curl -X POST https://asia-southeast2-[PROJECT_ID].cloudfunctions.net/manualAutoAlpha

# Check status
curl https://asia-southeast2-[PROJECT_ID].cloudfunctions.net/checkAutoAlphaStatus
```

---

## 📱 Notifikasi Email

Setiap kali alpha di-generate, sistem otomatis mengirim email ke orang tua siswa.

### Template Email:
```
Subject: [Smart Presensee] Notifikasi Kehadiran - ALPHA

Kepada Yth. Orang Tua/Wali dari [Nama Siswa],

Kami informasikan bahwa anak Anda:
- Nama: [Nama Siswa]
- NISN: [NISN]
- Kelas: [Kelas]
- Status: ALPHA (Tidak Hadir)
- Waktu: [Tanggal & Jam]

Status ini tercatat karena tidak melakukan presensi pada hari ini.

Terima kasih.
Smart Presensee System
```

### Email yang Terkirim:
- Hanya siswa yang punya email orang tua di database
- Email diambil dari field `email_orangtua` di collection `siswa`

---

## 🚀 Rekomendasi Penggunaan

### Untuk Production: **Cloud Functions** ⭐
- Paling reliable
- Tidak bergantung pada aplikasi
- Berjalan 24/7 di server

### Untuk Development/Testing: **Flutter Scheduler**
- Lebih mudah untuk testing
- Tidak perlu setup Firebase Blaze Plan
- Cukup untuk testing/demo

### Setup Ideal:
**Gunakan KEDUANYA:**
1. **Cloud Functions** sebagai primary (backup otomatis)
2. **Flutter Scheduler** sebagai secondary (manual control)

Jika Cloud Functions gagal, admin masih bisa manual trigger dari dashboard.

---

## 📝 Log dan Monitoring

### Flutter App Logs:
```dart
log('🔄 Executing auto-alpha generation...');
log('✅ Auto-alpha executed successfully');
log('📊 Alpha count: X');
```

### Cloud Functions Logs:
```bash
# Lihat logs di Firebase Console
firebase functions:log

# Atau di Firebase Console:
# Console → Functions → Logs
```

---

## ❓ Troubleshooting

### Scheduler tidak jalan?
1. ✅ Cek apakah aplikasi masih aktif (untuk Flutter Scheduler)
2. ✅ Cek status di Admin Dashboard
3. ✅ Cek attendance settings aktif atau tidak
4. ✅ Cek logs untuk error

### Cloud Functions tidak jalan?
1. ✅ Verifikasi deploy sukses: `firebase functions:list`
2. ✅ Cek logs: `firebase functions:log`
3. ✅ Verifikasi timezone setting: `timeZone('Asia/Jakarta')`
4. ✅ Cek Firebase Blaze Plan aktif

### Email tidak terkirim?
1. ✅ Cek email orang tua ada di database siswa
2. ✅ Cek konfigurasi SMTP di `email_service.dart`
3. ✅ Cek logs untuk error email

---

## 📞 Support

Jika ada pertanyaan atau masalah:
1. Cek logs di Firebase Console
2. Cek error di Flutter console
3. Review dokumentasi ini
4. Cek konfigurasi Firestore settings

---

## 🎉 Kesimpulan

Sistem Auto-Alpha Scheduler sudah **SIAP DIGUNAKAN**:

✅ Scheduler otomatis aktif saat app berjalan  
✅ Manual trigger tersedia di Admin Dashboard  
✅ Cloud Functions siap untuk deployment  
✅ Email notifikasi otomatis  
✅ Data tersimpan di Firestore dan laporan  

**Jam 13:56 setiap hari, siswa yang belum presensi akan otomatis tercatat ALPHA!** 🎯

