import 'package:face_detector/model/user_model.dart';
import 'package:flutter/material.dart';

class AuthenticatedUserScreen extends StatelessWidget {
  final UserModel user;
  const AuthenticatedUserScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Presensi"),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Hey ${user.name} !",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 26,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Berhasil Presensi!",
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
