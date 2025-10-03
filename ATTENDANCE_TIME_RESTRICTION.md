# Fitur Pembatasan Waktu Presensi

## 📋 Deskripsi
Fitur ini memungkinkan admin untuk mengatur batasan waktu presensi siswa. Siswa hanya dapat melakukan presensi pada rentang waktu yang ditentukan (misalnya: 06:30 - 13:55 WIB).

## ✨ Fitur Utama

### 1. **Pengaturan Waktu Presensi**
   - **Jam Mulai**: Waktu mulai dimana siswa dapat melakukan presensi
   - **Jam Selesai**: Waktu akhir dimana presensi ditutup
   - **Status Aktif/Non-Aktif**: Admin dapat mengaktifkan atau menonaktifkan pembatasan waktu

### 2. **Validasi Otomatis**
   - Sistem secara otomatis memvalidasi waktu saat siswa melakukan presensi
   - Jika di luar waktu yang ditentukan, presensi akan ditolak dengan pesan yang jelas

### 3. **Pesan Error yang Informatif**
   - **Sebelum Jam Mulai**: "Presensi belum dibuka. Waktu presensi mulai pukul XX:XX WIB"
   - **Setelah Jam Selesai**: "Waktu presensi sudah berakhir. Presensi ditutup pukul XX:XX WIB"

## 🎯 Cara Menggunakan

### Untuk Admin

#### 1. **Mengakses Pengaturan**
   - Login sebagai Admin
   - Buka menu **"Pengaturan"** di sidebar dashboard
   - Halaman pengaturan waktu presensi akan terbuka

#### 2. **Mengatur Waktu Presensi**
   - **Aktifkan/Nonaktifkan Pembatasan**:
     - Toggle switch di bagian atas untuk mengaktifkan atau menonaktifkan fitur
     - Jika dinonaktifkan, siswa dapat presensi kapan saja
   
   - **Atur Jam Mulai**:
     - Klik pada card "Jam Mulai Presensi"
     - Pilih waktu menggunakan time picker
     - Contoh: 06:30 (jam 6 pagi 30 menit)
   
   - **Atur Jam Selesai**:
     - Klik pada card "Jam Selesai Presensi"
     - Pilih waktu menggunakan time picker
     - Contoh: 13:55 (jam 1 siang 55 menit)
   
   - **Simpan Pengaturan**:
     - Klik tombol "Simpan Pengaturan" di bagian bawah
     - Sistem akan menampilkan notifikasi sukses jika berhasil

#### 3. **Setting Default**
   - **Jam Mulai Default**: 06:30 WIB
   - **Jam Selesai Default**: 13:55 WIB
   - **Status Default**: Aktif

### Untuk Siswa

#### 1. **Melakukan Presensi**
   - Siswa melakukan face recognition seperti biasa
   - Sistem akan otomatis mengecek waktu saat ini
   
#### 2. **Jika Berhasil**
   - Presensi tersimpan jika waktu sekarang berada di antara jam mulai dan jam selesai
   - Email notifikasi dikirim ke orang tua (jika fitur email aktif)

#### 3. **Jika Gagal**
   - Dialog error muncul dengan pesan:
     - **Terlalu Pagi**: "Presensi belum dibuka. Waktu presensi mulai pukul 06:30 WIB"
     - **Terlalu Sore**: "Waktu presensi sudah berakhir. Presensi ditutup pukul 13:55 WIB"
   - Presensi tidak tersimpan

## 🏗️ Struktur File

### Model
```
lib/model/attendance_settings.dart
```
Model untuk menyimpan pengaturan waktu presensi:
- `id`: ID dokumen di Firestore
- `jamMulai`: Jam mulai presensi (format: "HH:mm")
- `jamSelesai`: Jam selesai presensi (format: "HH:mm")
- `aktif`: Status aktif/non-aktif (boolean)

### Service
```
lib/services/attendance_time_helper.dart
```
Helper service untuk:
- `checkAttendanceTime()`: Mengecek apakah waktu sekarang valid untuk presensi
- `getSettings()`: Mengambil pengaturan dari Firestore
- `updateSettings()`: Menyimpan pengaturan ke Firestore

### UI Admin
```
lib/admin/admin_attendance_settings.dart
```
Halaman pengaturan waktu presensi untuk admin dengan fitur:
- Time picker untuk jam mulai dan jam selesai
- Toggle switch untuk aktif/non-aktif
- Info box yang menampilkan rentang waktu presensi
- Tombol simpan pengaturan

### Integrasi
```
lib/screens/authenticate_screen.dart
```
Dimodifikasi untuk menambahkan validasi waktu presensi sebelum menyimpan data.

## 🗄️ Struktur Database Firestore

### Collection: `attendance_settings`

#### Document: `default_settings`
```json
{
  "id": "default_settings",
  "jam_mulai": "06:30",
  "jam_selesai": "13:55",
  "aktif": true
}
```

**Field Descriptions:**
- `id` (String): Identifier dokumen
- `jam_mulai` (String): Jam mulai presensi dalam format "HH:mm"
- `jam_selesai` (String): Jam selesai presensi dalam format "HH:mm"
- `aktif` (Boolean): Status pembatasan waktu (true = aktif, false = non-aktif)

## 🔄 Alur Validasi

```
┌─────────────────────────┐
│ Siswa Melakukan Face    │
│ Recognition             │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Wajah Cocok?            │
└───────────┬─────────────┘
            │ Ya
            ▼
┌─────────────────────────┐
│ Ambil Setting Waktu     │
│ dari Firestore          │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Setting Aktif?          │
└───────────┬─────────────┘
            │ Ya
            ▼
┌─────────────────────────┐
│ Cek Waktu Sekarang:     │
│ Apakah dalam rentang?   │
└───────────┬─────────────┘
            │
     ┌──────┴──────┐
     │             │
   Ya│             │Tidak
     │             │
     ▼             ▼
┌─────────┐   ┌────────────┐
│ Simpan  │   │ Tolak &    │
│ Presensi│   │ Tampilkan  │
│         │   │ Error      │
└─────────┘   └────────────┘
```

## 🎨 UI Screenshot

### Halaman Pengaturan Admin
- **Header**: Card gradient hijau dengan ikon jam dan status
- **Switch**: Toggle untuk aktifkan/nonaktifkan pembatasan
- **Time Cards**: 2 card untuk jam mulai dan jam selesai
- **Info Box**: Menampilkan ringkasan rentang waktu
- **Save Button**: Tombol simpan besar di bagian bawah

### Dialog Error Siswa
- **Terlalu Pagi**: Dialog dengan judul "Waktu Presensi Tidak Valid"
- **Terlalu Sore**: Dialog dengan judul "Waktu Presensi Tidak Valid"
- Pesan jelas mengenai kapan presensi dapat dilakukan

## 📝 Catatan Penting

1. **Format Waktu**: Semua waktu disimpan dalam format 24 jam (HH:mm)
2. **Timezone**: Sistem menggunakan waktu lokal perangkat
3. **Default Values**: Jika belum ada setting, sistem menggunakan default (06:30 - 13:55)
4. **Fail-Safe**: Jika terjadi error saat mengecek waktu, sistem akan mengizinkan presensi (untuk menghindari siswa tidak bisa presensi karena error teknis)
5. **Real-time**: Setting langsung berlaku setelah disimpan, tidak perlu restart aplikasi

## 🔧 Troubleshooting

### Siswa Tidak Bisa Presensi Padahal Waktu Sudah Benar
- Cek apakah pembatasan waktu diaktifkan di halaman pengaturan
- Pastikan jam di perangkat siswa akurat
- Cek setting jam mulai dan jam selesai di halaman pengaturan admin

### Setting Tidak Tersimpan
- Pastikan koneksi internet stabil
- Cek Firebase console untuk memastikan collection `attendance_settings` tersedia
- Lihat log error di console untuk detail masalah

### Waktu di Dialog Error Tidak Sesuai
- Setting mungkin belum tersimpan dengan benar
- Reload halaman pengaturan dan cek nilai jam mulai/selesai
- Simpan ulang pengaturan

## 🚀 Pengembangan Lebih Lanjut

Fitur yang dapat ditambahkan:
1. **Multiple Time Slots**: Mendukung beberapa rentang waktu (misalnya pagi dan sore)
2. **Per-Class Settings**: Pengaturan waktu berbeda untuk setiap kelas
3. **Holiday Management**: Menonaktifkan presensi otomatis di hari libur
4. **Timezone Support**: Mendukung zona waktu yang berbeda
5. **History Log**: Menyimpan riwayat perubahan setting

---

**Dibuat**: Oktober 2025  
**Versi**: 1.0  
**Developer**: Smart Presensee Team
