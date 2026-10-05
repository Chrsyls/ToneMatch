import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'result_screen.dart';
import 'camera_screen.dart';
import '../widgets/dynamic_background.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  final String baseUrl = 'http://192.168.100.68:8000'; // Sesuaikan IP Anda

  Future<void> _openCustomCamera() async {
    final File? capturedImage = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CameraScreen()),
    );
    
    if (capturedImage != null) {
      await _processAndUploadImage(XFile(capturedImage.path));
    }
  }

  Future<void> _openGallery() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      await _processAndUploadImage(pickedFile);
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFE91E63)),
            SizedBox(height: 20),
            Text(
              'Menganalisis profil wajah...\nMenyelaraskan skema undertone ✨',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF4A2333), fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processAndUploadImage(XFile pickedFile) async {
    _showLoadingDialog();

    try {
      final uri = Uri.parse('$baseUrl/api/v1/analyze/undertone');
      var request = http.MultipartRequest('POST', uri);

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes('image', bytes, filename: 'wajah.jpg'));
      } else {
        request.files.add(await http.MultipartFile.fromPath('image', pickedFile.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      var responseData = json.decode(response.body);

      if (mounted) Navigator.pop(context); // Tutup dialog loading

      if (response.statusCode == 200 && responseData['success'] == true) {
        if (!mounted) return;
        _showSuccessDialog(responseData['message'], responseData['data']['undertone'], pickedFile.path);
      } else {
        throw Exception(responseData['error'] ?? 'Gagal menghubungi server.');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Tutup dialog loading jika terjadi error
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showSuccessDialog(String message, String undertone, String imagePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white.withOpacity(0.95),
        title: const Text('Analisis Selesai ✨', style: TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 16, color: Color(0xFF4A2333))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFFE91E63)),
                  const SizedBox(width: 8),
                  Text('Undertone: ${undertone.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFE91E63))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => ResultScreen(detectedUndertone: undertone, imagePath: imagePath)));
            },
            child: const Text('Lihat Rekomendasi', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE91E63))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const DynamicBackground(),
          Positioned(
            top: -50, left: -50,
            child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.3))),
          ),
          Positioned(
            bottom: 100, right: -80,
            child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFE91E63).withOpacity(0.1))),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(32.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3), 
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5), 
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFff9a9e)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            boxShadow: [BoxShadow(color: const Color(0xFFE91E63).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                          ),
                          child: const Icon(Icons.face_retouching_natural, size: 50, color: Colors.white),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'ToneMatch',
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFF4A2333)),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Unggah foto wajah Anda untuk membedah profil undertone dan temukan makeup yang paling cocok.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Color(0xFF7A5C61), height: 1.5),
                        ),
                        const SizedBox(height: 40),
                        ElevatedButton(
                          onPressed: _openCustomCamera,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE91E63),
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: const Color(0xFFE91E63).withOpacity(0.5),
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt_outlined),
                              SizedBox(width: 12),
                              Text('Ambil Foto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _openGallery,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4A2333),
                            side: const BorderSide(color: Colors.white, width: 2),
                            backgroundColor: Colors.white.withOpacity(0.4),
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_library_outlined),
                              SizedBox(width: 12),
                              Text('Pilih dari Galeri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}