import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:math' as math;

typedef RealtimeFrameCallback = void Function(
    InputImage inputImage, List<Face> faces);

class RealtimeCameraView extends StatefulWidget {
  const RealtimeCameraView({
    Key? key,
    required this.onFrame,
    this.overlayColor = const Color(0xFF4CAF50),
    this.enableCameraSwitch = true,
    this.initialLensDirection = CameraLensDirection.front,
  }) : super(key: key);

  final RealtimeFrameCallback onFrame;
  final Color overlayColor;
  final bool enableCameraSwitch;
  final CameraLensDirection initialLensDirection;

  @override
  State<RealtimeCameraView> createState() => _RealtimeCameraViewState();
}

class _RealtimeCameraViewState extends State<RealtimeCameraView>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isProcessing = false;
  Timer? _throttleTimer;
  List<Face> _latestFaces = const [];
  int _imageRotation = 0;
  Size? _imageSize;
  bool _isFrontFacing = false;
  bool _isLowLight = false; // deteksi kondisi gelap
  bool _useScreenLight = false; // overlay layar putih untuk kamera depan
  bool _isSettingExposure = false;
  double? _maxExposureOffset;
  double _normalExposureOffset = 0.0;
  FaceDetector? _frameFaceDetector;
  FaceDetectorMode _currentDetectorMode = FaceDetectorMode.fast;
  CameraLensDirection _selectedLens = CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedLens = widget.initialLensDirection;
    _initializeWithLens(_selectedLens);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _throttleTimer?.cancel();
    _controller?.dispose();
    _frameFaceDetector?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || _controller == null || !_controller!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _controller?.stopImageStream();
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      // Gunakan orientasi dari controller untuk akurasi lintas device
      try {
        _imageRotation = controller.description.sensorOrientation;
      } catch (_) {
        _imageRotation = front.sensorOrientation;
      }
      _isFrontFacing = front.lensDirection == CameraLensDirection.front;
      // Siapkan eksposur otomatis
      try {
        _maxExposureOffset = await controller.getMaxExposureOffset();
        await controller.setExposureMode(ExposureMode.auto);
        await controller.setExposureOffset(_normalExposureOffset);
        await controller.setFocusMode(FocusMode.auto);
        try {
          await controller.setFocusPoint(const Offset(0.5, 0.5));
        } catch (_) {}
        try {
          await controller.setExposurePoint(const Offset(0.5, 0.5));
        } catch (_) {}
      } catch (_) {}
      await controller.startImageStream(_processCameraImage);

      if (!mounted) return;
      setState(() {
        _controller = controller;
      });

      // Inisialisasi FaceDetector sekali (mode awal: fast, tanpa contours)
      _initOrUpdateFaceDetector(lowLight: false);
    } catch (_) {
      // Silently ignore init error to avoid UI crash
    }
  }

  Future<void> _initializeWithLens(CameraLensDirection desired) async {
    try {
      final cameras = await availableCameras();
      final description = cameras.firstWhere(
        (c) => c.lensDirection == desired,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      try {
        _imageRotation = controller.description.sensorOrientation;
      } catch (_) {
        _imageRotation = description.sensorOrientation;
      }
      _isFrontFacing = description.lensDirection == CameraLensDirection.front;
      try {
        _maxExposureOffset = await controller.getMaxExposureOffset();
        await controller.setExposureMode(ExposureMode.auto);
        await controller.setExposureOffset(_normalExposureOffset);
        await controller.setFocusMode(FocusMode.auto);
        try {
          await controller.setFocusPoint(const Offset(0.5, 0.5));
        } catch (_) {}
        try {
          await controller.setExposurePoint(const Offset(0.5, 0.5));
        } catch (_) {}
      } catch (_) {}
      await controller.startImageStream(_processCameraImage);

      if (!mounted) return;
      setState(() {
        _controller = controller;
      });

      _initOrUpdateFaceDetector(lowLight: false);
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    if (!mounted) return;
    final newLens =
        _selectedLens == CameraLensDirection.front ? CameraLensDirection.back : CameraLensDirection.front;
    try {
      await _controller?.stopImageStream();
    } catch (_) {}
    try {
      await _controller?.dispose();
    } catch (_) {}
    setState(() {
      _controller = null;
      _latestFaces = const [];
      _useScreenLight = false;
      _selectedLens = newLens;
    });
    await _initializeWithLens(newLens);
  }

  void _processCameraImage(CameraImage image) {
    if (_isProcessing) return;
    if (_throttleTimer != null && _throttleTimer!.isActive) return;

    _throttleTimer = Timer(const Duration(milliseconds: 100), () {}); // Optimized dari 150ms ke 100ms
    _isProcessing = true;

    _imageSize = (_imageRotation == 90 || _imageRotation == 270)
        ? Size(image.height.toDouble(), image.width.toDouble())
        : Size(image.width.toDouble(), image.height.toDouble());

    // Estimasi luminance dari plane Y (YUV) untuk deteksi low-light
    try {
      final avgY = _estimateLuminance(image);
      final low = avgY != null && avgY < 45.0; // ambang gelap konservatif
      if (low != _isLowLight) {
        _isLowLight = low;
        // Update detector hanya saat status low-light berubah
        _initOrUpdateFaceDetector(lowLight: _isLowLight);
        if (mounted) setState(() {});
      }

      if (_isLowLight) {
        // Boost eksposur; jika kamera belakang, coba torch; jika depan, aktifkan layar putih
        _applyLowLightExposure();
        if (_isFrontFacing) {
          if (!_useScreenLight) {
            _useScreenLight = true;
            if (mounted) setState(() {});
          }
          _setTorch(false);
        } else {
          _useScreenLight = false;
          _setTorch(true);
        }
      } else {
        _useScreenLight = false;
        _setTorch(false);
        _resetExposure();
      }
    } catch (_) {}

    final inputImage = _buildInputImageFromCameraImage(image);
    if (inputImage == null) {
      _isProcessing = false;
      return;
    }

    // Deteksi wajah dengan detector yang dipertahankan
    final detector = _frameFaceDetector;
    detector?.processImage(inputImage).then((faces) {
      // Gating ROI: fokus di bagian tengah layar (kurangi noise)
      if (_imageSize != null && faces.isNotEmpty) {
        final w = _imageSize!.width;
        final h = _imageSize!.height;
        final roi = Rect.fromLTWH(w * 0.2, h * 0.2, w * 0.6, h * 0.6);
        faces = faces.where((f) => roi.overlaps(f.boundingBox)).toList();
      }
      _latestFaces = faces;
      widget.onFrame(inputImage, faces);
    }).whenComplete(() {
      _isProcessing = false;
      if (mounted) setState(() {});
    });
  }

  void _initOrUpdateFaceDetector({required bool lowLight}) {
    try {
      final desiredMode = lowLight ? FaceDetectorMode.accurate : FaceDetectorMode.fast;
      if (_frameFaceDetector != null && _currentDetectorMode == desiredMode) {
        return; // tidak perlu update
      }
      _frameFaceDetector?.close();
      _currentDetectorMode = desiredMode;
      _frameFaceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: true,
          performanceMode: desiredMode,
          enableClassification: false,
          enableContours: false, // matikan untuk hindari spam log "Unknown landmark type"
          minFaceSize: 0.05,
        ),
      );
    } catch (_) {}
  }

  double? _estimateLuminance(CameraImage image) {
    try {
      final Plane yPlane = image.planes.first; // Y
      final bytes = yPlane.bytes;
      if (bytes.isEmpty) return null;
      int sum = 0;
      int count = 0;
      // Sampling setiap 8 byte untuk hemat CPU
      for (int i = 0; i < bytes.length; i += 8) {
        sum += bytes[i];
        count++;
      }
      if (count == 0) return null;
      return sum / count; // 0..255
    } catch (_) {
      return null;
    }
  }

  Future<void> _applyLowLightExposure() async {
    if (_controller == null || _isSettingExposure) return;
    _isSettingExposure = true;
    try {
      await _controller!.setExposureMode(ExposureMode.auto);
      final double target = (_maxExposureOffset ?? 0.0);
      await _controller!.setExposureOffset(target);
    } catch (_) {
    } finally {
      _isSettingExposure = false;
    }
  }

  Future<void> _resetExposure() async {
    if (_controller == null) return;
    try {
      await _controller!.setExposureMode(ExposureMode.auto);
      await _controller!.setExposureOffset(_normalExposureOffset);
    } catch (_) {}
  }

  Future<void> _setTorch(bool on) async {
    if (_controller == null) return;
    try {
      await _controller!.setFlashMode(on ? FlashMode.torch : FlashMode.off);
    } catch (_) {
      // Torch mungkin tidak didukung (terutama kamera depan)
    }
  }

  InputImage? _buildInputImageFromCameraImage(CameraImage image) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final rotation = _rotationIntToInputImageRotation(_imageRotation);

      // YUV420 untuk Android, BGRA8888 untuk iOS/web
      final format = defaultTargetPlatform == TargetPlatform.iOS
          ? InputImageFormat.bgra8888
          : InputImageFormat.yuv420;

      final metadata = InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (_) {
      return null;
    }
  }

  InputImageRotation _rotationIntToInputImageRotation(int rotation) {
    switch (rotation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      case 0:
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Container(
        color: const Color(0xFFF5F5F5),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        fit: StackFit.expand,
        children: [
          SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: CameraPreview(_controller!),
          ),
          // Overlay layar putih untuk membantu pencahayaan pada kamera depan (di bawah bounding box)
          if (_useScreenLight)
            AnimatedOpacity(
              opacity: 0.85,
              duration: const Duration(milliseconds: 200),
              child: Container(color: Colors.white),
            ),
          Positioned.fill(
            child: CustomPaint(
              painter: _FaceOverlayPainter(
                faces: _latestFaces,
                color: widget.overlayColor,
                imageSize: _imageSize,
                isFrontFacing: _isFrontFacing,
              ),
            ),
          ),
          // Indikator jumlah wajah terdeteksi
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tag_faces, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Wajah: ${_latestFaces.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          // Tombol switch kamera depan/belakang
          if (widget.enableCameraSwitch)
            Positioned(
              bottom: 12,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _switchCamera,
                  borderRadius: BorderRadius.circular(28),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.cameraswitch, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
            ),
          // Badge kecil info low-light
          if (_isLowLight)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.dark_mode, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Mode cahaya rendah',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _FaceOverlayPainter extends CustomPainter {
  _FaceOverlayPainter({
    required this.faces,
    required this.color,
    required this.imageSize,
    required this.isFrontFacing,
  });
  final List<Face> faces;
  final Color color;
  final Size? imageSize;
  final bool isFrontFacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withOpacity(0.9);

    if (imageSize == null || imageSize!.width == 0 || imageSize!.height == 0) {
      return;
    }

    // Samakan perhitungan dengan BoxFit.cover pada preview
    final double scale = math.max(size.width / imageSize!.width,
        size.height / imageSize!.height);
    final double dx = (size.width - imageSize!.width * scale) / 2;
    final double dy = (size.height - imageSize!.height * scale) / 2;

    for (final face in faces) {
      Rect r = face.boundingBox;

      // Mirror horizontal jika kamera depan
      double left = isFrontFacing ? (imageSize!.width - (r.left + r.width)) : r.left;
      final mapped = Rect.fromLTWH(
        left * scale + dx,
        r.top * scale + dy,
        r.width * scale,
        r.height * scale,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(mapped, const Radius.circular(8)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FaceOverlayPainter oldDelegate) {
    return oldDelegate.faces != faces || oldDelegate.color != color;
  }
}