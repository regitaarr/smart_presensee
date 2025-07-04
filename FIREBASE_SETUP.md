# Setup Firebase untuk Smart Presensee

## Masalah yang Ditemui
Error "Missing or insufficient permissions" dan "Error memuat data" terjadi karena aturan keamanan Firestore yang belum dikonfigurasi dengan benar.

## Solusi

### 1. Deploy Aturan Firestore

Jalankan perintah berikut di terminal:

```bash
# Login ke Firebase (jika belum)
firebase login

# Set project
firebase use smart-presensee-app

# Deploy aturan Firestore
firebase deploy --only firestore:rules
```

### 2. Aturan Keamanan Sementara

File `firestore.rules` sudah dikonfigurasi dengan aturan sementara yang mengizinkan semua akses untuk development:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Temporary rules to allow all access for development
    // TODO: Update these rules for production
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

### 3. Aturan Keamanan untuk Production

Setelah aplikasi berfungsi dengan baik, ganti aturan dengan yang lebih aman:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow read access to pengguna collection for authentication
    match /pengguna/{document} {
      allow read: if true; // Allow reading user data for login
      allow write: if request.auth != null; // Allow authenticated users to write
    }
    
    // Allow access to walikelas collection
    match /walikelas/{document} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    
    // Allow access to other collections that might be needed
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 4. Alternatif: Setup Manual di Firebase Console

Jika tidak bisa menggunakan CLI:

1. Buka [Firebase Console](https://console.firebase.google.com/)
2. Pilih project `smart-presensee-app`
3. Buka **Firestore Database** → **Rules**
4. Copy-paste aturan dari file `firestore.rules`
5. Klik **Publish**

### 5. Verifikasi Setup

Setelah deployment, test aplikasi:
1. Coba login dengan email yang valid
2. Periksa apakah data dapat dimuat
3. Periksa console log untuk error

### 6. Troubleshooting

Jika masih ada masalah:

1. **Periksa koneksi internet**
2. **Periksa Firebase project ID** di `firebase_options.dart`
3. **Periksa Google Services JSON** untuk Android
4. **Periksa console log** untuk error detail

### 7. Struktur Database yang Diperlukan

Pastikan koleksi berikut ada di Firestore:
- `pengguna` - Data user untuk login
- `walikelas` - Data wali kelas
- `siswa` - Data siswa
- `jadwal` - Data jadwal pelajaran
- `presensi` - Data kehadiran
- `wajah_siswa` - Data wajah siswa

### 8. Contoh Data User

Untuk testing, tambahkan user di koleksi `pengguna`:

```json
{
  "email": "admin@example.com",
  "password": "123456",
  "nama": "Administrator",
  "role": "admin"
}
```

## Catatan Penting

- Aturan sementara mengizinkan semua akses (tidak aman untuk production)
- Update aturan keamanan sebelum deploy ke production
- Backup data sebelum mengubah aturan
- Test semua fitur setelah deployment 