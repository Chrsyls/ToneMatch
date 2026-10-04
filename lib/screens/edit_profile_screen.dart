import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/dynamic_background.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  final String baseUrl = 'http://192.168.11.166:8000'; // Sesuaikan IP Anda

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/v1/users/usr_dummy_01'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true) {
          final user = data['data'];
          if (mounted) {
            setState(() {
              _nameController.text = user['name'] ?? '';
              _emailController.text = user['email'] ?? '';
            });
          }
        }
      }
    } catch (e) {
      // Tangani error jaringan jika offline
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/v1/users/usr_dummy_01'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "name": _nameController.text,
          "email": _emailController.text,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil berhasil diperbarui! ✨')),
          );
          Navigator.pop(context, true); // Kembali ke profil
        }
      } else {
        throw Exception('Gagal memperbarui profil');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Pastikan backend aktif ($e)')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const DynamicBackground(),
          SafeArea(
            child: Column(
              children: [
                // Header Bar
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF4A2333)),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text('Edit Profil', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF4A2333))),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading && _nameController.text.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          children: [
                            const SizedBox(height: 20),
                            // Avatar Foto Profil
                            Center(
                              child: Stack(
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFff9a9e)]),
                                      boxShadow: [BoxShadow(color: const Color(0xFFE91E63).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                                    ),
                                    child: const Icon(Icons.person, size: 50, color: Colors.white),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4A2333)),
                                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),
                            // Glassmorphism Form Card
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Nama Lengkap', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7A5C61))),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _nameController,
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.white.withOpacity(0.6),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                          prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFE91E63)),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      const Text('Email', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7A5C61))),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _emailController,
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.white.withOpacity(0.6),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                          prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFE91E63)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                            // Tombol Simpan
                            ElevatedButton(
                              onPressed: _isLoading ? null : _updateProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE91E63),
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: const Color(0xFFE91E63).withOpacity(0.5),
                                minimumSize: const Size(double.infinity, 56),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Simpan Perubahan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ],
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