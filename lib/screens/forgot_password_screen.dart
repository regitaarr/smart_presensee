import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;
  bool _otpVerified = false;
  String? _generatedOtp;

  // Ganti dengan API Key Fonnte Anda
  static const String fonnteApiKey = 'xM8VT1bqn3719BuvfPqr';

  String generateOtp({int length = 6}) {
    final rand = Random();
    return List.generate(length, (_) => rand.nextInt(10)).join();
  }

  Future<void> sendOtpWhatsApp(String phone, String otp) async {
    final response = await http.post(
      Uri.parse('https://api.fonnte.com/send'),
      headers: {
        'Authorization': fonnteApiKey,
      },
      body: {
        'target': phone, // format: 628xxxxxx
        'message': 'Kode OTP reset password Anda: $otp',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Gagal mengirim OTP ke WhatsApp');
    }
  }

  Future<void> _handleSendOtp() async {
    setState(() => _isLoading = true);
    try {
      final phone = _phoneController.text.trim();
      if (!RegExp(r'^628[0-9]{8,}$').hasMatch(phone)) {
        _showErrorToast(
            'Format nomor WhatsApp tidak valid (contoh: 628123xxxxxx)');
        return;
      }

      // Cek apakah nomor terdaftar di Firestore
      final query = await FirebaseFirestore.instance
          .collection('pengguna')
          .where('whatsapp', isEqualTo: phone)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        _showErrorToast('Nomor WhatsApp tidak terdaftar');
        return;
      }

      _generatedOtp = generateOtp();
      // Simpan OTP ke Firestore (opsional, bisa juga hanya di state)
      await FirebaseFirestore.instance.collection('otp_reset').doc(phone).set({
        'otp': _generatedOtp,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await sendOtpWhatsApp(phone, _generatedOtp!);

      setState(() {
        _otpSent = true;
      });
      _showSuccessToast('OTP telah dikirim ke WhatsApp Anda');
    } catch (e) {
      _showErrorToast('Terjadi kesalahan: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyOtp() async {
    setState(() => _isLoading = true);
    try {
      final phone = _phoneController.text.trim();
      final inputOtp = _otpController.text.trim();

      // Ambil OTP dari Firestore
      final doc = await FirebaseFirestore.instance
          .collection('otp_reset')
          .doc(phone)
          .get();
      if (doc.exists && doc['otp'] == inputOtp) {
        setState(() {
          _otpVerified = true;
        });
        _showSuccessToast('OTP benar, silakan masukkan password baru');
      } else {
        _showErrorToast('OTP salah');
      }
    } catch (e) {
      _showErrorToast('Terjadi kesalahan: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    setState(() => _isLoading = true);
    try {
      final phone = _phoneController.text.trim();
      final newPassword = _newPasswordController.text.trim();

      final query = await FirebaseFirestore.instance
          .collection('pengguna')
          .where('whatsapp', isEqualTo: phone)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({'password': newPassword});
        // Hapus OTP
        await FirebaseFirestore.instance
            .collection('otp_reset')
            .doc(phone)
            .delete();
        _showSuccessToast('Password berhasil direset!');
        if (mounted) Navigator.of(context).pop();
      } else {
        _showErrorToast('Nomor WhatsApp tidak ditemukan');
      }
    } catch (e) {
      _showErrorToast('Terjadi kesalahan: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: const Color(0xFF81C784),
      textColor: Colors.white,
    );
  }

  void _showErrorToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: const Color(0xFFFF8A65),
      textColor: Colors.white,
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: isPassword,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF81C784), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lupa Kata Sandi',
          style: TextStyle(
            color: Color(0xFF2E7D32),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2E7D32)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F5E8),
              Color(0xFFFFF3E0),
              Color(0xFFE8F5E8),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(20),
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
                      child: const Icon(
                        Icons.lock_reset,
                        size: 60,
                        color: Color(0xFF81C784),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Reset Kata Sandi',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Kami akan mengirimkan kode OTP satu kali ke nomor Whatsapp Anda',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (!_otpSent) ...[
                            _buildModernTextField(
                              controller: _phoneController,
                              label: 'Nomor WhatsApp',
                              hint: 'Contoh: 628123xxxxxx',
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleSendOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF81C784),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
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
                                        'Kirim OTP',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ] else if (!_otpVerified) ...[
                            _buildModernTextField(
                              controller: _otpController,
                              label: 'Kode OTP',
                              hint: 'Masukkan kode OTP',
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleVerifyOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF81C784),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
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
                                        'Verifikasi OTP',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ] else ...[
                            _buildModernTextField(
                              controller: _newPasswordController,
                              label: 'Password Baru',
                              hint: 'Masukkan password baru',
                              isPassword: true,
                              keyboardType: TextInputType.text,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed:
                                    _isLoading ? null : _handleResetPassword,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF81C784),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
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
                                        'Reset Password',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
