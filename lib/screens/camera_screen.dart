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

  bool _isCameraInitialized = false;
  bool _isProcessing = false;

  bool _isReady = false;
  bool _hasFace = false;
  String _statusText = 'Menganalisis area wajah...';

  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        CameraDescription selectedCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras!.first,
        );

        _controller = CameraController(
          selectedCamera,
          ResolutionPreset.medium, // Resolusi medium optimal untuk scanning frame cepat
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.yuv420,
        );

        await _controller!.initialize();

        if (mounted) {
          setState(() => _isCameraInitialized = true);
        }

        int frameCount = 0;
        _controller!.startImageStream((CameraImage image) {
          if (_isProcessing) return;
          frameCount++;
          if (frameCount % 10 != 0) return; // Proses tiap 10 frame untuk cegah lag

          _isProcessing = true;
          _checkLightingAndFace(image);
        });
      }
    } catch (e) {
      debugPrint("Error inisialisasi kamera: $e");
    }
  }

  void _checkLightingAndFace(CameraImage image) {
    try {
      // 1. CEK PENCAHAYAAN (Luminance - Y)
      final yBytes = image.planes[0].bytes;
      int yTotal = 0;
      for (int i = 0; i < yBytes.length; i += 20) {
        yTotal += yBytes[i];
      }
      double avgLuminance = yTotal / (yBytes.length / 20);
      
      // Batas cahaya yang aman
      bool isLightingGood = avgLuminance > 50 && avgLuminance < 220; 

      // 2. CEK WAJAH KETAT (Chrominance - U & V)
      bool isFaceDetected = false;

      if (image.planes.length >= 3) {
        final uBytes = image.planes[1].bytes;
        final vBytes = image.planes[2].bytes;

        // FOKUS AREA: Hanya memindai 40% area di tengah persis (menghindari baju dan tembok di pinggir)
        int startIdx = (uBytes.length * 0.3).toInt();
        int endIdx = (uBytes.length * 0.7).toInt();

        int skinPixelCount = 0;
        int totalSampledPixels = 0;

        // Sampling lebih rapat (tiap 5 piksel) agar akurasi di tengah oval lebih tajam
        for (int i = startIdx; i < endIdx; i += 5) {
          int u = uBytes[i];
          int v = vBytes[i];

          // ALGORITMA BARU: Membedakan benda mati dan kulit
          // - V (Rona hangat/merah) di rentang 132-175
          // - U (Rona dingin/biru) di rentang 75-130
          // - (v - u >= 10): Mencegah tembok, pintu, atau benda netral lolos
          if (v >= 132 && v <= 175 && u >= 75 && u <= 130 && (v - u >= 10)) {
            skinPixelCount++;
          }
          totalSampledPixels++;
        }

        double skinPercentage = (skinPixelCount / totalSampledPixels) * 100;
        
        // Syarat: Minimal 20% isi tengah oval harus kulit, dan tidak boleh dalam kondisi gelap gulita (avgLuminance > 40)
        isFaceDetected = skinPercentage > 20.0 && avgLuminance > 40.0; 
      }

      // 3. LOGIKA INSTRUKSI UI
      String status = '';
      if (!isFaceDetected) {
        status = 'Wajah tidak terdeteksi. Posisikan ke dalam oval.';
      } else if (!isLightingGood) {
        status = avgLuminance <= 50
            ? 'Terlalu Gelap, cari tempat lebih terang.'
            : 'Terlalu Terang, kurangi cahaya/hindari backlight.';
      } else {
        status = 'Kondisi Optimal! Silakan ambil foto.';
      }

      bool isReady = isLightingGood && isFaceDetected;

      if (_isReady != isReady || _statusText != status || _hasFace != isFaceDetected) {
        setState(() {
          _isReady = isReady;
          _hasFace = isFaceDetected;
          _statusText = status;
        });
      }
    } catch (e) {
      // Abaikan jika frame sedang diputar/rusak
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture) return;

    try {
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }

      final XFile picture = await _controller!.takePicture();
      if (mounted) {
        Navigator.pop(context, File(picture.path));
      }
    } catch (e) {
      debugPrint("Gagal mengambil gambar: $e");
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
        body: Center(child: CircularProgressIndicator(color: Color(0xFFE91E63))),
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
          // 1. Tampilan Kamera (Scaled Anti Distorsi)
          Transform.scale(
            scale: scale,
            child: Center(
              child: CameraPreview(_controller!),
            ),
          ),

          // 2. Overlay Oval
          CustomPaint(
            painter: FaceOverlayPainter(isReady: _isReady),
            size: Size(size.width, size.height),
          ),

          // 3. Animasi Scanner
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
                        BoxShadow(color: Colors.greenAccent.withOpacity(0.8), blurRadius: 10, spreadRadius: 2)
                      ],
                    ),
                  ),
                );
              },
            ),

          // 4. Panel Instruksi
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
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _isReady ? Colors.greenAccent.withOpacity(0.5) : Colors.white24, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getSensorIcon(),
                            color: _isReady ? Colors.greenAccent : Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isReady ? 'Kondisi Optimal' : (!_hasFace ? 'Posisikan Wajah' : 'Periksa Cahaya'),
                            style: TextStyle(
                                color: _isReady ? Colors.greenAccent : Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
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

          // 5. Tombol Aksi
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: const BorderSide(color: Colors.white54, width: 1.5),
                    ),
                  ),
                  child: const Text('Batal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),

                GestureDetector(
                  onTap: _takePicture,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 75,
                    width: 75,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _isReady ? Colors.greenAccent : const Color(0xFFE91E63), width: 4),
                      color: Colors.transparent,
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: _isReady ? 60 : 55,
                        width: _isReady ? 60 : 55,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isReady ? Colors.greenAccent : const Color(0xFFE91E63),
                        ),
                        child: _isReady ? const Icon(Icons.camera_alt, color: Colors.black54, size: 28) : null,
                      ),
                    ),
                  ),
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
    canvas.drawLine(
        Offset(size.width - marginX, marginY), Offset(size.width - marginX, marginY + mSize), markerPaint);

    canvas.drawLine(
        Offset(marginX, size.height - marginY - 80), Offset(marginX + mSize, size.height - marginY - 80), markerPaint);
    canvas.drawLine(
        Offset(marginX, size.height - marginY - 80), Offset(marginX, size.height - marginY - 80 - mSize), markerPaint);

    canvas.drawLine(Offset(size.width - marginX, size.height - marginY - 80),
        Offset(size.width - marginX - mSize, size.height - marginY - 80), markerPaint);
    canvas.drawLine(Offset(size.width - marginX, size.height - marginY - 80),
        Offset(size.width - marginX, size.height - marginY - 80 - mSize), markerPaint);
  }

  @override
  bool shouldRepaint(covariant FaceOverlayPainter oldDelegate) {
    return oldDelegate.isReady != isReady;
  }
}