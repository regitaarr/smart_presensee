//authenticate_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_presensee/model/face_features.dart';
import 'package:smart_presensee/model/user_model.dart';
import 'package:smart_presensee/screens/authenticated_user_screen.dart';
import 'package:smart_presensee/services/extract_features.dart';
import 'package:smart_presensee/widgets/realtime_camera_view.dart';
import 'package:flutter/material.dart';
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
    log('AuthenticateScreen initialized');

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
    _loadRegisteredFaces();
    _canAuthenticate = true; // tampilkan status section
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

  // Function to generate attendance ID - SEQUENTIAL VERSION
  Future<String> _generateAttendanceId() async {
    try {
      const String prefix = 'idpr04';

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

      DocumentSnapshot existingDoc = await FirebaseFirestore.instance
          .collection('presensi')
          .doc(newId)
          .get();

      if (existingDoc.exists) {
        log('ID $newId already exists, trying next number...');
        nextNumber++;
        formattedNumber = nextNumber.toString().padLeft(4, '0');
        newId = '$prefix$formattedNumber';
      }

      log('Generated attendance ID: $newId');
      return newId;
    } catch (e) {
      log('Error generating attendance ID: $e');

      DateTime now = DateTime.now();
      String timeString =
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      String fallbackId = 'idpr04$timeString';

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

        // Show message in popup dialog
        String timeString =
            '${existingTime.hour.toString().padLeft(2, '0')}:${existingTime.minute.toString().padLeft(2, '0')}';
        _showFailureDialog(
          title: "Presensi Gagal!",
          description:
              "Kamu $studentName sudah melakukan presensi hari ini pada pukul $timeString!",
        );
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

      // Check if student has already attended today
      bool hasAttendedToday = await _checkTodayAttendance(nisn);
      if (hasAttendedToday) {
        log('Attendance already exists for NISN $nisn today');
        return false;
      }

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
                      child: RealtimeCameraView(
                        onFrame: (inputImage, faces) {
                          _onRealtimeFrame(inputImage, faces);
                        },
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

  // Skor kemiripan berbasis beberapa metrik; semakin kecil semakin mirip (0 ideal)
  double? computeSimilarityScore(FaceFeatures faceA, FaceFeatures faceB) {
    final List<double> diffs = [];
    
    // Validasi: pastikan minimal ada 4 landmark yang terdeteksi
    int validLandmarks = 0;
    if (faceA.rightEye?.x != null && faceA.leftEye?.x != null) validLandmarks++;
    if (faceA.rightMouth?.x != null && faceA.leftMouth?.x != null) validLandmarks++;
    if (faceA.noseBase?.x != null) validLandmarks++;
    if (faceA.rightCheek?.x != null && faceA.leftCheek?.x != null) validLandmarks++;
    
    if (validLandmarks < 3) {
      log('Insufficient landmarks detected: $validLandmarks', name: 'FaceMatch');
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

    if (diffs.isEmpty || diffs.length < 3) {
      log('Insufficient face metrics: ${diffs.length}', name: 'FaceMatch');
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

  Future<void> _loadRegisteredFaces() async {
    if (_isLoadingUsers) return;
    setState(() {
      _isLoadingUsers = true;
    });
    try {
      final snap = await FirebaseFirestore.instance.collection('wajah_siswa').get();
      _registeredUsers.clear();
      for (var doc in snap.docs) {
        final user = UserModel.fromJson(doc.data());
        if (user.faceFeatures != null && user.nisn != null) {
          _registeredUsers.add(user);
        }
      }
      log('Loaded registered faces: ${_registeredUsers.length}');
    } catch (e) {
      log('Error loading registered faces: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
        });
      }
    }
  }

  void _onRealtimeFrame(InputImage inputImage, List<Face> faces) async {
    if (!mounted) return;
    if (_hasCompletedAttendance) return;
    if (_inConfirmation) return;
    if (faces.isEmpty) return;

    final now = DateTime.now();
    if (_lastMatchAttempt != null &&
        now.difference(_lastMatchAttempt!).inMilliseconds < 500) {
      return; // throttle
    }
    _lastMatchAttempt = now;

    if (_registeredUsers.isEmpty && !_isLoadingUsers) {
      await _loadRegisteredFaces();
      if (_registeredUsers.isEmpty) return;
    }

    setState(() => isMatching = true);
    try {
      // Gunakan hasil deteksi cepat dari onFrame (faces) jika tersedia untuk
      // menghindari pemrosesan ulang ML Kit yang mahal.
      FaceFeatures? features;
      if (faces.isNotEmpty) {
        features = extractFaceFeaturesFromFace(faces.first);
      }
      features ??=
          await extractFaceFeatures(inputImage, FaceDetectorSingleton().faceDetector);
      if (features == null) {
        setState(() => isMatching = false);
        return;
      }

      double bestScore = double.infinity; // semakin kecil semakin mirip
      UserModel? bestUser;
      int validComparisonCount = 0; // Hitung berapa banyak perbandingan valid

      for (final user in _registeredUsers) {
        try {
          final stored = user.faceFeatures!;
          final score = computeSimilarityScore(features, stored);
          if (score != null) {
            validComparisonCount++;
            log('Comparing with NISN ${user.nisn}: score = ${score.toStringAsFixed(4)}', name: 'FaceMatch');
            if (score < bestScore) {
              bestScore = score;
              bestUser = user;
            }
          }
        } catch (e) {
          log('Error comparing with user ${user.nisn}: $e', name: 'FaceMatch');
          // skip jika data tidak lengkap
        }
      }

      log('Best match: ${bestUser?.nisn ?? "none"} with score: ${bestScore.toStringAsFixed(4)} (from $validComparisonCount comparisons)', name: 'FaceMatch');

      // Ambang batas SANGAT KETAT untuk mencegah false positive
      // Threshold 0.055 = sangat sangat ketat, hanya wajah identik yang diterima
      const double strictThreshold = 0.055;
      
      if (bestUser != null && bestScore < strictThreshold) {
        log('✓ Face matched! Score: ${bestScore.toStringAsFixed(4)} for NISN: ${bestUser.nisn}', name: 'FaceMatch');
        _startConfirmation(bestUser);
      } else if (bestUser != null && bestScore < 0.12) {
        log('✗ Face similarity too low: ${bestScore.toStringAsFixed(4)} (threshold: $strictThreshold) - REJECTED', name: 'FaceMatch');
      } else {
        log('✗ No matching face found. Best score: ${bestScore.toStringAsFixed(4)}', name: 'FaceMatch');
      }
    } catch (e) {
      log('Realtime match error: $e');
    } finally {
      if (mounted) setState(() => isMatching = false);
    }
  }

  // Konfirmasi otomatis sebelum menyimpan
  UserModel? _candidateMatch;
  String? _candidateStudentName;
  int _countdown = 3;
  Timer? _countdownTimer;
  bool _inConfirmation = false;

  Future<void> _startConfirmation(UserModel bestUser) async {
    if (_inConfirmation || _hasCompletedAttendance) return;
    setState(() {
      _candidateMatch = bestUser;
      _inConfirmation = true;
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
        
        // Threshold dinaikkan ke 0.85 (dari 0.75) untuk mengurangi false positive
        dynamic str = await regula.FaceSDK.matchFacesSimilarityThresholdSplit(
            jsonEncode(response!.results), 0.85);

        var split = regula.MatchFacesSimilarityThresholdSplit.fromJson(
            json.decode(str));

        if (split!.matchedFaces.isNotEmpty) {
          double similarity = split.matchedFaces[0]!.similarity! * 100;
          log("Face similarity for ${(user.first as UserModel).nisn}: $similarity%");

          if (similarity > highestSimilarity) {
            highestSimilarity = similarity;
            bestMatch = user.first as UserModel;
          }

          // Threshold dinaikkan ke 92% (dari 85%) untuk mencegah false positive
          // Hanya wajah yang sangat mirip yang akan diterima
          if (similarity > 92.00) {
            faceMatched = true;
            loggingUser = user.first;
            log('✓ Face matched for NISN: ${loggingUser?.nisn} with similarity: $similarity%');

            // Save attendance for the matched user
            log('Attempting to save attendance record...');
            bool attendanceSaved = await _saveAttendanceRecord(loggingUser!);

            setState(() {
              trialNumber = 1;
              isMatching = false;
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
            log('✗ Face similarity too low: $similarity% (threshold: 92%) for NISN: ${(user.first as UserModel).nisn}');
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
                // Navigasi ke halaman AuthenticateScreen (halaman presensi/foto ulang)
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const AuthenticateScreen(),
                  ),
                );
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
  }

  Widget _buildActionSection() {
    if (_canAuthenticate) {
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
                    Text(
                      'Wajah terdeteksi',
                      style: const TextStyle(
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

      return isMatching
          ? Container(
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
                          'Harap tunggu sebentar',
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
            )
          : Container(
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
    } else {
      return const SizedBox.shrink();
    }
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