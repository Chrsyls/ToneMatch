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

  final String vlmBaseUrl = 'https://api.tonematch.web.id';
  final String localBaseUrl = 'http://10.4.89.111:8000'; // Sesuaikan IP VPS Anda

  Future<void> _openSmartCamera() async {
    final File? capturedFile = await Navigator.push<File>(
      context,
      MaterialPageRoute(builder: (context) => const CameraScreen()),
    );

    if (capturedFile != null) {
      await _analyzeWithVlmApi(capturedFile);
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
      await _analyzeWithVlmApi(File(pickedFile.path));
    }
  }

  // Kirim gambar ke VLM API (POST https://api.tonematch.web.id/predict)
  Future<void> _analyzeWithVlmApi(File imageFile) async {
    setState(() => _isAnalyzing = true);

    try {
      final vlmRequest = http.MultipartRequest('POST', Uri.parse('$vlmBaseUrl/predict'));
      vlmRequest.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final vlmStream = await vlmRequest.send().timeout(const Duration(seconds: 30));
      final vlmResponse = await http.Response.fromStream(vlmStream);

      if (vlmResponse.statusCode == 400) {
        throw Exception('Gambar tidak valid (Error 400). Pastikan format foto benar.');
      } else if (vlmResponse.statusCode == 422) {
        throw Exception('Model tidak dapat mengklasifikasi foto ini (Error 422).');
      } else if (vlmResponse.statusCode == 503) {
        throw Exception('Model VLM belum siap (Error 503). Coba beberapa saat lagi.');
      } else if (vlmResponse.statusCode != 200) {
        throw Exception('Gagal terhubung ke server VLM (Status: ${vlmResponse.statusCode})');
      }

      final vlmData = jsonDecode(vlmResponse.body);
      final String predClass = (vlmData['pred_class'] ?? 'neutral').toString().toLowerCase();
      final int timeMs = vlmData['time_ms'] ?? 0;

      // Ambil UID pengguna yang sedang aktif
      final prefs = await SharedPreferences.getInstance();
      final String currentUid = prefs.getString('user_uid') ?? 'usr_dummy_01';

      // Simpan hasil riwayat ke database MySQL VPS Anda
      String? savedServerImagePath;
      try {
        final saveReq = http.MultipartRequest('POST', Uri.parse('$localBaseUrl/api/v1/analyze/undertone'));
        saveReq.fields['user_id'] = currentUid;
        saveReq.fields['detected_undertone'] = predClass;
        saveReq.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

        final saveStream = await saveReq.send().timeout(const Duration(seconds: 10));
        final saveRes = await http.Response.fromStream(saveStream);

        if (saveRes.statusCode == 200) {
          final saveJson = jsonDecode(saveRes.body);
          savedServerImagePath = saveJson['data']?['image_url'];
        }
      } catch (dbErr) {
        debugPrint('Notice simpan riwayat lokal: $dbErr');
      }

      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✨ VLM Result: ${predClass.toUpperCase()} (${timeMs}ms)'),
            backgroundColor: Colors.green.shade700,
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              detectedUndertone: predClass,
              imagePath: savedServerImagePath,
            ),
          ),
        );
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
                      'Analisis Undertone',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4A2333),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Pindai wajahmu dengan kamera atau pilih foto dari galeri untuk diklasifikasikan secara langsung.',
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
                                  'VLM AI sedang memproses foto wajahmu...',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4A2333),
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Mohon tunggu sebentar',
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
                          'Pindai Wajah',
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