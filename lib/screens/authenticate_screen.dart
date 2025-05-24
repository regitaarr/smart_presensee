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

class _AuthenticateScreenState extends State<AuthenticateScreen> {
  // Function to generate attendance ID - SEQUENTIAL VERSION
  Future<String> _generateAttendanceId() async {
    try {
      const String prefix = 'idpr04';

      // Query untuk mendapatkan ID terakhir dengan prefix yang sama
      QuerySnapshot lastRecords = await FirebaseFirestore.instance
          .collection('presensi')
          .where('id_presensi', isGreaterThanOrEqualTo: prefix)
          .where('id_presensi',
              isLessThan:
                  prefix + 'z') // Untuk memastikan hanya prefix yang tepat
          .orderBy('id_presensi', descending: true)
          .limit(1)
          .get();

      int nextNumber = 1; // Default jika belum ada data

      if (lastRecords.docs.isNotEmpty) {
        String lastId = lastRecords.docs.first.get('id_presensi') as String;
        log('Last attendance ID found: $lastId');

        // Extract 4 digit terakhir dari ID
        if (lastId.length >= 10 && lastId.startsWith(prefix)) {
          String lastNumberStr = lastId.substring(6); // Ambil 4 digit terakhir
          int lastNumber = int.tryParse(lastNumberStr) ?? 0;
          nextNumber = lastNumber + 1;
        }
      }

      // Format 4 digit dengan leading zeros
      String formattedNumber = nextNumber.toString().padLeft(4, '0');
      String newId = '$prefix$formattedNumber';

      // Validasi panjang ID (harus tepat 10 karakter)
      if (newId.length != 10) {
        throw Exception('Generated ID length is not 10 characters: $newId');
      }

      // Double-check apakah ID sudah ada (untuk menghindari duplicate)
      DocumentSnapshot existingDoc = await FirebaseFirestore.instance
          .collection('presensi')
          .doc(newId)
          .get();

      if (existingDoc.exists) {
        // Jika ID sudah ada, coba lagi dengan increment
        log('ID $newId already exists, trying next number...');
        nextNumber++;
        formattedNumber = nextNumber.toString().padLeft(4, '0');
        newId = '$prefix$formattedNumber';
      }

      log('Generated attendance ID: $newId');
      return newId;
    } catch (e) {
      log('Error generating attendance ID: $e');

      // Fallback: gunakan timestamp sebagai 4 digit terakhir
      DateTime now = DateTime.now();
      String timeString =
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      String fallbackId = 'idpr04$timeString';

      log('Using fallback ID: $fallbackId');
      return fallbackId;
    }
  }

  // Alternative function with transaction for better concurrency handling
  Future<String> _generateAttendanceIdWithTransaction() async {
    try {
      const String prefix = 'idpr04';

      // Menggunakan transaction untuk menghindari race condition
      return await FirebaseFirestore.instance
          .runTransaction<String>((transaction) async {
        // Query untuk mendapatkan ID terakhir
        QuerySnapshot lastRecords = await FirebaseFirestore.instance
            .collection('presensi')
            .where('id_presensi', isGreaterThanOrEqualTo: prefix)
            .where('id_presensi', isLessThan: prefix + 'z')
            .orderBy('id_presensi', descending: true)
            .limit(1)
            .get();

        int nextNumber = 1;

        if (lastRecords.docs.isNotEmpty) {
          String lastId = lastRecords.docs.first.get('id_presensi') as String;
          if (lastId.length >= 10 && lastId.startsWith(prefix)) {
            String lastNumberStr = lastId.substring(6);
            int lastNumber = int.tryParse(lastNumberStr) ?? 0;
            nextNumber = lastNumber + 1;
          }
        }

        // Cek beberapa ID berikutnya sampai menemukan yang kosong
        for (int attempt = 0; attempt < 100; attempt++) {
          String formattedNumber =
              (nextNumber + attempt).toString().padLeft(4, '0');
          String candidateId = '$prefix$formattedNumber';

          // Cek apakah ID sudah ada
          DocumentSnapshot existingDoc = await transaction.get(FirebaseFirestore
              .instance
              .collection('presensi')
              .doc(candidateId));

          if (!existingDoc.exists) {
            log('Generated attendance ID: $candidateId');
            return candidateId;
          }
        }

        throw Exception('Could not generate unique ID after 100 attempts');
      });
    } catch (e) {
      log('Error in transaction: $e');

      // Fallback
      DateTime now = DateTime.now();
      String timeString =
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      return 'idpr04$timeString';
    }
  }

  // Function to check if attendance already exists today - SIMPLIFIED VERSION
  Future<bool> _checkTodayAttendance(String nisn) async {
    try {
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
      DateTime endOfDay =
          DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      log('Checking attendance for NISN: $nisn on ${now.toString().substring(0, 10)}');

      QuerySnapshot existingRecords = await FirebaseFirestore.instance
          .collection('presensi')
          .where('nisn', isEqualTo: nisn)
          .where('tanggal_waktu',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('tanggal_waktu',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      bool hasAttendance = existingRecords.docs.isNotEmpty;

      if (hasAttendance) {
        var existingData =
            existingRecords.docs.first.data() as Map<String, dynamic>;
        var existingTime =
            (existingData['tanggal_waktu'] as Timestamp).toDate();
        log('Found existing attendance for NISN $nisn at ${existingTime.toString()}');
      } else {
        log('No existing attendance found for NISN $nisn today');
      }

      return hasAttendance;
    } catch (e) {
      log('Error checking today attendance: $e');
      // If error in checking, return false to allow attendance (fail safe)
      return false;
    }
  }

  // Function to save attendance record - RELIABLE VERSION
  Future<bool> _saveAttendanceRecord(UserModel user) async {
    try {
      // Validate NISN
      if (user.nisn == null || user.nisn!.trim().isEmpty) {
        log('Error: User NISN is null or empty');
        showToast('Error: NISN tidak ditemukan', isError: true);
        return false;
      }

      final String nisn = user.nisn!.trim();
      log('Starting attendance save process for NISN: $nisn');

      // Check if already attended today
      bool hasAttendedToday = await _checkTodayAttendance(nisn);
      if (hasAttendedToday) {
        log('Attendance already exists for NISN $nisn today');
        showToast('Anda sudah melakukan presensi hari ini!', isError: true);
        return false;
      }

      // Generate attendance ID - Using the new sequential method
      String attendanceId = await _generateAttendanceId();
      // Or use transaction version for better concurrency:
      // String attendanceId = await _generateAttendanceIdWithTransaction();

      // Prepare attendance data
      Map<String, dynamic> attendanceData = {
        'id_presensi': attendanceId,
        'nisn': nisn,
        'nama': user.name ?? 'Unknown',
        'tanggal_waktu': Timestamp.now(),
        'status': 'hadir',
        'metode': 'face_recognition',
        'created_at': FieldValue.serverTimestamp(),
      };

      log('Saving attendance data: $attendanceData');

      // Save to Firestore with error handling
      await FirebaseFirestore.instance
          .collection('presensi')
          .doc(attendanceId)
          .set(attendanceData);

      log('Attendance saved successfully with ID: $attendanceId');

      // Verify the save by reading back
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
        showToast('Gagal menyimpan presensi. Silakan coba lagi.',
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

  // Helper function to format time for display
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Helper function to format date for display
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
  void initState() {
    super.initState();
    log('AuthenticateScreen initialized');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Presensi Face Recognition"),
        elevation: 0,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Date Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    'Tanggal Hari Ini',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(DateTime.now()),
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.green.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Camera View
            CameraView(
              onImage: (image) {
                _setImage(image);
              },
              onInputImage: (inputImage) async {
                setState(() => isMatching = true);
                _faceFeatures =
                    await extractFaceFeatures(inputImage, _faceDetector);
                setState(() => isMatching = false);
              },
            ),

            const SizedBox(height: 20),

            // Status and Button
            if (_canAuthenticate)
              isMatching
                  ? Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.green),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Sedang memproses wajah...',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 125),
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          "Lakukan Presensi",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () {
                          setState(() => isMatching = true);
                          _fetchUsersAndMatchFace();
                        },
                      ),
                    ),

            const SizedBox(height: 20),

            // Instructions
            if (!_canAuthenticate)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade700,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Petunjuk Presensi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Posisikan wajah Anda di tengah kamera\n'
                      '2. Pastikan pencahayaan cukup\n'
                      '3. Hindari menggunakan masker atau kacamata\n'
                      '4. Tekan tombol "Lakukan Presensi" setelah wajah terdeteksi',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade700,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 38),
          ],
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

  // A function to calculate the Euclidean distance between two points
  double euclideanDistance(Points p1, Points p2) {
    final sqr =
        math.sqrt(math.pow((p1.x! - p2.x!), 2) + math.pow((p1.y! - p2.y!), 2));
    return sqr;
  }

  _fetchUsersAndMatchFace() {
    log('🔍 Starting face matching process...');

    FirebaseFirestore.instance.collection("wajah_siswa").get().catchError((e) {
      log("❌ Getting User Error: $e");
      setState(() => isMatching = false);
      showToast(
          "Terjadi kesalahan saat mengambil data wajah!. Silahkan coba lagi",
          isError: true);
    }).then((snap) {
      if (snap.docs.isNotEmpty) {
        users.clear();
        log('📊 Total wajah terdaftar: ${snap.docs.length}');

        for (var doc in snap.docs) {
          UserModel user = UserModel.fromJson(doc.data());
          double similarity = compareFaces(_faceFeatures!, user.faceFeatures!);
          if (similarity >= 0.8 && similarity <= 1.5) {
            users.add([user, similarity]);
          }
        }

        log('✅ Filtered Users with matching similarity: ${users.length}');

        setState(() {
          //Sorts the users based on the similarity.
          //More similar face is put first.
          users.sort((a, b) => (((a.last as double) - 1).abs())
              .compareTo(((b.last as double) - 1).abs()));
        });

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
    log('🔄 Starting face matching with ${users.length} candidates...');

    bool faceMatched = false;
    for (List user in users) {
      image1.bitmap = (user.first as UserModel).image;
      image1.imageType = regula.ImageType.PRINTED;

      //Face comparing logic.
      var request = regula.MatchFacesRequest();
      request.images = [image1, image2];
      dynamic value = await regula.FaceSDK.matchFaces(jsonEncode(request));

      var response = regula.MatchFacesResponse.fromJson(json.decode(value));
      dynamic str = await regula.FaceSDK.matchFacesSimilarityThresholdSplit(
          jsonEncode(response!.results), 0.75);

      var split =
          regula.MatchFacesSimilarityThresholdSplit.fromJson(json.decode(str));
      setState(() {
        _similarity = split!.matchedFaces.isNotEmpty
            ? (split.matchedFaces[0]!.similarity! * 100).toStringAsFixed(2)
            : "error";
        log("📊 Face similarity: $_similarity%");

        if (_similarity != "error" && double.parse(_similarity) > 90.00) {
          faceMatched = true;
          loggingUser = user.first;
          log('✅ Face matched for user: ${loggingUser?.name}, NISN: ${loggingUser?.nisn}');
        } else {
          faceMatched = false;
        }
      });

      if (faceMatched) {
        // Save attendance record first
        log('💾 Attempting to save attendance record...');
        bool attendanceSaved = await _saveAttendanceRecord(loggingUser!);

        setState(() {
          trialNumber = 1;
          isMatching = false;
        });

        if (attendanceSaved) {
          log('✅ Attendance saved, navigating to success screen');
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AuthenticatedUserScreen(
                  user: loggingUser!,
                  attendanceAlreadySaved: true, // Mark as already saved
                ),
              ),
            );
          }
        } else {
          log('❌ Failed to save attendance, showing error');
          _showFailureDialog(
            title: "Gagal Menyimpan Presensi",
            description:
                "Terjadi kesalahan saat menyimpan data presensi. Silakan coba lagi.",
          );
        }
        break;
      }
    }

    if (!faceMatched) {
      if (trialNumber == 4) {
        setState(() => trialNumber = 1);
        _showFailureDialog(
          title: "Presensi gagal!",
          description:
              "Wajah tidak cocok dengan yang ada di database!. Silahkan coba kembali",
        );
      } else if (trialNumber == 3) {
        //After 2 trials if the face doesn't match automatically, the registered name prompt
        //will be shown. After entering the name the face registered with the entered name will
        //be fetched and will try to match it with the to be authenticated face.
        //If the faces match, Viola!. Else it means the user is not registered yet.
        setState(() {
          isMatching = false;
          trialNumber++;
        });
        if (!context.mounted) return;
        showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text("Masukkan nama"),
                content: TextFormField(
                  controller: _nameController,
                  cursorColor: Colors.blueAccent,
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        width: 2,
                        color: Colors.blueAccent,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        width: 2,
                        color: Colors.blueAccent,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    hintText: 'Masukkan nama lengkap',
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
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      if (_nameController.text.trim().isEmpty) {
                        showToast("Masukkan nama untuk memproses",
                            isError: true);
                      } else {
                        Navigator.of(context).pop();
                        setState(() => isMatching = true);
                        _fetchUserByName(_nameController.text.trim());
                      }
                    },
                    child: const Text(
                      "Cari",
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                ],
              );
            });
      } else {
        setState(() => trialNumber++);
        _showFailureDialog(
          title: "Presensi gagal!",
          description:
              "Wajah tidak cocok dengan yang ada di database!. Silahkan coba kembali",
        );
      }
    }
  }

  _fetchUserByName(String orgID) {
    FirebaseFirestore.instance
        .collection("wajah_siswa")
        .where("organizationId", isEqualTo: orgID)
        .get()
        .catchError((e) {
      log("Getting User Error: $e");
      setState(() => isMatching = false);
      showToast("Terjadi kesalahan!. Silahkan coba lagi.", isError: true);
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
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                "Ok",
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          ],
        );
      },
    );
  }

  void showToast(String msg, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: isError ? Colors.red : Colors.green,
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
  FaceFeatures? _faceFeatures;
  var image1 = regula.MatchFacesImage();
  var image2 = regula.MatchFacesImage();

  final TextEditingController _nameController = TextEditingController();

  bool _canAuthenticate = false;
  String _similarity = "";
  List<dynamic> users = [];
  bool userExists = false;
  UserModel? loggingUser;
  bool isMatching = false;
  int trialNumber = 1;

  @override
  void dispose() {
    _faceDetector.close();
    _nameController.dispose();
    super.dispose();
  }
}
