import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIdx = 0;

  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _isTakingPicture = false;

  bool _isReady = false;
  bool _hasFace = false;
  bool _isFlashOn = false;
  String _statusText = 'Menganalisis area wajah...';

  double _minAvailableExposure = 0.0;
  double _maxAvailableExposure = 0.0;

  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initCamera();
  }

  Future<void> _initCamera({int? cameraIndex}) async {
    try {
      _cameras ??= await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        if (cameraIndex != null) {
          _selectedCameraIdx = cameraIndex;
        } else {
          final frontIdx = _cameras!.indexWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
          );
          _selectedCameraIdx = frontIdx != -1 ? frontIdx : 0;
        }

        final CameraDescription selectedCamera = _cameras![_selectedCameraIdx];

        await _controller?.dispose();

        _controller = CameraController(
          selectedCamera,
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.yuv420,
        );

        await _controller!.initialize();

        try {
          _minAvailableExposure = await _controller!.getMinExposureOffset();
          _maxAvailableExposure = await _controller!.getMaxExposureOffset();
          await _controller!.setExposureOffset(_maxAvailableExposure);
        } catch (e) {
          debugPrint("Exposure offset error: $e");
        }

        if (mounted) {
          setState(() => _isCameraInitialized = true);
        }

        int frameCount = 0;
        await _controller!.startImageStream((CameraImage image) {
          if (_isProcessing || _isTakingPicture) return;
          frameCount++;
          if (frameCount % 6 != 0) return; // Cek lebih responsif

          _isProcessing = true;
          _checkLightingAndFace(image);
        });
      }
    } catch (e) {
      debugPrint("Error inisialisasi kamera: $e");
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    setState(() => _isCameraInitialized = false);
    final nextIdx = (_selectedCameraIdx + 1) % _cameras!.length;
    await _initCamera(cameraIndex: nextIdx);
  }

  Future<void> _optimizeLighting(double avgLuminance) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      if (avgLuminance < 40 && !_isFlashOn) {
        await _controller!.setFlashMode(FlashMode.torch);
        if (mounted) setState(() => _isFlashOn = true);
      } else if (avgLuminance >= 55 && _isFlashOn) {
        await _controller!.setFlashMode(FlashMode.off);
        if (mounted) setState(() => _isFlashOn = false);
      }
    } catch (_) {}
  }

  // Algoritma Deteksi Wajah Diperketat (Mencegah objek latar belakang terdeteksi wajah)
  void _checkLightingAndFace(CameraImage image) {
    try {
      final yBytes = image.planes[0].bytes;
      int width = image.width;
      int height = image.height;

      // Hitung rata-rata pencahayaan keseluruhan
      int yTotal = 0;
      for (int i = 0; i < yBytes.length; i += 20) {
        yTotal += yBytes[i];
      }
      double avgLuminance = yTotal / (yBytes.length / 20);

      _optimizeLighting(avgLuminance);
      bool isLightingGood = avgLuminance > 30 && avgLuminance < 235;

      bool isFaceDetected = false;

      if (image.planes.length >= 3) {
        final uBytes = image.planes[1].bytes;
        final vBytes = image.planes[2].bytes;

        // FOKUS PEMINDAIAN: Hanya ambil sampel di area tengah (Area oval wajah)
        int centerYStart = (height * 0.25).toInt();
        int centerYEnd = (height * 0.75).toInt();
        int centerXStart = (width * 0.30).toInt();
        int centerXEnd = (width * 0.70).toInt();

        int skinPixelCount = 0;
        int totalSampledPixels = 0;
        int rowStride = image.planes[1].bytesPerRow;

        for (int y = centerYStart; y < centerYEnd; y += 4) {
          for (int x = centerXStart; x < centerXEnd; x += 4) {
            int index = y * rowStride + x;
            if (index < uBytes.length && index < vBytes.length) {
              int u = uBytes[index];
              int v = vBytes[index];

              // Rentang warna kulit manusia yang akurat pada ruang warna YUV (mencegah dinding/benda cokelat lolos)
              if (v >= 133 && v <= 173 && u >= 80 && u <= 125 && (v - u >= 8)) {
                skinPixelCount++;
              }
              totalSampledPixels++;
            }
          }
        }

        if (totalSampledPixels > 0) {
          double skinPercentage = (skinPixelCount / totalSampledPixels) * 100;
          // Syarat ketat: Minimal 32% area tengah harus berupa piksel kulit manusia asli
          isFaceDetected = skinPercentage > 32.0 && avgLuminance > 25.0;
        }
      }

      String status = '';
      if (!isFaceDetected) {
        status = avgLuminance < 30
            ? 'Ruangan terlalu gelap. Posisikan wajah di dalam oval.'
            : 'Wajah tidak terdeteksi. Posisikan wajah tepat di dalam bingkai oval.';
      } else if (!isLightingGood) {
        status = avgLuminance <= 25 ? 'Terlalu gelap untuk analisis.' : 'Cahaya terlalu silau.';
      } else {
        status = 'Kondisi Wajah & Cahaya Optimal! Silakan ambil foto.';
      }

      bool isReady = isLightingGood && isFaceDetected;

      if (mounted && (_isReady != isReady || _statusText != status || _hasFace != isFaceDetected)) {
        setState(() {
          _isReady = isReady;
          _hasFace = isFaceDetected;
          _statusText = status;
        });
      }
    } catch (_) {
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    try {
      _controller?.setFlashMode(FlashMode.off);
    } catch (_) {}
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (!_isReady || !_hasFace) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wajah belum terdeteksi di dalam bingkai oval!'),
          duration: Duration(milliseconds: 1500),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture || _isTakingPicture) return;

    setState(() => _isTakingPicture = true);

    try {
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
      try {
        await _controller!.setFlashMode(FlashMode.off);
      } catch (_) {}

      final XFile picture = await _controller!.takePicture();
      if (mounted) {
        Navigator.pop(context, File(picture.path));
      }
    } catch (e) {
      debugPrint("Gagal mengambil gambar: $e");
      if (mounted) setState(() => _isTakingPicture = false);
    }
  }

  IconData _getSensorIcon() {
    if (_isReady) return Icons.check_circle_rounded;
    if (!_hasFace) return Icons.face_retouching_natural;
    return Icons.wb_sunny_outlined;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFE91E63)),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final ovalHeight = size.height * 0.45;
    final topOffset = (size.height / 2 - 40) - (ovalHeight / 2);

    var camera = _controller!.value;
    var scale = size.aspectRatio * camera.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: scale,
            child: Center(
              child: CameraPreview(_controller!),
            ),
          ),
          CustomPaint(
            painter: FaceOverlayPainter(isReady: _isReady),
            size: Size(size.width, size.height),
          ),
          if (_isReady)
            AnimatedBuilder(
              animation: _scanController,
              builder: (context, child) {
                final currentY = topOffset + (_scanController.value * ovalHeight);
                return Positioned(
                  top: currentY,
                  left: size.width * 0.2,
                  right: size.width * 0.2,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.8),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 24,
            right: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isReady ? Colors.greenAccent.withOpacity(0.5) : Colors.orangeAccent.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getSensorIcon(),
                            color: _isReady ? Colors.greenAccent : Colors.orangeAccent,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isReady ? 'Kondisi Optimal' : 'Posisikan Wajah',
                            style: TextStyle(
                              color: _isReady ? Colors.greenAccent : Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _statusText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 45,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: const BorderSide(color: Colors.white54, width: 1.5),
                    ),
                  ),
                  child: const Text('Batal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                GestureDetector(
                  onTap: _takePicture,
                  child: AnimatedOpacity(
                    opacity: _isReady ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 300),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 76,
                      width: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isReady ? Colors.greenAccent : Colors.grey,
                          width: 4,
                        ),
                        color: Colors.transparent,
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: _isReady ? 60 : 55,
                          width: _isReady ? 60 : 55,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isReady ? Colors.greenAccent : Colors.grey.shade700,
                          ),
                          child: _isTakingPicture
                              ? const Padding(
                                  padding: EdgeInsets.all(14.0),
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Icon(
                                  _isReady ? Icons.camera_alt : Icons.lock_outline,
                                  color: _isReady ? Colors.black87 : Colors.white60,
                                  size: 26,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _switchCamera,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white12,
                    padding: const EdgeInsets.all(14),
                  ),
                  icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 26),
                  tooltip: 'Ganti Kamera',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FaceOverlayPainter extends CustomPainter {
  final bool isReady;
  FaceOverlayPainter({required this.isReady});

  @override
  void paint(Canvas canvas, Size size) {
    final themeColor = isReady ? Colors.greenAccent : Colors.white;

    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.65)
      ..style = PaintingStyle.fill;

    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final ovalWidth = size.width * 0.7;
    final ovalHeight = size.height * 0.45;
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 40),
      width: ovalWidth,
      height: ovalHeight,
    );

    final ovalPath = Path()..addOval(ovalRect);
    final finalPath = Path.combine(PathOperation.difference, path, ovalPath);
    canvas.drawPath(finalPath, backgroundPaint);

    final borderPaint = Paint()
      ..color = themeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isReady ? 3.0 : 2.0;
    canvas.drawOval(ovalRect, borderPaint);

    final markerPaint = Paint()
      ..color = themeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    double mSize = 30;
    double marginX = 20;
    double marginY = (size.height - ovalHeight) / 2 - 40;

    canvas.drawLine(Offset(marginX, marginY), Offset(marginX + mSize, marginY), markerPaint);
    canvas.drawLine(Offset(marginX, marginY), Offset(marginX, marginY + mSize), markerPaint);

    canvas.drawLine(Offset(size.width - marginX, marginY), Offset(size.width - marginX - mSize, marginY), markerPaint);
    canvas.drawLine(Offset(size.width - marginX, marginY), Offset(size.width - marginX, marginY + mSize), markerPaint);

    canvas.drawLine(Offset(marginX, size.height - marginY - 80), Offset(marginX + mSize, size.height - marginY - 80), markerPaint);
    canvas.drawLine(Offset(marginX, size.height - marginY - 80), Offset(marginX, size.height - marginY - 80 - mSize), markerPaint);

    canvas.drawLine(Offset(size.width - marginX, size.height - marginY - 80), Offset(size.width - marginX - mSize, size.height - marginY - 80), markerPaint);
    canvas.drawLine(Offset(size.width - marginX, size.height - marginY - 80), Offset(size.width - marginX, size.height - marginY - 80 - mSize), markerPaint);
  }

  @override
  bool shouldRepaint(covariant FaceOverlayPainter oldDelegate) {
    return oldDelegate.isReady != isReady;
  }
}