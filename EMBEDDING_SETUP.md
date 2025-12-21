# 🚀 Setup Embedding-Based Face Recognition

## 📋 Prerequisites

1. **Model TFLite**: Download model `mobilefacenet.tflite` dan letakkan di:
   ```
   assets/models/mobilefacenet.tflite
   ```

2. **Dependencies**: Sudah ditambahkan ke `pubspec.yaml`:
   - `tflite_flutter: ^0.10.4`
   - `image: ^4.1.3`

## 📁 Struktur File yang Dibuat

```
lib/
 ├─ services/
 │   ├─ face_embedding_model.dart      ✅ Model TFLite untuk generate embedding
 │   └─ registered_face_store.dart      ✅ Store embedding wajah terdaftar
 │
 ├─ utils/
 │   ├─ image_utils.dart                ✅ Preprocessing image dari camera
 │   └─ similarity_utils.dart          ✅ Cosine similarity calculation
 │
 ├─ realtime/
 │   └─ realtime_face_handler.dart      ✅ Handler utama realtime recognition
 │
 └─ models/
     └─ face_track_state.dart           ✅ State tracking per wajah
```

## 🔧 Cara Kerja

### 1. **Inisialisasi Sistem**
- Model TFLite di-load saat `initState()`
- Jika model tidak tersedia, sistem fallback ke geometric similarity (metode lama)

### 2. **Load Embedding dari Firebase**
- Saat load wajah terdaftar, sistem akan mencari field `face_embedding` di Firestore
- Format: `List<double>` dengan 128 elemen (embedding 128D)

### 3. **Realtime Processing**
- Setiap frame dari camera di-process oleh `RealtimeFaceHandler`
- Generate embedding 128D dari wajah terdeteksi
- Compare dengan semua embedding terdaftar menggunakan cosine similarity
- Validasi ketat: threshold + gap check + konsistensi frame

### 4. **Konfirmasi Match**
- Jika match valid, trigger callback `onMatchConfirmed`
- Sistem akan cek presensi ganda
- Start konfirmasi otomatis

## 📊 Parameter Konfigurasi

Di `realtime_face_handler.dart`:

```dart
static const double COSINE_THRESHOLD = 0.65;  // ~82.5% similarity
static const double MIN_GAP = 0.12;           // Gap minimal antara best & second
static const int MIN_FRAMES = 6;              // Frame konsisten minimal
static const int LOCK_MS = 2500;              // Lock duration setelah konfirmasi
```

## 🔄 Fallback Mechanism

Jika embedding system tidak tersedia (model tidak ditemukan):
- Sistem otomatis fallback ke **geometric similarity** (metode lama)
- UI tetap sama, tidak ada perubahan
- Semua fitur tetap berfungsi

## 📝 Menyimpan Embedding ke Firebase

Saat register wajah baru, generate embedding dan simpan:

```dart
// Generate embedding dari gambar
final embedding = _embeddingModel.predict(preprocessedImage);

// Simpan ke Firestore
await FirebaseFirestore.instance
    .collection('wajah_siswa')
    .doc(nisn)
    .update({
      'face_embedding': embedding, // List<double> 128 elemen
    });
```

## ✅ Keuntungan Sistem Baru

1. **Akurasi Lebih Tinggi**: Embedding-based lebih akurat dari geometric
2. **Anti False Positive**: Validasi ketat dengan gap check
3. **Identity Lock**: Mencegah drift A → B dengan tracking state
4. **Realtime**: Tetap menggunakan camera realtime + face tracker
5. **On-Device**: Semua processing di device, tidak perlu server

## ⚠️ Catatan Penting

1. **Model TFLite**: Pastikan file `mobilefacenet.tflite` ada di `assets/models/`
2. **Embedding Storage**: Embedding perlu disimpan saat register wajah
3. **Backward Compatible**: Sistem lama tetap berfungsi jika embedding tidak tersedia

## 🐛 Troubleshooting

### Model tidak load
- Pastikan file `mobilefacenet.tflite` ada di `assets/models/`
- Check `pubspec.yaml` sudah include asset path
- Run `flutter pub get` dan `flutter clean` lalu rebuild

### Embedding tidak ditemukan
- Sistem akan fallback ke geometric similarity
- Untuk menggunakan embedding, pastikan field `face_embedding` ada di Firestore

### Match tidak terdeteksi
- Check threshold di `realtime_face_handler.dart`
- Pastikan embedding sudah di-generate dengan benar
- Check log untuk melihat similarity score


