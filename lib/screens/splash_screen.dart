import 'package:flutter/material.dart';
import 'dart:async';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showFirstImage = true;

  @override
  void initState() {
    super.initState();

    // Setup animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller)
      ..addListener(() {
        setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _showFirstImage = !_showFirstImage;
          _controller.reset();
        }
      });

    // Start image switching animation
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _controller.forward();
      }
    });

    // Navigate to login screen after 5 seconds
    Timer(const Duration(seconds: 5), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated logo
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: _showFirstImage
                  ? Column(
                      key: const ValueKey('logo1'),
                      children: [
                        Image.asset(
                          'assets/images/logo1.png',
                          width: 200,
                          height: 200,
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'SMART PRESENSEE',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF36C340),
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Absen Digital. Sekolah Makin Pintar!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFFFFC107),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    )
                  : Image.asset(
                      'assets/images/logo2.png',
                      width: 300,
                      height: 300,
                      key: const ValueKey('logo2'),
                    ),
            ),
            const SizedBox(height: 20),
            // Loading indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}
