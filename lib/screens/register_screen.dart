import 'dart:convert';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_presensee/model/face_features.dart';
import 'package:smart_presensee/model/user_model.dart';
import 'package:smart_presensee/services/extract_features.dart';
import 'package:smart_presensee/widgets/camera_view.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );
  String? _image;
  FaceFeatures? _faceFeatures;

  bool isRegistering = false;
  final _formFieldKey = GlobalKey<FormState>();
  final TextEditingController _nisnController = TextEditingController();
  String? selectedStudentName;

  // Function to generate face ID
  Future<String> _generateFaceId() async {
    const String prefix = 'idwj04';
    final QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('wajah_siswa').get();

    final int faceCount = snapshot.docs.length + 1;
    final String formattedNumber = faceCount.toString().padLeft(4, '0');

    return prefix + formattedNumber;
  }

  // Function to validate and get student data
  Future<Map<String, dynamic>?> _validateStudent(String nisn) async {
    try {
      DocumentSnapshot studentDoc =
          await FirebaseFirestore.instance.collection('siswa').doc(nisn).get();

      if (studentDoc.exists) {
        return studentDoc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      log('Error validating student: $e');
      return null;
    }
  }

  // Function to check if face is already registered for this NISN
  Future<bool> _checkExistingFaceRegistration(String nisn) async {
    try {
      QuerySnapshot existingFace = await FirebaseFirestore.instance
          .collection('wajah_siswa')
          .where('nisn', isEqualTo: nisn)
          .limit(1)
          .get();

      return existingFace.docs.isNotEmpty;
    } catch (e) {
      log('Error checking existing face: $e');
      return false;
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
              Color(0xFFE8F5E8), // Light pastel green
              Color(0xFFFFF3E0), // Light pastel orange
              Color(0xFFE8F5E8), // Light pastel green
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // Logo and Title Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF81C784).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo1.png',
                      width: 60,
                      height: 60,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SMART PRESENSEE',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF36C340),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Absen Digital. Sekolah Makin Pintar!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFFFFC107),
                      letterSpacing: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Camera View
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CameraView(
                        onImage: (image) {
                          setState(() {
                            _image = base64Encode(image);
                          });
                        },
                        onInputImage: (inputImage) async {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF4CAF50)),
                              ),
                            ),
                          );
                          await extractFaceFeatures(inputImage, _faceDetector)
                              .then((faceFeatures) {
                            setState(() {
                              _faceFeatures = faceFeatures;
                            });
                            Navigator.of(context).pop();
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_image != null) ...[
                    // Form section
                    Form(
                      key: _formFieldKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NISN Siswa',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nisnController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Masukkan NISN siswa',
                              prefixIcon: const Icon(
                                Icons.badge_outlined,
                                color: Color(0xFF81C784),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF81C784), width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFEF4444)),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFEF4444), width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "NISN tidak boleh kosong";
                              }
                              if (value.trim().length < 10) {
                                return "NISN harus 10 digit";
                              }
                              return null;
                            },
                            onChanged: (value) async {
                              if (value.length == 10) {
                                // Auto validate student when NISN is complete
                                Map<String, dynamic>? studentData =
                                    await _validateStudent(value);
                                if (studentData != null) {
                                  setState(() {
                                    selectedStudentName =
                                        studentData['nama_siswa'];
                                  });
                                } else {
                                  setState(() {
                                    selectedStudentName = null;
                                  });
                                }
                              }
                            },
                          ),

                          const SizedBox(height: 20),

                          // Student info display
                          if (selectedStudentName != null) ...[
                            Center(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E8),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF81C784),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Data Siswa Ditemukan:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF4CAF50),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Nama: $selectedStudentName',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Register button
                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF8A65), // Pastel orange
                                  Color(0xFFFF7043), // Darker orange
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFFF8A65).withOpacity(0.4),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: isRegistering ? null : _registerFace,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: isRegistering
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Daftarkan Wajah',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _registerFace() async {
    if (!_formFieldKey.currentState!.validate()) return;
    if (_faceFeatures == null) {
      showToast('Silakan ambil foto wajah terlebih dahulu');
      return;
    }

    final String nisn = _nisnController.text.trim();

    setState(() {
      isRegistering = true;
    });

    try {
      // Validate student exists
      Map<String, dynamic>? studentData = await _validateStudent(nisn);
      if (studentData == null) {
        showToast('NISN tidak ditemukan dalam database siswa');
        return;
      }

      // Check if face already registered for this NISN
      bool faceExists = await _checkExistingFaceRegistration(nisn);
      if (faceExists) {
        showToast('Wajah sudah terdaftar untuk NISN ini');
        return;
      }

      // Generate face ID
      String faceId = await _generateFaceId();

      // Create user model WITHOUT name field - only NISN is needed for identification
      UserModel user = UserModel(
        idWajah: faceId,
        nisn: nisn,
        name:
            null, // Remove name field - name can be retrieved from 'siswa' collection using NISN
        gambar: _image,
        faceFeatures: _faceFeatures,
      );

      // Save to Firestore without 'name' field
      Map<String, dynamic> faceData = user.toJson();

      // Explicitly remove 'name' field if it exists to ensure it's not saved
      faceData.remove('name');
      faceData.remove('registeredOn'); // Remove registeredOn field

      log('Saving face data without name field: $faceData');

      await FirebaseFirestore.instance
          .collection("wajah_siswa")
          .doc(faceId)
          .set(faceData);

      showToast('Wajah berhasil didaftarkan!');

      // Delay and navigate back
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      showToast('Terjadi kesalahan: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          isRegistering = false;
        });
      }
    }
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

  @override
  void dispose() {
    _faceDetector.close();
    _nisnController.dispose();
    super.dispose();
  }
}
