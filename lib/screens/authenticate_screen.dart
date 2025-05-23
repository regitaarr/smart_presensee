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
  // Function to generate attendance ID
  Future<String> _generateAttendanceId() async {
    try {
      const String prefix = 'idpr04';

      // Try to get the collection, if it doesn't exist it will return empty
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('presensi')
          .get()
          .catchError((e) {
        log('Collection might not exist yet: $e');
        return FirebaseFirestore.instance.collection('presensi').get();
      });

      final int attendanceCount = snapshot.docs.length + 1;
      final String formattedNumber = attendanceCount.toString().padLeft(4, '0');

      return prefix + formattedNumber;
    } catch (e) {
      log('Error generating attendance ID: $e');
      // Return a default ID if error occurs
      return 'idpr040001';
    }
  }

  // Function to save attendance record
  Future<void> _saveAttendanceRecord(UserModel user) async {
    try {
      // Check if user has NISN
      if (user.nisn == null || user.nisn!.isEmpty) {
        log('Error: User NISN is null or empty');
        showToast('Error: NISN tidak ditemukan');
        return;
      }

      log('Attempting to save attendance for NISN: ${user.nisn}');

      // Check if attendance record already exists for today
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);
      DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // First, try to check existing records
      QuerySnapshot? existingRecord;
      try {
        existingRecord = await FirebaseFirestore.instance
            .collection('presensi')
            .where('nisn', isEqualTo: user.nisn)
            .where('tanggal_waktu',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('tanggal_waktu',
                isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
            .limit(1)
            .get();
      } catch (e) {
        log('Error checking existing record: $e');
        // If collection doesn't exist, continue to create new record
        existingRecord = null;
      }

      if (existingRecord == null || existingRecord.docs.isEmpty) {
        // Generate new attendance ID
        String attendanceId = await _generateAttendanceId();
        log('Generated attendance ID: $attendanceId');

        // Prepare data to save
        Map<String, dynamic> attendanceData = {
          'id_presensi': attendanceId,
          'nisn': user.nisn,
          'tanggal_waktu': Timestamp.now(),
          'status':
              'hadir', // Automatically set to 'hadir' for face recognition
        };

        log('Saving attendance data: $attendanceData');

        // Create new attendance record
        await FirebaseFirestore.instance
            .collection('presensi')
            .doc(attendanceId)
            .set(attendanceData)
            .then((_) {
          log('Attendance saved successfully with ID: $attendanceId');
          showToast('Presensi berhasil dicatat!');
        }).catchError((error) {
          log('Error saving to Firestore: $error');
          showToast('Gagal menyimpan presensi: $error');
        });
      } else {
        log('Attendance already exists for today');
        showToast('Anda sudah melakukan presensi hari ini');
      }
    } catch (e) {
      log('Unexpected error in _saveAttendanceRecord: $e');
      showToast('Terjadi kesalahan: $e');
    }
  }

  // Test function to create initial collection (for debugging)
  Future<void> _testCreateCollection() async {
    try {
      await FirebaseFirestore.instance.collection('presensi').doc('test').set({
        'test': true,
        'created_at': Timestamp.now(),
      }).then((_) {
        log('Test document created successfully');
        // Delete the test document
        FirebaseFirestore.instance.collection('presensi').doc('test').delete();
      });
    } catch (e) {
      log('Error creating test document: $e');
    }
  }

  // Initialize Firestore collection if needed
  Future<void> _initializeCollection() async {
    try {
      // Try to access the collection
      await FirebaseFirestore.instance
          .collection('presensi')
          .limit(1)
          .get()
          .then((_) {
        log('Presensi collection is accessible');
      }).catchError((e) {
        log('Collection might not exist, will be created on first save: $e');
        // Optionally create a test document to ensure collection exists
        // _testCreateCollection();
      });
    } catch (e) {
      log('Error initializing collection: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeCollection();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Presensi Wajah"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
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
            // TODO Clear comment
            /*if (isMatching)
              const Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: EdgeInsets.only(top: 64),
                  child: AnimatedView(),
                ),
              ),*/

            if (_canAuthenticate)
              isMatching
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : ElevatedButton(
                      child: const Text("Presensi"),
                      onPressed: () {
                        setState(() => isMatching = true);
                        _fetchUsersAndMatchFace();
                      },
                    ),
            const SizedBox(height: 38),

            // Debug button - hapus setelah testing
            /*
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text("Test Save Presensi"),
              onPressed: () async {
                // Test save dengan data dummy
                UserModel testUser = UserModel(
                  idWajah: 'test123',
                  nisn: '1234567890',
                  name: 'Test User',
                );
                await _saveAttendanceRecord(testUser);
              },
            ),
            */
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
    // ignore: body_might_complete_normally_catch_error
    FirebaseFirestore.instance.collection("wajah_siswa").get().catchError((e) {
      log("Getting User Error: $e");
      setState(() => isMatching = false);
      showToast("Terjadi kesalahan!. Silahkan coba lagi");
    }).then((snap) {
      if (snap.docs.isNotEmpty) {
        users.clear();
        log(snap.docs.length.toString(), name: "Total wajah terdaftar");
        for (var doc in snap.docs) {
          UserModel user = UserModel.fromJson(doc.data());
          double similarity = compareFaces(_faceFeatures!, user.faceFeatures!);
          if (similarity >= 0.8 && similarity <= 1.5) {
            users.add([user, similarity]);
          }
        }
        log(users.length.toString(), name: "Filtered Users");
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
          description: "Pastikah wajah terdaftar di database.",
        );
      }
    });
  }

  _matchFaces() async {
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
        log("similarity: $_similarity");

        if (_similarity != "error" && double.parse(_similarity) > 90.00) {
          faceMatched = true;
          loggingUser = user.first;
          log('Face matched for user: ${loggingUser?.name}, NISN: ${loggingUser?.nisn}');
        } else {
          faceMatched = false;
        }
      });
      if (faceMatched) {
        setState(() {
          trialNumber = 1;
          isMatching = false;
        });

        // Save attendance record before navigating
        await _saveAttendanceRecord(loggingUser!);

        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AuthenticatedUserScreen(user: loggingUser!),
            ),
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
                  cursorColor: Colors.redAccent,
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        width: 2,
                        color: Colors.redAccent,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        width: 2,
                        color: Colors.redAccent,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      if (_nameController.text.trim().isEmpty) {
                        showToast("Masukkan nama untuk memproses");
                      } else {
                        Navigator.of(context).pop();
                        setState(() => isMatching = true);
                        _fetchUserByName(_nameController.text.trim());
                      }
                    },
                    child: const Text(
                      "Done",
                      style: TextStyle(
                        color: Colors.redAccent,
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
        // ignore: body_might_complete_normally_catch_error
        .catchError((e) {
      log("Getting User Error: $e");
      setState(() => isMatching = false);
      showToast("Terjadi kesalahan!. Silahkan coba lagi.");
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
          description: "Pastikah wajah terdaftar di database.",
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
          title: Text(title),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                "Ok",
                style: TextStyle(
                  color: Colors.redAccent,
                ),
              ),
            )
          ],
        );
      },
    );
  }

  void showToast(String msg) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: msg.contains('berhasil') ? Colors.green : Colors.red,
      textColor: Colors.white,
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
    super.dispose();
  }
}
