# 📥 Panduan Unduh Laporan Excel untuk Wali Kelas

## 🎯 Fitur Baru
Sekarang Anda dapat mengunduh laporan kehadiran dalam format **Excel (.xlsx)** yang **langsung tersimpan** ke folder **Download** di perangkat Android Anda!

---

## 📱 Langkah-Langkah Mengunduh Laporan

### 1️⃣ **Unduh Laporan Harian**
Untuk mengunduh laporan kehadiran semua siswa pada tanggal tertentu:

1. **Login** sebagai **Wali Kelas**
2. Masuk ke menu **"Daftar Kehadiran Siswa"**
3. **Pilih tanggal** yang diinginkan (gunakan ikon kalender)
4. Tekan tombol **Download** (ikon unduh ⬇️) di **pojok kanan atas**
5. Jika muncul **permintaan izin penyimpanan**, pilih **"Izinkan"** atau **"Allow"**
6. Tunggu proses pembuatan laporan
7. Toast notification hijau akan muncul: **"✅ File tersimpan di folder Download"**
8. Dialog konfirmasi akan muncul dengan informasi:
   - **Lokasi file** (path lengkap)
   - **Ukuran file** (dalam KB)
   - **Instruksi** cara menemukan file
9. Pilih:
   - **"Buka File"** → Langsung membuka Excel
   - **"Tutup"** → File tetap tersimpan di Download

### 2️⃣ **Unduh Riwayat Per Siswa**
Untuk mengunduh riwayat kehadiran satu siswa tertentu:

1. Dari **"Daftar Kehadiran Siswa"**, pilih siswa
2. Tekan **"Lihat Riwayat"**
3. Tekan tombol **Download** (ikon unduh ⬇️) di **pojok kanan atas**
4. Ikuti langkah yang sama seperti di atas

---

## 📂 Cara Menemukan File Excel

### Metode 1: Melalui File Manager
1. Buka aplikasi **"Files"**, **"File Manager"**, atau **"My Files"**
2. Cari folder **"Download"** atau **"Downloads"**
3. File Excel akan ada di sana dengan nama:
   - Laporan harian: `laporan_kehadiran_YYYYMMDD.xlsx`
   - Riwayat siswa: `riwayat_kehadiran_[NISN]_YYYYMMDD.xlsx`

### Metode 2: Langsung Dari Aplikasi
1. Saat dialog konfirmasi muncul, tekan **"Buka File"**
2. File akan langsung terbuka di aplikasi Excel/Spreadsheet

### Metode 3: Melalui Notifikasi Download (jika ada)
1. Geser layar dari atas untuk membuka panel notifikasi
2. Cari notifikasi download file
3. Tap untuk membuka file

---

## ⚠️ Troubleshooting

### ❌ File Tidak Muncul di Folder Download

**Solusi 1: Cek Izin Aplikasi**
1. Buka **Settings** → **Apps** → **Smart Presensee**
2. Tap **Permissions** → **Files and Media** atau **Storage**
3. Pastikan diset ke **"Allow"** atau **"Izinkan"**
4. Coba unduh lagi

**Solusi 2: Cek di Folder Alternatif**
File mungkin tersimpan di:
- `/storage/emulated/0/Download`
- `/storage/emulated/0/Downloads`
- `/sdcard/Download`
- `/sdcard/Downloads`

**Solusi 3: Lihat Log di Android Studio**
1. Jalankan aplikasi melalui **Android Studio** atau **VS Code**
2. Buka tab **Logcat** / **Debug Console**
3. Cari log dengan text:
   - `"Attempting to save file to:"`
   - `"File verification - Exists:"`
   - `"✅ File successfully saved to:"`
4. Log akan menunjukkan path lengkap file

**Solusi 4: Gunakan Tombol "Buka File"**
- Saat dialog konfirmasi muncul, langsung tekan **"Buka File"**
- Ini akan membuka file tanpa perlu mencarinya manual

**Solusi 5: Restart Aplikasi**
1. **Force stop** aplikasi Smart Presensee
2. Buka aplikasi lagi
3. Coba unduh laporan lagi

---

## 📊 Format Laporan Excel

### Laporan Harian
```
LAPORAN KEHADIRAN SISWA
Tanggal: [Tanggal]

╔════╦═══════╦════════════╦═══════╦═════════════╦═══════════╦════════╦═════════╦═══════════╗
║ No ║ NISN  ║ Nama Siswa ║ Kelas ║ Jenis Kel.  ║ Tanggal   ║ Waktu  ║ Status  ║ Metode    ║
╚════╩═══════╩════════════╩═══════╩═════════════╩═══════════╩════════╩═════════╩═══════════╝

REKAPITULASI KEHADIRAN
Total Siswa: [jumlah]
Hadir:       [jumlah]
Sakit:       [jumlah]
Izin:        [jumlah]
Alpha:       [jumlah]
```

### Riwayat Per Siswa
```
RIWAYAT KEHADIRAN SISWA
Nama:  [Nama]
NISN:  [NISN]
Kelas: [Kelas]

╔════╦═══════════╦════════╦═════════╦═══════════╗
║ No ║ Tanggal   ║ Waktu  ║ Status  ║ Metode    ║
╚════╩═══════════╩════════╩═════════╩═══════════╝

REKAPITULASI KEHADIRAN
Total Presensi: [jumlah]
Hadir:          [jumlah]
Sakit:          [jumlah]
Izin:           [jumlah]
Alpha:          [jumlah]
```

---

## 📱 Aplikasi untuk Membuka File Excel

File Excel dapat dibuka dengan aplikasi berikut:
- ✅ **Microsoft Excel** (Official)
- ✅ **Google Sheets**
- ✅ **WPS Office**
- ✅ **Polaris Office**
- ✅ **AndrOpen Office**
- ✅ Aplikasi spreadsheet lainnya

---

## 🔍 Informasi Teknis

### Lokasi Penyimpanan Default
```
Android: /storage/emulated/0/Download/
iOS:     [App Documents Directory]
```

### Format File
- **Ekstensi:** `.xlsx`
- **Tipe:** Microsoft Excel 2007+
- **Encoding:** UTF-8
- **Ukuran:** Bervariasi (biasanya 10-100 KB)

### Permissions Required (Android)
- `WRITE_EXTERNAL_STORAGE`
- `READ_EXTERNAL_STORAGE`
- `MANAGE_EXTERNAL_STORAGE` (Android 11+)

---

## 💡 Tips & Trik

1. **Nama File Otomatis:** File diberi nama otomatis dengan tanggal, mudah untuk mengorganisir
2. **Copy Path:** Path file di dialog bisa **di-copy** (long press) untuk dibagikan
3. **File Tetap Ada:** File tidak akan terhapus meskipun aplikasi di-uninstall
4. **Bisa Diedit:** File Excel bisa diedit di aplikasi spreadsheet
5. **Bisa Dibagikan:** File bisa dibagikan via WhatsApp, Email, dll
6. **Backup:** Salin file ke cloud storage (Google Drive, Dropbox) untuk backup

---

## 🆘 Butuh Bantuan?

Jika masih mengalami masalah:
1. Screenshot layar error (jika ada)
2. Screenshot dialog konfirmasi
3. Cek log di Android Studio/VS Code
4. Hubungi developer dengan informasi:
   - Versi Android
   - Model HP
   - Screenshot error
   - Log aplikasi

---

**Versi:** 1.0  
**Terakhir Diperbarui:** Oktober 2025

