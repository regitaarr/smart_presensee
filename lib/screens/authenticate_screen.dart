//authenticate_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_presensee/model/face_features.dart';
import 'package:smart_presensee/model/user_model.dart';
import 'package:smart_presensee/screens/authenticated_user_screen.dart';
import 'package:smart_presensee/services/extract_features.dart';
import 'package:smart_presensee/services/email_service.dart';
import 'package:smart_presensee/services/attendance_time_helper.dart';
import 'package:smart_presensee/widgets/realtime_camera_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_face_api/face_api.dart' as regula;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class AuthenticateScreen extends StatefulWidget {
  const AuthenticateScreen({super.key});

  @override
  State<AuthenticateScreen> createState() => _AuthenticateScreenState();
}

class _AuthenticateScreenState extends State<AuthenticateScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    print('════════════════════════════════════════════');
    print('🚀 AUTH SCREEN INITIALIZED');
    print('════════════════════════════════════════════');
    log('AuthenticateScreen initialized');
    
    // Reset flag untuk memastikan state bersih
    _isProcessingAttendance = false;
    _resetRealtimeState(); // pastikan state auto-presensi bersih di awal

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _scaleController.forward();
    });

    // Realtime mode siap dipakai; muat data wajah terdaftar
    print('📥 Loading registered faces...');
    _loadRegisteredFaces();
    _canAuthenticate = true; // tampilkan status section
    print('✅ Can authenticate set to true');
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    FaceDetectorSingleton().close(); // pastikan hanya close sekali
    _nameController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Reset penuh state yang dipakai auto-presensi agar embedding/flag lama tidak terbawa
  void _resetRealtimeState() {
    _lastDetectedTrackingId = null;
    _stableFrameCount = 0;
    _isAutoProcessing = false;
    _inConfirmation = false;
    _hasCompletedAttendance = false;
    _sessionStartTime = DateTime.now();
    _lastCandidateNisn = null;
    _consistentMatchCount = 0;
    _failStreak = 0;
    _candidateMatch = null;
    _candidateStudentName = null;
    _countdownTimer?.cancel();
    _countdown = 3;
    _lastSuccessNotificationTime = null;
    _lastFailureDialogTime = null;
  }

  // Function to generate attendance ID - IMPROVED VERSION with race condition prevention
  Future<String> _generateAttendanceId() async {
    try {
      const String prefix = 'idpr04';
      
      // Retry mechanism untuk mengatasi race condition
      for (int attempt = 0; attempt < 5; attempt++) {
        QuerySnapshot lastRecords = await FirebaseFirestore.instance
            .collection('presensi')
            .where('id_presensi', isGreaterThanOrEqualTo: prefix)
            .where('id_presensi', isLessThan: '${prefix}z')
            .orderBy('id_presensi', descending: true)
            .limit(1)
            .get();

        int nextNumber = 1;

        if (lastRecords.docs.isNotEmpty) {
          String lastId = lastRecords.docs.first.get('id_presensi') as String;
          log('Last attendance ID found: $lastId');

          if (lastId.length >= 10 && lastId.startsWith(prefix)) {
            String lastNumberStr = lastId.substring(6);
            int lastNumber = int.tryParse(lastNumberStr) ?? 0;
            nextNumber = lastNumber + 1;
          }
        }

        String formattedNumber = nextNumber.toString().padLeft(4, '0');
        String newId = '$prefix$formattedNumber';

        if (newId.length != 10) {
          throw Exception('Generated ID length is not 10 characters: $newId');
        }

        // Double check: Pastikan ID belum dipakai
        DocumentSnapshot existingDoc = await FirebaseFirestore.instance
            .collection('presensi')
            .doc(newId)
            .get();

        if (!existingDoc.exists) {
          log('Generated unique attendance ID: $newId (attempt ${attempt + 1})');
          return newId;
        }
        
        log('⚠ ID $newId already exists, retrying... (attempt ${attempt + 1})');
        // Tunggu sebentar sebelum retry untuk menghindari collision
        await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
      }
      
      // Jika semua attempt gagal, gunakan fallback dengan timestamp + random
      throw Exception('Failed to generate unique ID after 5 attempts');
    } catch (e) {
      log('Error generating attendance ID: $e');

      // Fallback ID dengan timestamp + random number untuk uniqueness
      DateTime now = DateTime.now();
      String timeString =
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      int random = math.Random().nextInt(100);
      String randomStr = random.toString().padLeft(2, '0');
      String fallbackId = 'idpr$timeString$randomStr';

      log('Using fallback ID: $fallbackId');
      return fallbackId;
    }
  }

  // Function to check if attendance already exists today - OPTIMIZED VERSION
  Future<bool> _checkTodayAttendance(String nisn) async {
    try {
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
      DateTime endOfDay =
          DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      log('Checking attendance for NISN: $nisn on ${now.toString().substring(0, 10)}');

      // Query with a single field first
      QuerySnapshot existingRecords = await FirebaseFirestore.instance
          .collection('presensi')
          .where('nisn', isEqualTo: nisn)
          .get();

      // Filter the results in memory for the date range
      bool hasAttendance = existingRecords.docs.any((doc) {
        Timestamp timestamp = doc.get('tanggal_waktu') as Timestamp;
        DateTime docDate = timestamp.toDate();
        return docDate.isAfter(startOfDay) && docDate.isBefore(endOfDay);
      });

      if (hasAttendance) {
        // Get the first matching document
        var existingData = existingRecords.docs.firstWhere((doc) {
          Timestamp timestamp = doc.get('tanggal_waktu') as Timestamp;
          DateTime docDate = timestamp.toDate();
          return docDate.isAfter(startOfDay) && docDate.isBefore(endOfDay);
        }).data() as Map<String, dynamic>;

        var existingTime =
            (existingData['tanggal_waktu'] as Timestamp).toDate();
        log('Found existing attendance for NISN $nisn at ${existingTime.toString()}');

        // Get student name from siswa collection
        DocumentSnapshot studentDoc = await FirebaseFirestore.instance
            .collection('siswa')
            .doc(nisn)
            .get();

        String studentName = "siswa";
        if (studentDoc.exists) {
          studentName = studentDoc.get('nama_siswa') as String;
        }

        // Show message in popup dialog - LANGSUNG tanpa guard
        String timeString =
            '${existingTime.hour.toString().padLeft(2, '0')}:${existingTime.minute.toString().padLeft(2, '0')}';
        
        // Tampilkan dialog langsung tanpa delay dan guard karena ini dipanggil SEBELUM konfirmasi
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text(
                  "Presensi Gagal!",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF7043),
                  ),
                ),
                content: Text(
                  "Kamu $studentName sudah melakukan presensi hari ini pada pukul $timeString!",
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6B7280),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        }
      } else {
        log('No existing attendance found for NISN $nisn today');
      }

      return hasAttendance;
    } catch (e) {
      log('Error checking today attendance: $e');
      _showFailureDialog(
        title: "Error",
        description:
            "Terjadi kesalahan saat memeriksa presensi: ${e.toString()}",
      );
      return false;
    }
  }

  // Function to save attendance record - RELIABLE VERSION (Updated without nama field)
  Future<bool> _saveAttendanceRecord(UserModel user) async {
    try {
      if (user.nisn == null || user.nisn!.trim().isEmpty) {
        log('Error: User NISN is null or empty');
        showToast('Error: NISN tidak ditemukan', isError: true);
        return false;
      }

      final String nisn = user.nisn!.trim();
      log('Starting attendance save process for NISN: $nisn');

      // 🕐 Cek waktu presensi terlebih dahulu
      Map<String, dynamic> timeCheck = await AttendanceTimeHelper.checkAttendanceTime();
      if (timeCheck['allowed'] == false) {
        log('Attendance not allowed at this time: ${timeCheck['message']}');
        _showFailureDialog(
          title: "Waktu Presensi Tidak Valid",
          description: timeCheck['message'] ?? 'Presensi hanya dapat dilakukan pada waktu yang ditentukan.',
        );
        return false;
      }

      // NOTE: Pengecekan presensi ganda sudah dilakukan di _onRealtimeFrame() 
      // sebelum fungsi ini dipanggil untuk menghindari race condition dengan dialog konfirmasi

      String attendanceId = await _generateAttendanceId();

      // Updated attendance data without nip field
      Map<String, dynamic> attendanceData = {
        'id_presensi': attendanceId,
        'nisn': nisn,
        'tanggal_waktu': Timestamp.now(),
        'status': 'hadir',
        'metode': 'face_recognition',
      };

      log('Saving attendance data: $attendanceData');

      await FirebaseFirestore.instance
          .collection('presensi')
          .doc(attendanceId)
          .set(attendanceData);

      log('Attendance saved successfully with ID: $attendanceId');

      // Verify the save was successful
      DocumentSnapshot savedDoc = await FirebaseFirestore.instance
          .collection('presensi')
          .doc(attendanceId)
          .get();

      if (savedDoc.exists) {
        log('Verified: Attendance record exists in Firestore');
        showToast(
            'Presensi berhasil dicatat pada ${_formatTime(DateTime.now())}!');
        
        // Kirim notifikasi email ke orang tua
        _sendEmailNotification(nisn, user.name ?? 'Siswa', 'hadir');
        
        return true;
      } else {
        log('Error: Failed to verify saved attendance record');
        showToast('Gagal menyimpan presensi. Silakan coba lagi!',
            isError: true);
        return false;
      }
    } catch (e) {
      log('Error in _saveAttendanceRecord: $e');
      showToast('Terjadi kesalahan saat menyimpan presensi: ${e.toString()}',
          isError: true);
      return false;
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dateTime) {
    List<String> months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
  }

  // Fungsi untuk mengirim notifikasi email ke orang tua
  Future<void> _sendEmailNotification(
      String nisn, String studentName, String status) async {
    try {
      log('📧 Memulai proses pengiriman email untuk NISN: $nisn');

      // Ambil data siswa dari Firestore untuk mendapatkan email orang tua
      DocumentSnapshot studentDoc = await FirebaseFirestore.instance
          .collection('siswa')
          .doc(nisn)
          .get();

      if (!studentDoc.exists) {
        log('⚠️ Data siswa tidak ditemukan untuk NISN: $nisn');
        return;
      }

      Map<String, dynamic> studentData =
          studentDoc.data() as Map<String, dynamic>;

      // Periksa apakah email orang tua tersedia
      String? parentEmail = studentData['email_orangtua'];
      if (parentEmail == null || parentEmail.isEmpty) {
        log('⚠️ Email orang tua tidak tersedia untuk siswa: $studentName');
        return;
      }

      // Ambil data tambahan
      String namaLengkap = studentData['nama_siswa'] ?? studentName;
      String? kelas = studentData['kelas_sw'];

      log('📧 Mengirim email ke: $parentEmail untuk siswa: $namaLengkap');

      // Kirim email menggunakan EmailService
      bool emailSent = await EmailService.sendAttendanceNotification(
        studentName: namaLengkap,
        nisn: nisn,
        parentEmail: parentEmail,
        attendanceStatus: status,
        attendanceTime: DateTime.now(),
        className: kelas,
      );

      if (emailSent) {
        log('✅ Email berhasil dikirim ke: $parentEmail');
      } else {
        log('❌ Gagal mengirim email ke: $parentEmail');
      }
    } catch (e) {
      log('❌ Error saat mengirim email: $e');
      // Tidak menampilkan error ke user karena presensi sudah berhasil
      // Email hanya notifikasi tambahan
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F5E8),
              Color(0xFFFFF3E0),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Modern App Bar
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF2E7D32),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Presensi Face Recognition',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Konten utama: kamera memenuhi layar
              Expanded(
                child: Column(
                  children: [
                    // Date Display (kembali ditampilkan)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF81C784),
                                Color(0xFF66BB6A),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF81C784).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.calendar_today,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Hari Ini',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _formatDate(DateTime.now()),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Kamera memenuhi layar di bawah banner tanggal
                    Expanded(
                      child: Stack(
                        children: [
                          // Camera View
                          RealtimeCameraView(
                            onFrame: (inputImage, faces) {
                              _onRealtimeFrame(inputImage, faces);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: _buildActionSection(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: _buildPetunjukPresensi(),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Member functions
  Future _setImage(Uint8List imageToAuthenticate) async {
    image2.bitmap = base64Encode(imageToAuthenticate);
    image2.imageType = regula.ImageType.PRINTED;

    setState(() {
      _canAuthenticate = true;
    });
  }

  double? _distance(Points? a, Points? b) {
    if (a == null || b == null) return null;
    if (a.x == null || a.y == null || b.x == null || b.y == null) return null;
    return euclideanDistance(a, b);
  }

  /// Konversi InputImage ke Uint8List bitmap untuk Regula FaceSDK
  /// Menggunakan filePath jika tersedia, atau menggunakan cara alternatif
  Future<Uint8List?> _inputImageToBitmap(InputImage inputImage) async {
    try {
      // Coba ambil dari filePath jika tersedia (untuk image picker)
      if (inputImage.filePath != null) {
        try {
          final file = await File(inputImage.filePath!).readAsBytes();
          return file;
        } catch (e) {
          log('⚠️ Error reading file from path: $e', name: 'ImageConversion');
        }
      }
      
      // Untuk realtime camera, kita perlu menggunakan cara lain
      // InputImage dari camera stream tidak memiliki bytes langsung
      // Kita akan menggunakan image2 yang sudah di-set sebelumnya, atau
      // menggunakan cara alternatif dengan mengambil snapshot
      
      // Fallback: gunakan image2 jika sudah di-set (untuk mode manual)
      // Untuk realtime, kita akan menggunakan cara yang berbeda
      log('⚠️ InputImage tidak memiliki filePath, menggunakan alternatif', name: 'ImageConversion');
      
      // Untuk realtime camera, kita perlu mendapatkan bytes dari camera snapshot
      // Tapi karena kita tidak punya akses langsung ke CameraController,
      // kita akan menggunakan pendekatan yang berbeda:
      // Simpan bytes saat InputImage dibuat, atau gunakan cara lain
      
      return null;
    } catch (e) {
      log('❌ Error converting InputImage to bitmap: $e', name: 'ImageConversion');
      return null;
    }
  }

  /// Fungsi compareFaces: Membandingkan landmark via rasio sederhana
  /// Mengembalikan ratio similarity (0.0 - 1.0, semakin tinggi semakin mirip)
  double? compareFaces(FaceFeatures faceA, FaceFeatures faceB) {
    try {
      final List<double> ratios = [];
      
      // 1. Rasio jarak antar mata
      final eyeDistA = _distance(faceA.rightEye, faceA.leftEye);
      final eyeDistB = _distance(faceB.rightEye, faceB.leftEye);
      if (eyeDistA != null && eyeDistB != null && eyeDistA > 0 && eyeDistB > 0) {
        final ratio = math.min(eyeDistA, eyeDistB) / math.max(eyeDistA, eyeDistB);
        ratios.add(ratio);
      }
      
      // 2. Rasio jarak hidung ke mulut
      final noseMouthA = _distance(faceA.noseBase, faceA.bottomMouth);
      final noseMouthB = _distance(faceB.noseBase, faceB.bottomMouth);
      if (noseMouthA != null && noseMouthB != null && noseMouthA > 0 && noseMouthB > 0) {
        final ratio = math.min(noseMouthA, noseMouthB) / math.max(noseMouthA, noseMouthB);
        ratios.add(ratio);
      }
      
      // 3. Rasio jarak mata ke hidung
      final eyeNoseA = _distance(faceA.rightEye, faceA.noseBase);
      final eyeNoseB = _distance(faceB.rightEye, faceB.noseBase);
      if (eyeNoseA != null && eyeNoseB != null && eyeNoseA > 0 && eyeNoseB > 0) {
        final ratio = math.min(eyeNoseA, eyeNoseB) / math.max(eyeNoseA, eyeNoseB);
        ratios.add(ratio);
      }
      
      // 4. Rasio jarak antar mulut
      final mouthA = _distance(faceA.rightMouth, faceA.leftMouth);
      final mouthB = _distance(faceB.rightMouth, faceB.leftMouth);
      if (mouthA != null && mouthB != null && mouthA > 0 && mouthB > 0) {
        final ratio = math.min(mouthA, mouthB) / math.max(mouthA, mouthB);
        ratios.add(ratio);
      }
      
      if (ratios.isEmpty) {
        return null;
      }
      
      // Rata-rata semua rasio
      final avgRatio = ratios.reduce((a, b) => a + b) / ratios.length;
      return avgRatio;
    } catch (e) {
      log('Error in compareFaces: $e', name: 'FaceMatch');
      return null;
    }
  }

  /// Fungsi untuk matching menggunakan compareFaces (fallback)
  /// Mengembalikan UserModel jika match ditemukan, null jika tidak
  Future<UserModel?> _matchFacesWithCompareFaces(
    FaceFeatures? features,
    List<UserModel> registeredUsers,
  ) async {
    if (features == null) {
      return null;
    }
    
    try {
      double bestRatio = 0.0;
      UserModel? bestUser;
      const double ratioThreshold = 0.75; // Threshold untuk compareFaces
      
      for (final user in registeredUsers) {
        if (user.faceFeatures == null) continue;
        
        final ratio = compareFaces(features, user.faceFeatures!);
        if (ratio != null && ratio > bestRatio) {
          bestRatio = ratio;
          bestUser = user;
          
          // Early exit jika ratio sudah cukup tinggi
          if (ratio >= ratioThreshold) {
            log('✅ Early exit: Match found with ratio ${ratio.toStringAsFixed(4)} >= $ratioThreshold', name: 'CompareFaces');
            return user;
          }
        }
      }
      
      if (bestUser != null && bestRatio >= ratioThreshold) {
        return bestUser;
      }
      
      return null;
    } catch (e) {
      log('❌ Error in _matchFacesWithCompareFaces: $e', name: 'CompareFaces');
      return null;
    }
  }

  /// Fungsi untuk matching menggunakan Regula FaceSDK dengan early exit
  /// Mengembalikan UserModel jika match ditemukan (similarity > threshold), null jika tidak
  Future<UserModel?> _matchFacesWithRegula(
    Uint8List capturedImageBytes,
    List<UserModel> registeredUsers,
  ) async {
    try {
      // Threshold similarity (85-88%)
      const double similarityThreshold = 0.86; // 86% sebagai nilai tengah
      
      log('🔍 Starting Regula FaceSDK matching with ${registeredUsers.length} users...', name: 'RegulaMatch');
      
      // Setup captured image untuk Regula
      final capturedImage = regula.MatchFacesImage();
      capturedImage.bitmap = base64Encode(capturedImageBytes);
      capturedImage.imageType = regula.ImageType.PRINTED;
      
      // Loop per user dengan early exit
      for (final user in registeredUsers) {
        try {
          // Skip jika user tidak memiliki gambar
          if (user.gambar == null || user.gambar!.isEmpty) {
            continue;
          }
          
          // Setup stored image untuk Regula
          final storedImage = regula.MatchFacesImage();
          storedImage.bitmap = user.gambar!;
          storedImage.imageType = regula.ImageType.PRINTED;
          
          // Buat request untuk matchFaces
          final request = regula.MatchFacesRequest();
          request.images = [storedImage, capturedImage];
          
          // Panggil Regula FaceSDK.matchFaces
          final responseJson = await regula.FaceSDK.matchFaces(jsonEncode(request));
          final response = regula.MatchFacesResponse.fromJson(json.decode(responseJson));
          
          final results = response?.results;
          if (results == null || results.isEmpty) {
            continue;
          }
          
          // Gunakan similarity threshold split untuk mendapatkan matched faces
          final thresholdSplitJson = await regula.FaceSDK.matchFacesSimilarityThresholdSplit(
            jsonEncode(results),
            similarityThreshold,
          );
          final thresholdSplit = regula.MatchFacesSimilarityThresholdSplit.fromJson(
            json.decode(thresholdSplitJson),
          );
          
          final matchedFaces = thresholdSplit?.matchedFaces;
          if (matchedFaces != null && matchedFaces.isNotEmpty) {
            final matchedFace = matchedFaces.first;
            final similarityValue = matchedFace?.similarity;
            if (similarityValue != null) {
              final similarity = similarityValue * 100;
              log('✅ Match found for NISN ${user.nisn}: ${similarity.toStringAsFixed(2)}%}', name: 'RegulaMatch');
              
              // Early exit: langsung return jika similarity > threshold
              if (similarity >= (similarityThreshold * 100)) {
                log('🎯 Early exit: Match found with similarity ${similarity.toStringAsFixed(2)}% >= ${(similarityThreshold * 100).toStringAsFixed(2)}%', name: 'RegulaMatch');
                return user;
              }
            }
          }
        } catch (e) {
          log('⚠️ Error matching with user ${user.nisn}: $e', name: 'RegulaMatch');
          continue; // Lanjut ke user berikutnya
        }
      }
      
      log('❌ No match found with Regula FaceSDK (threshold: ${(similarityThreshold * 100).toStringAsFixed(2)}%)', name: 'RegulaMatch');
      return null;
    } catch (e) {
      log('❌ Error in _matchFacesWithRegula: $e', name: 'RegulaMatch');
      return null;
    }
  }

  // Skor kemiripan berbasis beberapa metrik; semakin kecil semakin mirip (0 ideal)
  double? computeSimilarityScore(FaceFeatures faceA, FaceFeatures faceB) {
    final List<double> diffs = [];
    
    // Validasi: pastikan minimal ada landmark yang terdeteksi
    int validLandmarks = 0;
    if (faceA.rightEye?.x != null && faceA.leftEye?.x != null) validLandmarks++;
    if (faceA.rightMouth?.x != null && faceA.leftMouth?.x != null) validLandmarks++;
    if (faceA.noseBase?.x != null) validLandmarks++;
    if (faceA.rightCheek?.x != null && faceA.leftCheek?.x != null) validLandmarks++;
    
    // Minimal 3 landmark untuk perbandingan yang seimbang
    if (validLandmarks < 3) {
      log('Insufficient landmarks detected: $validLandmarks (minimum: 3)', name: 'FaceMatch');
      return null;
    }

    // 1. Jarak antar mata (horizontal)
    final eyeA = _distance(faceA.rightEye, faceA.leftEye);
    final eyeB = _distance(faceB.rightEye, faceB.leftEye);
    if (eyeA != null && eyeB != null && eyeA > 0 && eyeB > 0) {
      diffs.add(((eyeA / eyeB) - 1.0).abs());
    }

    // 2. Jarak antar mulut (horizontal)
    final mouthA = _distance(faceA.rightMouth, faceA.leftMouth);
    final mouthB = _distance(faceB.rightMouth, faceB.leftMouth);
    if (mouthA != null && mouthB != null && mouthA > 0 && mouthB > 0) {
      diffs.add(((mouthA / mouthB) - 1.0).abs());
    }

    // 3. Jarak hidung ke mulut (vertical)
    final noseMouthA = _distance(faceA.noseBase, faceA.bottomMouth);
    final noseMouthB = _distance(faceB.noseBase, faceB.bottomMouth);
    if (noseMouthA != null && noseMouthB != null && noseMouthA > 0 && noseMouthB > 0) {
      diffs.add(((noseMouthA / noseMouthB) - 1.0).abs());
    }

    // 4. Jarak antar pipi (horizontal) 
    final cheekA = _distance(faceA.rightCheek, faceA.leftCheek);
    final cheekB = _distance(faceB.rightCheek, faceB.leftCheek);
    if (cheekA != null && cheekB != null && cheekA > 0 && cheekB > 0) {
      diffs.add(((cheekA / cheekB) - 1.0).abs());
    }

    // 5. Jarak mata kanan ke hidung
    final rightEyeNoseA = _distance(faceA.rightEye, faceA.noseBase);
    final rightEyeNoseB = _distance(faceB.rightEye, faceB.noseBase);
    if (rightEyeNoseA != null && rightEyeNoseB != null && rightEyeNoseA > 0 && rightEyeNoseB > 0) {
      diffs.add(((rightEyeNoseA / rightEyeNoseB) - 1.0).abs());
    }

    // 6. Jarak mata kiri ke hidung
    final leftEyeNoseA = _distance(faceA.leftEye, faceA.noseBase);
    final leftEyeNoseB = _distance(faceB.leftEye, faceB.noseBase);
    if (leftEyeNoseA != null && leftEyeNoseB != null && leftEyeNoseA > 0 && leftEyeNoseB > 0) {
      diffs.add(((leftEyeNoseA / leftEyeNoseB) - 1.0).abs());
    }

    // 7. Rasio lebar wajah (mata) dengan tinggi wajah (mata ke mulut)
    final widthA = _distance(faceA.rightEye, faceA.leftEye);
    final heightA = _distance(faceA.rightEye, faceA.bottomMouth);
    final widthB = _distance(faceB.rightEye, faceB.leftEye);
    final heightB = _distance(faceB.rightEye, faceB.bottomMouth);
    if (widthA != null && heightA != null && widthB != null && heightB != null &&
        widthA > 0 && heightA > 0 && widthB > 0 && heightB > 0) {
      final ratioA = widthA / heightA;
      final ratioB = widthB / heightB;
      diffs.add(((ratioA / ratioB) - 1.0).abs());
    }

    // 8. Jarak mata kanan ke pipi kanan
    final rightEyeCheekA = _distance(faceA.rightEye, faceA.rightCheek);
    final rightEyeCheekB = _distance(faceB.rightEye, faceB.rightCheek);
    if (rightEyeCheekA != null && rightEyeCheekB != null && rightEyeCheekA > 0 && rightEyeCheekB > 0) {
      diffs.add(((rightEyeCheekA / rightEyeCheekB) - 1.0).abs());
    }

    // 9. Jarak mata kiri ke pipi kiri
    final leftEyeCheekA = _distance(faceA.leftEye, faceA.leftCheek);
    final leftEyeCheekB = _distance(faceB.leftEye, faceB.leftCheek);
    if (leftEyeCheekA != null && leftEyeCheekB != null && leftEyeCheekA > 0 && leftEyeCheekB > 0) {
      diffs.add(((leftEyeCheekA / leftEyeCheekB) - 1.0).abs());
    }

    // Ears optional; tambahkan jika ada
    final earA = _distance(faceA.rightEar, faceA.leftEar);
    final earB = _distance(faceB.rightEar, faceB.leftEar);
    if (earA != null && earB != null && earA > 0 && earB > 0) {
      diffs.add(((earA / earB) - 1.0).abs());
    }

    // Minimal 4 metrik wajah untuk perbandingan yang seimbang
    if (diffs.isEmpty || diffs.length < 4) {
      log('Insufficient face metrics: ${diffs.length} (minimum: 4)', name: 'FaceMatch');
      return null;
    }
    
    final score = diffs.reduce((a, b) => a + b) / diffs.length;
    log('Score: ${score.toStringAsFixed(4)} (${diffs.length} metrics)', name: 'SimilarityScore');
    return score;
  }

  // Realtime matching state & logic
  final List<UserModel> _registeredUsers = [];
  bool _isLoadingUsers = false;
  DateTime? _lastMatchAttempt;
  bool _hasCompletedAttendance = false;
  
  DateTime _sessionStartTime = DateTime.now();
  static const int _minFailDelayMs = 800; // tunda notif gagal minimal 0.8 detik sejak kamera aktif
  String? _lastCandidateNisn; // konsistensi kandidat agar tidak lompat antar user
  int _consistentMatchCount = 0;
  static const int _minConsistentMatches = 4; // butuh match konsisten berturut-turut sebelum konfirmasi (ditingkatkan untuk akurasi)
  int _failStreak = 0; // smoothing agar wajah terdaftar tidak langsung gagal karena noise

  Future<void> _loadRegisteredFaces() async {
    if (_isLoadingUsers) {
      print('⏭️ Already loading users, skipping...');
      return;
    }
    
    print('════════════════════════════════════════════');
    print('📂 LOADING REGISTERED FACES');
    print('════════════════════════════════════════════');
    
    setState(() {
      _isLoadingUsers = true;
    });
    try {
      log('🔄 Loading registered faces from Firestore...', name: 'LoadFaces');
      print('🔄 Fetching from Firestore collection: wajah_siswa');
      
      final snap = await FirebaseFirestore.instance.collection('wajah_siswa').get();
      print('📦 Found ${snap.docs.length} documents in wajah_siswa');
      log('📦 Found ${snap.docs.length} documents in wajah_siswa collection', name: 'LoadFaces');
      
      _registeredUsers.clear();
      int validCount = 0;
      
      for (var doc in snap.docs) {
        try {
          final user = UserModel.fromJson(doc.data());
          if (user.faceFeatures != null && user.nisn != null) {
            _registeredUsers.add(user);
            validCount++;
            print('  ✓ Added user: NISN ${user.nisn}');
          } else {
            print('  ✗ Skipped: NISN ${user.nisn ?? 'null'} - Missing data');
          }
        } catch (e) {
          print('  ⚠️ Error parsing user: $e');
          log('⚠️ Error parsing user: $e', name: 'LoadFaces');
        }
      }
      
      print('════════════════════════════════════════════');
      print('✅ ✅ ✅ LOADED $validCount REGISTERED FACES');
      print('════════════════════════════════════════════');
      log('✅ ✅ ✅ Loaded $validCount valid registered faces!', name: 'LoadFaces');
      
      if (_registeredUsers.isEmpty) {
        print('❌ WARNING: NO VALID FACE DATA!');
        log('❌ WARNING: No valid face data found!', name: 'LoadFaces');
        showToast('Tidak ada wajah terdaftar di database. Silakan daftarkan wajah terlebih dahulu.', isError: true);
      }
    } catch (e) {
      print('❌ ERROR loading faces: $e');
      log('❌ Error loading registered faces: $e', name: 'LoadFaces');
      showToast('Gagal memuat data wajah', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
        });
      }
      print('🏁 Load faces completed');
    }
  }

  Future<void> _onRealtimeFrame(InputImage inputImage, List<Face> faces) async {
    if (!mounted) return;
    if (_hasCompletedAttendance) return;
    if (_inConfirmation) return;
    
    // Reset stabilization jika tidak ada wajah
    if (faces.isEmpty) {
      if (_lastDetectedTrackingId != null || _stableFrameCount > 0) {
        setState(() {
          _lastDetectedTrackingId = null;
          _stableFrameCount = 0;
        });
        print('🔄 Reset: No face detected');
      }
      return;
    }
    
    // Print untuk debug - wajah terdeteksi
    if (_stableFrameCount == 0) {
      print('👤 Face detected! trackingId: ${faces.first.trackingId}');
    }

    final now = DateTime.now();
    if (_lastMatchAttempt != null &&
        now.difference(_lastMatchAttempt!).inMilliseconds < 200) {
      return; // throttle - dikurangi dari 500ms ke 200ms untuk response lebih cepat
    }
    _lastMatchAttempt = now;

    if (_registeredUsers.isEmpty && !_isLoadingUsers) {
      log('⚠️ No registered users in memory, loading...', name: 'AutoPresensi');
      await _loadRegisteredFaces();
      if (_registeredUsers.isEmpty) {
        log('❌ Cannot proceed - no registered faces found!', name: 'AutoPresensi');
        return;
      }
      log('✅ Loaded ${_registeredUsers.length} users, ready to match!', name: 'AutoPresensi');
    }

    // ===== STABILIZATION LOGIC =====
    // Ambil trackingId dari wajah pertama
    final Face detectedFace = faces.first;
    final int? currentTrackingId = detectedFace.trackingId;
    
    // Check stabilization dengan atau tanpa tracking ID
    if (currentTrackingId != null) {
      // CASE 1: Ada tracking ID - gunakan tracking ID untuk stabilisasi
      if (_lastDetectedTrackingId == currentTrackingId) {
        // Tracking ID sama, increment counter
        _stableFrameCount++;
        print('🎯 Stable: $_stableFrameCount/$REQUIRED_STABLE_FRAMES (ID: $currentTrackingId)');
        log('🎯 Stable frame count: $_stableFrameCount/$REQUIRED_STABLE_FRAMES (ID: $currentTrackingId)', name: 'Stabilization');
      } else {
        // Tracking ID berubah, reset counter
        print('🔄 ID changed: $_lastDetectedTrackingId → $currentTrackingId (reset)');
        log('🔄 Tracking ID changed: $_lastDetectedTrackingId → $currentTrackingId, resetting counter', name: 'Stabilization');
        setState(() {
          _lastDetectedTrackingId = currentTrackingId;
          _stableFrameCount = 1;
        });
        return; // Tunggu stabilization
      }
    } else {
      // CASE 2: Tidak ada tracking ID - gunakan frame count sederhana
      print('⚠️ No tracking ID from ML Kit - using simple frame count');
      log('⚠️ No tracking ID from ML Kit, using simple stabilization', name: 'Stabilization');
      
      // Increment frame count setiap kali wajah terdeteksi (tanpa tracking ID)
      _stableFrameCount++;
      print('🎯 Stable (no ID): $_stableFrameCount/$REQUIRED_STABLE_FRAMES');
      log('🎯 Stable frame count (no tracking): $_stableFrameCount/$REQUIRED_STABLE_FRAMES', name: 'Stabilization');
      
      // Set tracking ID ke -1 sebagai marker bahwa kita menggunakan simple count
      if (_lastDetectedTrackingId != -1) {
        setState(() {
          _lastDetectedTrackingId = -1;
        });
      }
    }

    // Jika belum stabil (belum 3 frame berturut-turut), tunggu
    if (_stableFrameCount < REQUIRED_STABLE_FRAMES) {
      return;
    }

    // ===== WAJAH SUDAH STABIL, PROSES AUTO-MATCHING =====
    log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', name: 'AutoPresensi');
    log('✅ ✅ ✅ FACE STABILIZED! Starting auto-match...', name: 'AutoPresensi');
    log('📊 Total registered users: ${_registeredUsers.length}', name: 'AutoPresensi');
    log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', name: 'AutoPresensi');
    
    // GUARD: Cegah multiple processing, konfirmasi berlangsung, atau sudah selesai
    if (_isAutoProcessing || _inConfirmation || _hasCompletedAttendance) {
      log('⚠️ Skipping: processing=$_isAutoProcessing, confirmation=$_inConfirmation, completed=$_hasCompletedAttendance', name: 'AutoPresensi');
      return;
    }
    
    // 🕐 CEK WAKTU PRESENSI TERLEBIH DAHULU (SEBELUM MATCHING)
    Map<String, dynamic> timeCheck = await AttendanceTimeHelper.checkAttendanceTime();
    if (timeCheck['allowed'] == false) {
      log('⏰ Attendance not allowed at this time: ${timeCheck['message']}', name: 'TimeCheck');
      
      // Tampilkan notifikasi waktu tidak valid
      _showFailureDialog(
        title: "Waktu Presensi Tidak Valid",
        description: timeCheck['message'] ?? 'Presensi hanya dapat dilakukan pada waktu yang ditentukan.',
      );
      
      // Reset stabilization untuk mencoba lagi nanti
      setState(() {
        _lastDetectedTrackingId = null;
        _stableFrameCount = 0;
      });
      return;
    }
    log('✅ Time check passed: Attendance allowed', name: 'TimeCheck');

    setState(() {
      isMatching = true;
      _isAutoProcessing = true;
      _failStreak = 0; // reset fail streak di awal siklus matching
    });
    
    try {
      final startTime = DateTime.now();
      
      // Untuk Regula FaceSDK, kita perlu bytes dari gambar
      // Karena InputImage dari realtime camera tidak memiliki bytes langsung,
      // kita akan menggunakan cara yang sudah ada: menggunakan image2 yang sudah di-set
      // atau menggunakan cara alternatif dengan mengambil snapshot
      
      // Set image2 untuk Regula FaceSDK (menggunakan cara yang sudah ada)
      // Kita akan menggunakan InputImage bytes jika tersedia, atau menggunakan cara lain
      Uint8List? capturedBitmap;
      
      // Coba ambil dari filePath jika tersedia
      if (inputImage.filePath != null) {
        try {
          final file = File(inputImage.filePath!);
          if (await file.exists()) {
            capturedBitmap = await file.readAsBytes();
          }
        } catch (e) {
          log('⚠️ Error reading file: $e', name: 'ImageConversion');
        }
      }
      
      // Jika tidak ada filePath, gunakan cara alternatif
      // Untuk realtime camera, kita akan menggunakan image2 yang sudah di-set sebelumnya
      // atau kita akan menggunakan cara yang berbeda
      if (capturedBitmap == null) {
        // Gunakan image2.bitmap jika sudah di-set (untuk mode manual)
        // Untuk realtime, kita perlu cara lain
        log('⚠️ No filePath available, using alternative method', name: 'ImageConversion');
        // Kita akan menggunakan cara yang berbeda: menggunakan image2 yang sudah ada
        // atau menggunakan cara lain untuk mendapatkan bytes
        // Untuk sekarang, kita akan skip Regula dan menggunakan compareFaces saja
        // atau kita akan menggunakan cara yang sudah ada di _matchFaces()
      }
      
      // GUARD: Cek lagi setelah async operation
      if (_inConfirmation || _hasCompletedAttendance) {
        log('⚠️ ABORT: confirmation/completion started during image conversion', name: 'AutoPresensi');
        setState(() {
          isMatching = false;
          _isAutoProcessing = false;
          _failStreak = 0;
        });
        return;
      }
      
      // Ekstraksi fitur wajah untuk fallback compareFaces (jika Regula tidak tersedia)
      FaceFeatures? features;
      if (faces.isNotEmpty) {
        features = extractFaceFeaturesFromFace(faces.first);
      }
      if (features == null) {
        features = await extractFaceFeatures(inputImage, FaceDetectorSingleton().faceDetector);
      }

      final conversionTime = DateTime.now().difference(startTime).inMilliseconds;
      log('✅ Image conversion SUCCESS: ${conversionTime}ms', name: 'Performance');

      // ===== MATCHING DENGAN REGULA FACESDK =====
      // Fetch koleksi wajah_siswa jika belum dimuat
      if (_registeredUsers.isEmpty && !_isLoadingUsers) {
        await _loadRegisteredFaces();
      }
      
      // GUARD: Cek lagi setelah async operation (load users)
      if (_inConfirmation || _hasCompletedAttendance) {
        log('⚠️ ABORT: confirmation/completion started during user loading', name: 'AutoPresensi');
        setState(() {
          isMatching = false;
          _isAutoProcessing = false;
        });
        return;
      }
      
      UserModel? matchedUser;
      
      // Jika capturedBitmap tersedia, gunakan Regula FaceSDK
      if (capturedBitmap != null) {
        // Matching dengan Regula FaceSDK (dengan early exit)
        final matchStartTime = DateTime.now();
        matchedUser = await _matchFacesWithRegula(capturedBitmap, _registeredUsers);
        final matchTime = DateTime.now().difference(matchStartTime).inMilliseconds;
        log('✓ Regula FaceSDK matching: ${matchTime}ms', name: 'Performance');
      } else {
        // Fallback: gunakan compareFaces jika Regula tidak tersedia
        log('⚠️ Using compareFaces fallback (no bitmap available)', name: 'FaceMatch');
        matchedUser = await _matchFacesWithCompareFaces(features, _registeredUsers);
      }

      // GUARD: Cek lagi setelah matching selesai
      if (_inConfirmation || _hasCompletedAttendance) {
        log('⚠️ ABORT: confirmation/completion started during matching process', name: 'AutoPresensi');
        setState(() {
          isMatching = false;
          _isAutoProcessing = false;
        });
        return;
      }
      
      // Gunakan hasil dari Regula FaceSDK langsung tanpa validasi tambahan
      if (matchedUser != null) {
        // Cek konsistensi kandidat agar tidak lompat user antar frame
        if (_lastCandidateNisn == matchedUser.nisn) {
          _consistentMatchCount++;
        } else {
          _lastCandidateNisn = matchedUser.nisn;
          _consistentMatchCount = 1;
        }
        if (_consistentMatchCount < _minConsistentMatches) {
          log('⏳ Waiting for consistent match (${_consistentMatchCount}/$_minConsistentMatches) for NISN ${matchedUser.nisn}', name: 'FaceMatch');
          setState(() {
            isMatching = false;
            _isAutoProcessing = false;
          });
          return;
        }
        // Reset counter setelah konsisten terpenuhi untuk menghindari carryover
        _consistentMatchCount = 0;
        _lastCandidateNisn = null;

        // ===== WAJAH COCOK - CEK PRESENSI GANDA DULU =====
        log('✅ ✅ ✅ MATCH FOUND with Regula FaceSDK for NISN: ${matchedUser.nisn}', name: 'FaceMatch');
        
        // CEK PRESENSI GANDA SEBELUM LANJUT KE KONFIRMASI
        if (matchedUser.nisn != null && matchedUser.nisn!.trim().isNotEmpty) {
          log('🔍 Checking duplicate attendance for NISN: ${matchedUser.nisn}', name: 'FaceMatch');
          bool hasAttendedToday = await _checkTodayAttendance(matchedUser.nisn!.trim());
          if (hasAttendedToday) {
            log('⚠️ Duplicate attendance detected! Aborting...', name: 'FaceMatch');
            setState(() {
              isMatching = false;
              _isAutoProcessing = false;
              _lastDetectedTrackingId = null;
              _stableFrameCount = 0;
            });
            return; // Stop proses, notifikasi sudah ditampilkan di _checkTodayAttendance
          }
        }
        
        // Check cooldown untuk sukses
        if (_lastSuccessNotificationTime != null) {
          final timeSinceLastSuccess = now.difference(_lastSuccessNotificationTime!).inSeconds;
          if (timeSinceLastSuccess < SUCCESS_COOLDOWN_SECONDS) {
            log('⏳ Success cooldown active (${SUCCESS_COOLDOWN_SECONDS - timeSinceLastSuccess}s remaining)', name: 'AutoPresensi');
            setState(() {
              isMatching = false;
              _isAutoProcessing = false;
            });
            return;
          }
        }
        
        log('🎯 Proceeding to confirmation...', name: 'FaceMatch');
        _lastSuccessNotificationTime = now;
        
        // SET FLAG SEGERA TANPA MENUNGGU setState (KUNCI UTAMA!)
        // Ini adalah synchronous operation yang langsung block proses lain
        _inConfirmation = true; // Set LANGSUNG untuk block dialog gagal IMMEDIATELY
        
        // Kemudian setState untuk UI update
        setState(() {
          _lastDetectedTrackingId = null;
          _stableFrameCount = 0;
          isMatching = false;
          _isAutoProcessing = false;
        });
        
        // Start konfirmasi
        await _startConfirmation(matchedUser);
        log('📝 Confirmation started', name: 'FaceMatch');
        return; // Exit setelah match valid
      }
      
      // Jika tidak ada match valid, lanjut ke failure flow
      {
        // ===== WAJAH TIDAK COCOK - TAMPILKAN NOTIFIKASI =====
        // GUARD: Cek sekali lagi untuk memastikan tidak sedang konfirmasi
        if (_inConfirmation || _hasCompletedAttendance) {
          log('⚠️ Skipping failure notification: confirmation/completion active', name: 'FaceMatch');
          setState(() {
            isMatching = false;
            _isAutoProcessing = false;
          });
          return;
        }

        // Tambah syarat: tunda notif gagal sampai minimal ada jeda awal
        final elapsedMs = DateTime.now().difference(_sessionStartTime).inMilliseconds;
        if (elapsedMs < _minFailDelayMs) {
          log('⏳ Delay failure notification (elapsed=${elapsedMs}ms)', name: 'FaceMatch');
          setState(() {
            isMatching = false;
            _isAutoProcessing = false;
            _lastDetectedTrackingId = null;
            _stableFrameCount = 0;
          });
          return;
        }
        
        log('✗ No matching face found with Regula FaceSDK (threshold: 86%)', name: 'FaceMatch');
        
        // Tampilkan dialog gagal dengan guard ketat dan cooldown
        if (_lastFailureDialogTime != null) {
          final timeSinceLastFailure = now.difference(_lastFailureDialogTime!).inSeconds;
          if (timeSinceLastFailure < 8) { // 8 detik cooldown untuk menghindari spam
            log('⏳ Failure dialog cooldown active', name: 'AutoPresensi');
            setState(() {
              isMatching = false;
              _isAutoProcessing = false;
            });
            return;
          }
        }
        
        // Set waktu untuk cooldown
        _lastFailureDialogTime = now;
        
        // Jika wajah tidak terdaftar, langsung gagal (tanpa fail-streak)
        final bool forceFail = (matchedUser == null);
        if (!forceFail) {
          // Kandidat terdaftar dengan akurasi cukup: izinkan satu kali fail-streak smoothing
          if (_failStreak < 1) {
            _failStreak += 1;
            log('⏳ Delay failure for registered-face candidate (failStreak=$_failStreak)', name: 'FaceMatch');
            setState(() {
              isMatching = false;
              _isAutoProcessing = false;
              _lastDetectedTrackingId = null;
              _stableFrameCount = 0;
            });
            return;
          }
        }
        // Reset fail streak setelah akan menampilkan dialog
        _failStreak = 0;
        
        // Tampilkan dialog popup untuk wajah tidak cocok
        // Logika trialNumber + dialog nama ketika gagal
        if (trialNumber == 4) {
          setState(() => trialNumber = 1);
          _showFailureDialog(
            title: "Presensi Gagal!",
            description: "Wajah tidak cocok dengan yang ada di database. Silahkan coba kembali!",
          );
        } else if (trialNumber == 3) {
          setState(() {
            isMatching = false;
            trialNumber++;
          });
          if (!context.mounted) return;
          _showNameDialog();
        } else {
          setState(() => trialNumber++);
          _showFailureDialog(
            title: "Presensi Gagal!",
            description: "Wajah tidak cocok dengan yang ada di database. Silahkan coba kembali!",
          );
        }
        
        // Reset state
        setState(() {
          _lastDetectedTrackingId = null;
          _stableFrameCount = 0;
          _lastCandidateNisn = null;
          _consistentMatchCount = 0;
        });
      }
    } catch (e) {
      log('Realtime match error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isMatching = false;
          _isAutoProcessing = false;
        });
      }
    }
  }


  // Konfirmasi otomatis sebelum menyimpan
  UserModel? _candidateMatch;
  String? _candidateStudentName;
  int _countdown = 3;
  Timer? _countdownTimer;
  bool _inConfirmation = false;

  Future<void> _startConfirmation(UserModel bestUser) async {
    // Note: _inConfirmation sudah di-set TRUE sebelum fungsi ini dipanggil
    // Hanya cek jika sudah completed
    if (_hasCompletedAttendance) {
      log('⚠️ Skipping confirmation: already completed attendance', name: 'Confirmation');
      return;
    }
    
    log('✅ Starting confirmation for NISN: ${bestUser.nisn}', name: 'Confirmation');
    setState(() {
      _candidateMatch = bestUser;
      // _inConfirmation sudah TRUE, tidak perlu set lagi
      _countdown = 3;
    });

    // Muat nama siswa dari koleksi 'siswa'
    try {
      if (bestUser.nisn != null) {
        final doc = await FirebaseFirestore.instance
            .collection('siswa')
            .doc(bestUser.nisn)
            .get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _candidateStudentName = data['nama_siswa'] as String?;
          });
        }
      }
    } catch (_) {}

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 700), (t) async {
      if (!mounted) return;
      if (_countdown <= 1) {
        t.cancel();
        await _confirmAndSave();
      } else {
        setState(() {
          _countdown -= 1;
        });
      }
    });
  }

  Future<void> _confirmAndSave() async {
    final user = _candidateMatch;
    if (user == null) {
      setState(() {
        _inConfirmation = false;
      });
      return;
    }
    final saved = await _saveAttendanceRecord(user);
    if (saved) {
      _hasCompletedAttendance = true;
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AuthenticatedUserScreen(
            user: user,
            attendanceAlreadySaved: true,
          ),
        ),
      );
    } else {
      if (!mounted) return;
      setState(() {
        _inConfirmation = false;
        _candidateMatch = null;
        _candidateStudentName = null;
      });
    }
  }

  void _cancelConfirmation() {
    _countdownTimer?.cancel();
    setState(() {
      _inConfirmation = false;
      _candidateMatch = null;
      _candidateStudentName = null;
    });
  }


  double euclideanDistance(Points p1, Points p2) {
    final sqr =
        math.sqrt(math.pow((p1.x! - p2.x!), 2) + math.pow((p1.y! - p2.y!), 2));
    return sqr;
  }

  _fetchUsersAndMatchFace() {
    log('Starting face matching process...');

    // ignore: body_might_complete_normally_catch_error
    FirebaseFirestore.instance.collection("wajah_siswa").get().catchError((e) {
      log("Getting User Error: $e");
      setState(() => isMatching = false);
      showToast(
          "Terjadi kesalahan saat mengambil data wajah!. Silahkan coba lagi!",
          isError: true);
    }).then((snap) async {
      if (snap.docs.isNotEmpty) {
        users.clear();
        log('Total wajah terdaftar: ${snap.docs.length}');

        for (var doc in snap.docs) {
          UserModel user = UserModel.fromJson(doc.data());

          // Load student class information
          if (user.nisn != null) {
            try {
              DocumentSnapshot studentDoc = await FirebaseFirestore.instance
                  .collection('siswa')
                  .doc(user.nisn)
                  .get();

              if (studentDoc.exists) {
                log('Loaded student info for NISN ${user.nisn}');
              }
            } catch (e) {
              log('Error loading student info: $e');
            }
          }

          // Add all users to the list for comparison
          users.add([user, 1.0]);
        }

        log('Total users loaded for comparison: ${users.length}');
        _matchFaces();
      } else {
        _showFailureDialog(
          title: "Wajah tidak terdaftar",
          description: "Pastikan wajah terdaftar di database.",
        );
      }
    });
  }

  _matchFaces() async {
    log('Starting face matching with ${users.length} candidates...');

    bool faceMatched = false;
    double highestSimilarity = 0.0;
    UserModel? bestMatch;

    for (List user in users) {
      try {
        image1.bitmap = (user.first as UserModel).gambar;
        image1.imageType = regula.ImageType.PRINTED;

        var request = regula.MatchFacesRequest();
        request.images = [image1, image2];
        dynamic value = await regula.FaceSDK.matchFaces(jsonEncode(request));

        var response = regula.MatchFacesResponse.fromJson(json.decode(value));
        
        // Threshold seimbang untuk menghindari false positive namun tetap bisa mengenali wajah terdaftar
        dynamic str = await regula.FaceSDK.matchFacesSimilarityThresholdSplit(
            jsonEncode(response!.results), 0.75);

        var split = regula.MatchFacesSimilarityThresholdSplit.fromJson(
            json.decode(str));

        if (split!.matchedFaces.isNotEmpty) {
          double similarity = split.matchedFaces[0]!.similarity! * 100;
          log("Face similarity for ${(user.first as UserModel).nisn}: $similarity%");

          if (similarity > highestSimilarity) {
            highestSimilarity = similarity;
            bestMatch = user.first as UserModel;
          }

          // Threshold seimbang: cukup tinggi untuk akurasi tapi tidak terlalu ketat
          // 88% adalah nilai optimal untuk mengenali wajah terdaftar sambil menghindari false positive
          if (similarity > 88.00) {
            faceMatched = true;
            loggingUser = user.first;
            log('✓ Face matched for NISN: ${loggingUser?.nisn} with similarity: $similarity%');

            // Guard: Cek apakah sedang memproses attendance untuk mencegah duplikasi
            if (_isProcessingAttendance) {
              log('⚠ Already processing attendance, skipping duplicate save');
              break;
            }

            // Set flag untuk mencegah save ganda
            _isProcessingAttendance = true;

            // Save attendance for the matched user
            log('Attempting to save attendance record...');
            bool attendanceSaved = await _saveAttendanceRecord(loggingUser!);

            setState(() {
              trialNumber = 1;
              isMatching = false;
              _isProcessingAttendance = false; // Reset flag setelah selesai
            });

            if (attendanceSaved) {
              log('Attendance saved, navigating to success screen');
              if (mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AuthenticatedUserScreen(
                      user: loggingUser!,
                      attendanceAlreadySaved: true,
                    ),
                  ),
                );
              }
            } else {
              log('Failed to save attendance, showing error');
              _showFailureDialog(
                title: "Gagal Menyimpan Presensi",
                description:
                    "Terjadi kesalahan saat menyimpan data presensi. Silakan coba lagi!",
              );
            }
            break;
          } else {
            log('✗ Face similarity too low: $similarity% (threshold: 88%) for NISN: ${(user.first as UserModel).nisn}');
          }
        }
      } catch (e) {
        log('Error during face matching: $e');
        continue; // Continue with next user instead of breaking
      }
    }

    if (!faceMatched) {
      if (bestMatch != null) {
        log('✗ No match found. Best candidate: ${bestMatch.nisn} with similarity: $highestSimilarity% (below threshold)');
      } else {
        log('✗ No matching faces detected');
      }

      if (trialNumber == 4) {
        setState(() => trialNumber = 1);
        _showFailureDialog(
          title: "Presensi Gagal!",
          description:
              "Wajah tidak cocok dengan yang ada di database. Silahkan coba kembali!",
        );
      } else if (trialNumber == 3) {
        setState(() {
          isMatching = false;
          trialNumber++;
        });
        if (!context.mounted) return;
        _showNameDialog();
      } else {
        setState(() => trialNumber++);
        _showFailureDialog(
          title: "Presensi Gagal!",
          description:
              "Wajah tidak cocok dengan yang ada di database. Silahkan coba kembali!",
        );
      }
    }
  }

  void _showNameDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Masukkan nama",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
          content: TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Masukkan nama lengkap',
              prefixIcon: const Icon(
                Icons.person_outline,
                color: Color(0xFF81C784),
              ),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF81C784), width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => trialNumber = 1);
              },
              child: const Text(
                "Batal",
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (_nameController.text.trim().isEmpty) {
                  showToast("Masukkan nama untuk memproses", isError: true);
                } else {
                  Navigator.of(context).pop();
                  setState(() => isMatching = true);
                  _fetchUserByName(_nameController.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF81C784),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Cari",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  _fetchUserByName(String orgID) {
    FirebaseFirestore.instance
        .collection("wajah_siswa")
        .where("organizationId", isEqualTo: orgID)
        .get()
        // ignore: body_might_complete_normally_catch_error
        .catchError((e) {
      log("Getting User Error: $e");
      setState(() => isMatching = false);
      showToast("Terjadi kesalahan!. Silahkan coba lagi!", isError: true);
    }).then((snap) {
      if (snap.docs.isNotEmpty) {
        users.clear();

        for (var doc in snap.docs) {
          setState(() {
            users.add([UserModel.fromJson(doc.data()), 1]);
          });
        }
        _matchFaces();
      } else {
        setState(() => trialNumber = 1);
        _showFailureDialog(
          title: "Wajah tidak terdaftar",
          description: "Pastikan wajah terdaftar di database.",
        );
      }
    });
  }

  void _showFailureDialog(
      {required String title, required String description}) {
    // GUARD TERAKHIR: Jangan tampilkan dialog jika sedang konfirmasi atau sudah selesai
    if (_inConfirmation || _hasCompletedAttendance) {
      log('⚠️ BLOCKED: Dialog gagal dicegah karena konfirmasi aktif', name: 'FailureDialog');
      return;
    }
    
    // Delay kecil untuk memastikan flag _inConfirmation sudah ter-update dari proses paralel
    // Gunakan Future.delayed untuk memberi waktu propagasi flag
    Future.delayed(const Duration(milliseconds: 100), () {
      // CEK LAGI setelah delay
      if (_inConfirmation || _hasCompletedAttendance) {
        log('⚠️ BLOCKED: Dialog gagal dicegah setelah delay check', name: 'FailureDialog');
        return;
      }
      
      if (!mounted) return; // Pastikan widget masih mounted
      
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF7043),
              ),
            ),
            content: Text(
              description,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                      Navigator.of(context).pop();
                      // Kembali ke beranda (pop semua sampai root)
                      Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: Color(0xFF2E7D32), // hijau, bukan merah
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }); // Tutup Future.delayed
  }

  Widget _buildActionSection() {
    if (_canAuthenticate) {
      // Tampilkan konfirmasi jika wajah cocok
      if (_inConfirmation) {
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF81C784)),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF81C784).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.check, color: Color(0xFF2E7D32), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Wajah terdeteksi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_candidateStudentName ?? 'NISN: ${_candidateMatch?.nisn ?? '-'}'} · Absen otomatis dalam $_countdown dtk',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _cancelConfirmation,
                child: const Text('Batal', style: TextStyle(color: Color(0xFF6B7280))),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: _confirmAndSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF66BB6A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Absen Sekarang', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }

      // Tampilkan progress stabilization jika wajah terdeteksi tapi belum stabil
      if (_stableFrameCount > 0 && _stableFrameCount < REQUIRED_STABLE_FRAMES) {
        double progress = _stableFrameCount / REQUIRED_STABLE_FRAMES;
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFB74D)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  value: progress,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF9800)),
                  backgroundColor: const Color(0xFFFFE0B2),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Stabilisasi wajah...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE65100),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tahan posisi wajah ($_stableFrameCount/$REQUIRED_STABLE_FRAMES)',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(_stableFrameCount / REQUIRED_STABLE_FRAMES * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE65100),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      // Tampilkan loading saat memproses wajah
      if (isMatching) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF81C784).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF81C784)),
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Memproses wajah...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Mencocokkan dengan database',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      // Status idle - auto-detection aktif
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF64B5F6)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.visibility, color: Color(0xFF1976D2), size: 18),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Mode Auto-Presensi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Arahkan wajah ke kamera untuk presensi otomatis',
                    style: TextStyle(fontSize: 13, color: Color(0xFF546E7A)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sensors, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'AKTIF',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Fallback jika _canAuthenticate false
    return Container(
      width: double.infinity,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF8A65),
            Color(0xFFFF7043),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8A65).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          setState(() => isMatching = true);
          _fetchUsersAndMatchFace();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.face_retouching_natural,
              color: Colors.white,
              size: 16,
            ),
            SizedBox(width: 6),
            Text(
              "Lakukan Presensi",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetunjukPresensi() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Judul di tengah
          Align(
            alignment: Alignment.center,
            child: Text(
              'Petunjuk Presensi',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF7043),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 8),
          // List tetap rata kiri
          Text(
            '1. Posisikan wajah di tengah kamera\n'
            '2. Pastikan pencahayaan cukup\n'
            '3. Hindari menggunakan masker\n',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
              height: 1.1,
            ),
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }

  void showToast(String msg, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor:
          isError ? const Color(0xFFFF8A65) : const Color(0xFF81C784),
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  /// Data Members
  // ignore: unused_field
  FaceFeatures? _faceFeatures;
  var image1 = regula.MatchFacesImage();
  var image2 = regula.MatchFacesImage();

  final TextEditingController _nameController = TextEditingController();

  bool _canAuthenticate = false;
  List<dynamic> users = [];
  bool userExists = false;
  UserModel? loggingUser;
  bool isMatching = false;
  int trialNumber = 1;
  bool _isProcessingAttendance = false; // Flag untuk mencegah duplikasi save
  
  // Real-time auto-presensi variables
  int? _lastDetectedTrackingId;
  int _stableFrameCount = 0;
  DateTime? _lastSuccessNotificationTime;
  DateTime? _lastFailureDialogTime;
  static const int REQUIRED_STABLE_FRAMES = 3; // 3 frame berturut-turut (optimasi dari 5)
  static const int SUCCESS_COOLDOWN_SECONDS = 5; // Cooldown untuk notifikasi sukses
  bool _isAutoProcessing = false; // Flag untuk mencegah multiple auto-process
}

// Tambahkan singleton untuk FaceDetector
class FaceDetectorSingleton {
  static final FaceDetectorSingleton _instance =
      FaceDetectorSingleton._internal();
  late final FaceDetector faceDetector;

  factory FaceDetectorSingleton() {
    return _instance;
  }

  FaceDetectorSingleton._internal() {
    faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.05,
      ),
    );
  }

  void close() {
    faceDetector.close();
  }
}