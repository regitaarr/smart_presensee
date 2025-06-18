//authenticate_screen.dart
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_presensee/model/face_features.dart';
import 'package:smart_presensee/model/user_model.dart';
import 'package:smart_presensee/screens/authenticated_user_screen.dart';
import 'package:smart_presensee/services/extract_features.dart';
import 'package:smart_presensee/widgets/camera_view.dart';
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
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _faceDetector.close();
    _nameController.dispose();
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
              // Konten utama scrollable
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      // Date Display
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
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
                      // Main Content
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              children: [
                                // Camera View
                                CameraView(
                                  onImage: (image) {
                                    _setImage(image);
                                  },
                                  onInputImage: (inputImage) async {
                                    setState(() => isMatching = true);
                                    _faceFeatures = await extractFaceFeatures(
                                        inputImage, _faceDetector);
                                    setState(() => isMatching = false);
                                  },
                                ),
                                const SizedBox(height: 4),
                                // Status and Button Section
                                _buildActionSection(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Petunjuk Presensi
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: _buildPetunjukPresensi(),
                      ),
                    ],
                  ),
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

  double compareFaces(FaceFeatures face1, FaceFeatures face2) {
    double distEar1 = euclideanDistance(face1.rightEar!, face1.leftEar!);
    double distEar2 = euclideanDistance(face2.rightEar!, face2.leftEar!);
    double ratioEar = distEar1 / distEar2;

    double distEye1 = euclideanDistance(face1.rightEye!, face1.leftEye!);
    double distEye2 = euclideanDistance(face2.rightEye!, face2.leftEye!);
    double ratioEye = distEye1 / distEye2;

    double distCheek1 = euclideanDistance(face1.rightCheek!, face1.leftCheek!);
    double distCheek2 = euclideanDistance(face2.rightCheek!, face2.leftCheek!);
    double ratioCheek = distCheek1 / distCheek2;

    double distMouth1 = euclideanDistance(face1.rightMouth!, face1.leftMouth!);
    double distMouth2 = euclideanDistance(face2.rightMouth!, face2.leftMouth!);
    double ratioMouth = distMouth1 / distMouth2;

    double distNoseToMouth1 =
        euclideanDistance(face1.noseBase!, face1.bottomMouth!);
    double distNoseToMouth2 =
        euclideanDistance(face2.noseBase!, face2.bottomMouth!);
    double ratioNoseToMouth = distNoseToMouth1 / distNoseToMouth2;

    double ratio =
        (ratioEye + ratioEar + ratioCheek + ratioMouth + ratioNoseToMouth) / 5;
    log(ratio.toString(), name: "Ratio");

    return ratio;
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

          if (similarity > 85.00) {
            faceMatched = true;
            loggingUser = user.first;
            log('Face matched for user: ${loggingUser?.name}, NISN: ${loggingUser?.nisn}');

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
          }
        }
      } catch (e) {
        log('Error during face matching: $e');
        continue; // Continue with next user instead of breaking
      }
    }

    if (!faceMatched) {
      if (bestMatch != null) {
        log('Best match found with similarity: $highestSimilarity%');
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

  _showFailureDialog({
    required String title,
    required String description,
  }) {
    setState(() => isMatching = false);
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
              color: Color(0xFFEF4444),
            ),
            textAlign: TextAlign.center,
          ),
          content: Text(
            description,
            style: const TextStyle(color: Color(0xFF6B7280)),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF81C784),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "OK",
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

  Widget _buildActionSection() {
    if (_canAuthenticate) {
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
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );
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
