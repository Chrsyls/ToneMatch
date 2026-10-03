import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'saved_products_screen.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
// Import widget background dinamis
import '../widgets/dynamic_background.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String userName = 'Alvito Aryo';
  String userEmail = 'test@tonematch.app';
  String? avatarUrl;
  final String baseUrl = 'http://192.168.11.166:8000';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/v1/users/usr_dummy_01'));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          setState(() {
            userName = decoded['data']['name'] ?? 'Alvito Aryo';
            userEmail = decoded['data']['email'] ?? 'test@tonematch.app';
            avatarUrl = decoded['data']['avatar_url'];
          });
        }
      }
    } catch (e) {
      // Ignore if offline
    }
  }

  Widget _buildGlassMenu(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.6)),
            ),
            child: ListTile(
              leading: Icon(icon, color: isDestructive ? Colors.red.shade400 : const Color(0xFFE91E63)),
              title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDestructive ? Colors.red.shade400 : const Color(0xFF4A2333))),
              trailing: const Icon(Icons.chevron_right, color: Color(0xFF7A5C61)),
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // MEMANGGIL BACKGROUND DINAMIS DI SINI
          const DynamicBackground(),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: const Color(0xFFE0E0E0),
                      image: avatarUrl != null && avatarUrl!.isNotEmpty
                          ? DecorationImage(fit: BoxFit.cover, image: NetworkImage('$baseUrl/$avatarUrl'))
                          : null,
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFE91E63).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: avatarUrl == null || avatarUrl!.isEmpty
                        ? const Icon(Icons.person, size: 70, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(userName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                  const SizedBox(height: 4),
                  Text(userEmail, style: const TextStyle(fontSize: 16, color: Color(0xFF7A5C61))),
                  const SizedBox(height: 30),
                  
                  _buildGlassMenu(Icons.edit_outlined, 'Edit Profil', () async {
                    final result = await Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreen(
                          initialName: userName,
                          initialEmail: userEmail,
                          initialAvatarUrl: avatarUrl,
                        ),
                      ),
                    );
                    if (result == true) _loadUserProfile();
                  }),
                  _buildGlassMenu(Icons.bookmark_outline, 'Produk Tersimpan', () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedProductsScreen()));
                  }),
                  _buildGlassMenu(Icons.settings_outlined, 'Pengaturan', () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                  }),
                  const Spacer(),
                  _buildGlassMenu(Icons.logout, 'Keluar (Logout)', () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitur Logout menyusul')));
                  }, isDestructive: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}