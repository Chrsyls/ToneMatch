import 'dart:ui';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class EditProfileScreen extends StatefulWidget {
  final String initialName;
  final String initialEmail;
  final String? initialAvatarUrl;

  const EditProfileScreen({
    super.key,
    required this.initialName,
    required this.initialEmail,
    this.initialAvatarUrl,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  
  XFile? _selectedImage;
  String? _currentAvatarUrl;
  bool _isAvatarRemoved = false;
  bool _isSaving = false;
  final String baseUrl = 'http://192.168.11.166:8000';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController(text: widget.initialEmail);
    _currentAvatarUrl = widget.initialAvatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
        _isAvatarRemoved = false;
      });
    }
  }

  void _removeAvatar() {
    setState(() {
      _selectedImage = null;
      _currentAvatarUrl = null;
      _isAvatarRemoved = true;
    });
  }

  Future<void> _updateProfile() async {
    setState(() { _isSaving = true; });
    try {
      var request = http.MultipartRequest('PUT', Uri.parse('$baseUrl/api/v1/users/usr_dummy_01'));
      request.fields['name'] = _nameController.text.trim();
      request.fields['email'] = _emailController.text.trim();
      request.fields['remove_avatar'] = _isAvatarRemoved.toString();

      if (_selectedImage != null) {
        if (kIsWeb) {
          final bytes = await _selectedImage!.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes('avatar', bytes, filename: 'avatar.jpg'));
        } else {
          request.files.add(await http.MultipartFile.fromPath('avatar', _selectedImage!.path));
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil & Kredensial berhasil diperbarui! ✨'))
          );
          Navigator.pop(context, true);
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Terjadi kesalahan pada server.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'))
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isSaving = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Menentukan tampilan gambar profil (ikon default siluet abu-abu jika tidak ada foto)
    ImageProvider? avatarProvider;
    if (_selectedImage != null) {
      avatarProvider = kIsWeb ? NetworkImage(_selectedImage!.path) : FileImage(File(_selectedImage!.path)) as ImageProvider;
    } else if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty && !_isAvatarRemoved) {
      avatarProvider = NetworkImage('$baseUrl/$_currentAvatarUrl');
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Edit Profil', style: TextStyle(color: Color(0xFF4A2333), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF4A2333)),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFff9a9e), Color(0xFFfecfef), Color(0xFFfdfbfb)],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(28.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Foto Profil dengan ikon siluet abu-abu default referensi
                          Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFE91E63).withOpacity(0.2),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 55,
                                  backgroundColor: const Color(0xFFE0E0E0), // Warna latar abu-abu default
                                  backgroundImage: avatarProvider,
                                  child: avatarProvider == null
                                      ? const Icon(Icons.person, size: 70, color: Colors.white) // Ikon siluet default
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: InkWell(
                                  onTap: _pickImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFE91E63),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Opsi Hapus Foto Profil kembali ke Default
                          if (_selectedImage != null || (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty && !_isAvatarRemoved))
                            TextButton.icon(
                              onPressed: _removeAvatar,
                              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                              label: const Text('Hapus Foto Profil', style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                            )
                          else
                            const Text(
                              'Ketuk ikon kamera untuk mengganti foto',
                              style: TextStyle(fontSize: 13, color: Color(0xFF7A5C61), fontWeight: FontWeight.w500),
                            ),
                          
                          const SizedBox(height: 24),
                          
                          // Input Nama
                          TextField(
                            controller: _nameController,
                            style: const TextStyle(color: Color(0xFF4A2333), fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              labelText: 'Nama Lengkap',
                              labelStyle: const TextStyle(color: Color(0xFF7A5C61)),
                              prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFE91E63)),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.6),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFFE91E63), width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Input Email
                          TextField(
                            controller: _emailController,
                            style: const TextStyle(color: Color(0xFF4A2333), fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              labelText: 'Email Kredensial',
                              labelStyle: const TextStyle(color: Color(0xFF7A5C61)),
                              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFE91E63)),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.6),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFFE91E63), width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // Tombol Simpan
                          ElevatedButton(
                            onPressed: _isSaving ? null : _updateProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE91E63),
                              foregroundColor: Colors.white,
                              elevation: 6,
                              shadowColor: const Color(0xFFE91E63).withOpacity(0.4),
                              minimumSize: const Size(double.infinity, 54),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Text(
                                    'Simpan Perubahan',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                          ),
                        ],
                      ),
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