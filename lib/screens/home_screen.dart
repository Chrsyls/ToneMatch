import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/dynamic_background.dart';
import 'camera_screen.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isAnalyzing = false;
  bool _isCheckingHealth = true;
  bool _isModelReady = false;

  final String vlmBaseUrl = 'https://api.tonematch.web.id';
  final String localBaseUrl = 'http://10.4.89.111:8000';

  @override
  void initState() {
    super.initState();
    _checkVlmHealth();
  }

  Future<void> _checkVlmHealth() async {
    setState(() => _isCheckingHealth = true);
    try {
      final response = await http
          .get(Uri.parse('$vlmBaseUrl/health'))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _isModelReady = (data['status'] == 'ok' && data['model_ready'] == true);
            _isCheckingHealth = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('VLM Health Check Error: $e');
    }
    if (mounted) {
      setState(() {
        _isModelReady = false;
        _isCheckingHealth = false;
      });
    }
  }

  Future<void> _openSmartCamera() async {
    final File? capturedFile = await Navigator.push<File>(
      context,
      MaterialPageRoute(builder: (context) => const CameraScreen()),
    );

    if (capturedFile != null) {
      await _analyzeFaceWithCroppedVlm(capturedFile);
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1080,
    );

    if (pickedFile != null) {
      await _analyzeFaceWithCroppedVlm(File(pickedFile.path));
    }
  }

  // Mengirim foto ke Backend untuk di-Crop otomatis ke area wajah + diprediksi oleh VLM API + Kalibrasi Neutral
  Future<void> _analyzeFaceWithCroppedVlm(File imageFile) async {
    setState(() => _isAnalyzing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final String currentUid = prefs.getString('user_uid') ?? 'usr_dummy_01';

      final req = http.MultipartRequest('POST', Uri.parse('$localBaseUrl/api/v1/analyze/undertone'));
      req.fields['user_id'] = currentUid;
      req.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      final stream = await req.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(stream);

      if (res.statusCode == 200) {
        final jsonRes = jsonDecode(res.body);
        if (jsonRes['success'] == true) {
          final data = jsonRes['data'];
          final String detectedTone = (data['undertone'] ?? 'neutral').toString().toLowerCase();
          final String? savedImagePath = data['image_url'];

          if (mounted) {
            setState(() => _isAnalyzing = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✨ Undertone Terdeteksi: ${detectedTone.toUpperCase()}'),
                backgroundColor: Colors.green.shade700,
              ),
            );

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ResultScreen(
                  detectedUndertone: detectedTone,
                  imagePath: savedImagePath,
                ),
              ),
            );
          }
          return;
        } else {
          throw Exception(jsonRes['error'] ?? 'Gagal menganalisis wajah');
        }
      } else {
        throw Exception('Server merespons dengan status: ${res.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const DynamicBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _checkVlmHealth,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isCheckingHealth
                                ? Colors.orange
                                : (_isModelReady ? Colors.green : Colors.redAccent),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 10,
                              color: _isCheckingHealth
                                  ? Colors.orange
                                  : (_isModelReady ? Colors.green : Colors.redAccent),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isCheckingHealth
                                  ? 'Mengecek Server VLM AI...'
                                  : (_isModelReady ? 'VLM AI + Auto Face-Crop Ready' : 'VLM Server Offline (Ketuk Refresh)'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4A2333),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE91E63).withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.face_retouching_natural,
                        size: 72,
                        color: Color(0xFFE91E63),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Analisis Undertone Kulit',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4A2333),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Sistem otomatis melakukan pemotongan fokus wajah (Auto Face-Crop) & kalibrasi warna kulit bersama VLM AI agar deteksi Warm, Cool, dan Neutral lebih akurat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF7A5C61),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),

                    if (_isAnalyzing)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Column(
                              children: const [
                                CircularProgressIndicator(color: Color(0xFFE91E63)),
                                SizedBox(height: 18),
                                Text(
                                  'Memotong fokus wajah & menganalisis rona kulit bersama VLM AI...',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4A2333),
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Mohon tunggu beberapa detik',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF7A5C61)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        onPressed: _openSmartCamera,
                        icon: const Icon(Icons.camera_front_rounded),
                        label: const Text(
                          'Pindai Wajah (Kamera Pintar)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4A2333),
                          backgroundColor: Colors.white.withOpacity(0.45),
                          side: const BorderSide(color: Color(0xFF4A2333), width: 1.5),
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text(
                          'Pilih Foto dari Galeri',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}