import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../widgets/dynamic_background.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  bool _isFetching = true; 
  bool _isSaving = false;  
  
  File? _profileImage;     
  String? _serverAvatarUrl; // Menyimpan URL gambar dari backend
  bool _isAvatarRemoved = false; // Flag jika tombol hapus ditekan
  
  final String baseUrl = 'http://10.4.89.111:8000'; // IP Anda

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isFetching = true);
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
              _serverAvatarUrl = user['avatar_url']; // Ambil URL gambar saat ini
              _isAvatarRemoved = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading user: $e");
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  Future<void> _pickProfileImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
        _isAvatarRemoved = false; // Batal hapus jika milih foto baru
      });
    }
  }

  Future<void> _updateProfile({bool isReset = false}) async {
    setState(() => _isSaving = true);
    try {
      var uri = Uri.parse('$baseUrl/api/v1/users/usr_dummy_01');
      var request = http.MultipartRequest('PUT', uri);

      if (isReset) {
        // DATA RESET DEFAULT
        request.fields['name'] = "Alvito Aryo";
        request.fields['email'] = "test@tonematch.app";
        request.fields['remove_avatar'] = "true";
      } else {
        // DATA EDIT NORMAL
        request.fields['name'] = _nameController.text;
        request.fields['email'] = _emailController.text;
        request.fields['remove_avatar'] = _isAvatarRemoved ? "true" : "false";

        if (_profileImage != null && !_isAvatarRemoved) {
          request.files.add(await http.MultipartFile.fromPath('avatar', _profileImage!.path));
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isReset ? 'Kredensial direset ke default! 🐛' : 'Profil berhasil diperbarui! ✨')),
          );
          
          Navigator.pop(context, {
            "name": isReset ? "Alvito Aryo" : _nameController.text,
            "email": isReset ? "test@tonematch.app" : _emailController.text,
            "imagePath": isReset || _isAvatarRemoved ? null : _profileImage?.path,
            "serverAvatarUrl": responseData['avatar_url'],
            "isAvatarRemoved": isReset || _isAvatarRemoved
          }); 
        }
      } else {
        throw Exception('Gagal memperbarui profil: ${response.body}');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Fungsi Helper untuk menentukan gambar mana yang akan dirender
  ImageProvider? _getAvatarImage() {
    if (_isAvatarRemoved) return null;
    if (_profileImage != null) return FileImage(_profileImage!);
    if (_serverAvatarUrl != null) return NetworkImage('$baseUrl/$_serverAvatarUrl');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    bool hasImage = _getAvatarImage() != null;

    return Scaffold(
      body: Stack(
        children: [
          const DynamicBackground(),
          SafeArea(
            child: Column(
              children: [
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
                  child: _isFetching
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          children: [
                            const SizedBox(height: 20),
                            // Avatar Foto Profil Dinamis
                            Center(
                              child: Stack(
                                children: [
                                  GestureDetector(
                                    onTap: _pickProfileImage,
                                    child: Container(
                                      width: 110,
                                      height: 110,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        image: hasImage 
                                            ? DecorationImage(image: _getAvatarImage()!, fit: BoxFit.cover) 
                                            : null,
                                        gradient: !hasImage 
                                            ? const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFff9a9e)])
                                            : null,
                                        boxShadow: [BoxShadow(color: const Color(0xFFE91E63).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                                      ),
                                      child: !hasImage 
                                          ? const Icon(Icons.person, size: 50, color: Colors.white)
                                          : null,
                                    ),
                                  ),
                                  // Icon Kamera (Edit)
                                  Positioned(
                                    bottom: 0,
                                    right: 5,
                                    child: GestureDetector(
                                      onTap: _pickProfileImage,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4A2333)),
                                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                  // TOMBOL HAPUS FOTO (Hanya muncul jika ada foto)
                                  if (hasImage)
                                    Positioned(
                                      top: 0,
                                      right: 5,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _profileImage = null;
                                            _isAvatarRemoved = true;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent, border: Border.all(color: Colors.white, width: 2)),
                                          child: const Icon(Icons.delete, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),
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
                            ElevatedButton(
                              onPressed: _isSaving ? null : () => _updateProfile(isReset: false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE91E63),
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: const Color(0xFFE91E63).withOpacity(0.5),
                                minimumSize: const Size(double.infinity, 56),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _isSaving
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Simpan Perubahan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                            
                            // TOMBOL DEBUG: RESET KREDENSIAL DEFAULT
                            const SizedBox(height: 24),
                            TextButton.icon(
                              onPressed: _isSaving ? null : () => _updateProfile(isReset: true),
                              icon: const Icon(Icons.bug_report, color: Colors.grey),
                              label: const Text('Reset Kredensial (Debug)', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.3),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.grey, width: 1)),
                              ),
                            ),
                            const SizedBox(height: 40),
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