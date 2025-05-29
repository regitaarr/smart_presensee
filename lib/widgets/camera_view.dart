//camera_view.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

class CameraView extends StatefulWidget {
  const CameraView({
    Key? key,
    required this.onImage,
    required this.onInputImage,
  }) : super(key: key);

  final Function(Uint8List image) onImage;
  final Function(InputImage inputImage) onInputImage;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with TickerProviderStateMixin {
  File? _image;
  ImagePicker? _imagePicker;
  bool _isProcessing = false;

  late AnimationController _pulseController;
  late AnimationController _fadeController;
  // ignore: unused_field
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _imagePicker = ImagePicker();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _pulseController.repeat(reverse: true);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive sizes based on available space
        final availableHeight = constraints.maxHeight;
        final availableWidth = constraints.maxWidth;

        // Camera height should be responsive to available space
        final cameraHeight = (availableHeight * 0.7).clamp(180.0, 280.0);
        final buttonHeight = 45.0;
        final spacing = 8.0;

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Camera Preview Container
              Container(
                width: availableWidth,
                height: cameraHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: _image != null
                      ? null
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFF9FAFB),
                            Color(0xFFE8F5E8),
                          ],
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _image != null
                      ? _buildImagePreview(availableWidth)
                      : _buildEmptyState(availableWidth, cameraHeight),
                ),
              ),

              SizedBox(height: spacing),

              // Camera Button
              SizedBox(
                width: availableWidth,
                height: buttonHeight,
                child: _buildCameraButton(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImagePreview(double width) {
    return Image.file(
      _image!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }

  Widget _buildEmptyState(double width, double height) {
    return Stack(
      children: [
        // Background pattern
        Positioned.fill(
          child: CustomPaint(
            painter: DotPatternPainter(),
          ),
        ),

        // Main content
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: height - 32,
              maxWidth: width - 32,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title
                const Text(
                  'Ambil Foto Wajah',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),

                const SizedBox(height: 2),

                // Subtitle
                const Text(
                  'Posisikan wajah di tengah',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                // Face outline guide
                Container(
                  width: (width * 0.25).clamp(50.0, 90.0),
                  height: (width * 0.3).clamp(60.0, 100.0),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF81C784).withOpacity(0.5),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Stack(
                    children: _buildMiniCornerIndicators(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCornerIndicators() {
    return [
      Positioned(
        top: 6,
        left: 6,
        child: _buildCornerIndicator(),
      ),
      Positioned(
        top: 6,
        right: 6,
        child: Transform.rotate(
          angle: 1.5708,
          child: _buildCornerIndicator(),
        ),
      ),
      Positioned(
        bottom: 6,
        left: 6,
        child: Transform.rotate(
          angle: -1.5708,
          child: _buildCornerIndicator(),
        ),
      ),
      Positioned(
        bottom: 6,
        right: 6,
        child: Transform.rotate(
          angle: 3.14159,
          child: _buildCornerIndicator(),
        ),
      ),
    ];
  }

  List<Widget> _buildMiniCornerIndicators() {
    return [
      Positioned(
        top: 6,
        left: 6,
        child: _buildMiniCornerIndicator(),
      ),
      Positioned(
        top: 6,
        right: 6,
        child: Transform.rotate(
          angle: 1.5708,
          child: _buildMiniCornerIndicator(),
        ),
      ),
      Positioned(
        bottom: 6,
        left: 6,
        child: Transform.rotate(
          angle: -1.5708,
          child: _buildMiniCornerIndicator(),
        ),
      ),
      Positioned(
        bottom: 6,
        right: 6,
        child: Transform.rotate(
          angle: 3.14159,
          child: _buildMiniCornerIndicator(),
        ),
      ),
    ];
  }

  Widget _buildCornerIndicator() {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        color: Color(0xFF81C784),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(3),
        ),
      ),
    );
  }

  Widget _buildMiniCornerIndicator() {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: const Color(0xFF81C784).withOpacity(0.5),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(2),
        ),
      ),
    );
  }

  Widget _buildCameraButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF81C784),
            Color(0xFF66BB6A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF81C784).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _getImage,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isProcessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _image != null ? Icons.refresh : Icons.camera_alt_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _image != null ? "Foto Ulang" : "Ambil Foto",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future _getImage() async {
    setState(() {
      _image = null;
      _isProcessing = true;
    });

    try {
      final pickedFile = await _imagePicker?.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        await _setPickedFile(pickedFile);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future _setPickedFile(XFile? pickedFile) async {
    if (pickedFile == null) return;

    try {
      if (kIsWeb) {
        // Handle web platform
        final bytes = await pickedFile.readAsBytes();
        widget.onImage(bytes);

        InputImage inputImage = InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
            size: Size(800, 800),
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.bgra8888,
            bytesPerRow: 800 * 4,
          ),
        );
        widget.onInputImage(inputImage);
      } else {
        // Handle mobile platforms
        final path = pickedFile.path;
        setState(() {
          _image = File(path);
        });

        Uint8List imageBytes = _image!.readAsBytesSync();
        widget.onImage(imageBytes);

        InputImage inputImage = InputImage.fromFilePath(path);
        widget.onInputImage(inputImage);
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
    }
  }
}

// Custom painter for dot pattern background
class DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF81C784).withOpacity(0.05)
      ..style = PaintingStyle.fill;

    const double spacing = 20.0;
    const double dotRadius = 1.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
