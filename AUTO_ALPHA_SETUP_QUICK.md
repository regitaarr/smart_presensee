# 🚀 Quick Setup - Auto Alpha pada Jam 13:56

## ✅ Yang Sudah Dikerjakan

Sistem auto-alpha **SUDAH SIAP** dan **OTOMATIS AKTIF**!

### 1️⃣ Flutter Scheduler Service ✅
- ✅ File: `lib/services/alpha_scheduler_service.dart` 
- ✅ Otomatis start saat aplikasi berjalan
- ✅ Cek setiap 30 detik
- ✅ Generate alpha 1 menit setelah jam selesai presensi
  - Default: Jam selesai 13:55 → Generate alpha jam **13:56**

### 2️⃣ Integration di Main App ✅
- ✅ Scheduler otomatis start di `lib/main.dart`
- ✅ Berjalan background saat app aktif

### 3️⃣ Admin Dashboard ✅
- ✅ Card status scheduler di dashboard
- ✅ Tombol manual trigger
- ✅ Monitoring real-time

### 4️⃣ Cloud Functions (Optional) ✅
- ✅ File: `functions/index.js`
- ✅ Ready untuk deploy
- ⏳ Perlu deploy manual (lihat cara di bawah)

---

## 🎯 Cara Kerja

### Otomatis (Setiap Hari):
1. Jam 13:56 WIB, scheduler otomatis jalan
2. Cek siswa yang belum presensi hari ini
3. Generate status ALPHA untuk siswa tersebut
4. Simpan ke Firestore collection `presensi`
5. Kirim email notifikasi ke orang tua
6. Data muncul di laporan

### Manual (Kapan Saja):
1. Login sebagai Admin
2. Lihat dashboard
3. Klik tombol "Jalankan" di card "Auto-Alpha Scheduler"
4. Konfirmasi, selesai!

---

## 📱 Testing

### Test Sekarang:
1. Jalankan aplikasi
2. Login sebagai Admin
3. Di dashboard, klik tombol **"Jalankan"** di card biru "Auto-Alpha Scheduler"
4. Konfirmasi
5. Cek hasilnya di "Data Presensi" atau "Laporan"

### Lihat Log:
```
🔄 Starting Alpha Scheduler...
✅ Alpha Scheduler started
⏰ Waktu auto-alpha: 13:56
✅ Generated alpha for: [Nama Siswa]
📧 Email alpha sent to: [email]
```

---

## ⚙️ Konfigurasi

### Mengubah Waktu Auto-Alpha:

**Cara 1: Ubah Jam Selesai Presensi**
1. Login Admin → Dashboard
2. Lihat card "Pembatasan Waktu Presensi"
3. Ubah jam selesai di Firestore (akan dijelaskan di admin settings)
4. Auto-alpha akan jalan 1 menit setelah jam tersebut

**Cara 2: Edit Manual di Firestore**
- Collection: `attendance_settings`
- Document: `default_settings`
- Field: `jam_selesai` (contoh: `"14:00"`)
- Auto-alpha akan jalan pada `14:01`

---

## 🌟 Deploy Cloud Functions (Optional tapi Recommended)

Cloud Functions lebih reliable karena berjalan di server, tidak perlu app aktif.

### Setup:
```bash
# 1. Install dependencies
cd functions
npm install

# 2. Login ke Firebase (jika belum)
firebase login

# 3. Deploy
firebase deploy --only functions
```

### Setelah Deploy:
- Function akan jalan **OTOMATIS** setiap hari jam 13:56
- Tidak perlu aplikasi aktif
- Berjalan 24/7 di server Firebase

### Biaya:
- Perlu Firebase Blaze Plan (pay-as-you-go)
- Biaya sangat minimal untuk 1 function per hari
- Estimasi: < $1 per bulan

---

## 📊 Monitoring

### Cek Status:
1. Login Admin
2. Dashboard
3. Lihat card **"Auto-Alpha Scheduler"**
   - Status: AKTIF ✅ / TIDAK AKTIF ❌
   - Eksekusi hari ini: Ya/Tidak

### Cek Data:
1. Menu "Data Presensi"
2. Filter tanggal hari ini
3. Cari status "alpha" dengan metode "auto_generated"

### Cek Email:
- Email dikirim ke `email_orangtua` di data siswa
- Cek logs untuk konfirmasi pengiriman

---

## 🔧 Troubleshooting

### ❌ Scheduler tidak jalan?
**Cek:**
- ✅ Aplikasi masih berjalan?
- ✅ Setting aktif? (card hijau di dashboard)
- ✅ Sudah lewat jam selesai + 1 menit?

**Solusi:**
- Restart aplikasi
- Atau gunakan manual trigger

### ❌ Email tidak terkirim?
**Cek:**
- ✅ Email orang tua ada di database siswa?
- ✅ Konfigurasi SMTP sudah benar?

**File config:** `lib/services/email_service.dart`

### ❌ Data tidak muncul di laporan?
**Cek:**
- ✅ Status = "alpha"
- ✅ Tanggal hari ini
- ✅ NISN siswa valid

---

## 📝 Summary

| Fitur | Status |
|-------|--------|
| Flutter Scheduler | ✅ **AKTIF** (otomatis) |
| Manual Trigger | ✅ **TERSEDIA** (admin dashboard) |
| Cloud Functions | ⏳ Siap deploy (optional) |
| Email Notifikasi | ✅ **AKTIF** |
| Data ke Firestore | ✅ **AKTIF** |
| Muncul di Laporan | ✅ **AKTIF** |

---

## 🎉 Done!

Sistem **SUDAH BERJALAN**! 

Pada jam **13:56** setiap hari, siswa yang belum presensi akan otomatis tercatat **ALPHA** dan orang tua mereka akan menerima email notifikasi.

Untuk dokumentasi lengkap, lihat: `AUTO_ALPHA_SCHEDULER.md`

---

**Happy Coding! 🚀**

