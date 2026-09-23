import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http; // Tambahan untuk ImgBB
import 'dart:convert'; // Tambahan untuk encode Base64
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String _loadingText = '';

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile == null) return;

      setState(() {
        _isLoading = true;
        _loadingText = 'Mengunggah foto ke ImgBB...';
      });

      // 1. Baca file dan ubah ke format Base64 agar mudah dikirim via API
      final bytes = await pickedFile.readAsBytes();
      final String base64Image = base64Encode(bytes);

      // 2. Kirim foto ke server ImgBB
      // GANTI 'API_KEY_ANDA' DENGAN API KEY DARI WEBSITE IMGBB
      const String imgbbApiKey = '04889b35b148848a8233bd521fc2be5c'; 
      final url = Uri.parse('https://api.imgbb.com/1/upload');
      
      final response = await http.post(url, body: {
        'key': imgbbApiKey,
        'image': base64Image,
      });

      final responseData = json.decode(response.body);

      if (responseData['success'] == true) {
        // 3. Ambil URL publik dari respons ImgBB
        final String downloadUrl = responseData['data']['url'];

        setState(() {
          _loadingText = 'Menyimpan data ke Firestore...';
        });

        // 4. Simpan URL tersebut ke Firestore (seperti rencana awal)
        await FirebaseFirestore.instance.collection('classification_histories').add({
          'user_id': 'usr_dummy_01',
          'image_url': downloadUrl,
          'detected_undertone': 'warm', // Simulasi hasil
          'confidence_score': 0.85,
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultScreen(
                detectedUndertone: 'warm',
                imageUrl: downloadUrl, 
              ),
            ),
          );
        }
      } else {
        throw Exception('Gagal mengunggah ke ImgBB');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ... (Sisa kode widget build di bawahnya tetap sama seperti sebelumnya) ...
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ToneMatch', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.face_retouching_natural, size: 100, color: Color(0xFFE91E63)),
              const SizedBox(height: 24),
              const Text(
                'Temukan Undertone Kulitmu',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ambil foto wajahmu dengan pencahayaan yang terang untuk akurasi terbaik.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 48),
              
              if (_isLoading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_loadingText, style: const TextStyle(fontWeight: FontWeight.w500)),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Ambil Foto Kamera'),
                    onPressed: () => _pickAndUploadImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Pilih dari Galeri'),
                    onPressed: () => _pickAndUploadImage(ImageSource.gallery),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}