import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/dynamic_background.dart';
import 'edit_profile_screen.dart';
import 'saved_products_screen.dart';
import 'admin_product_screen.dart';
import 'super_admin_dashboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  final String baseUrl = 'http://192.168.11.166:8000'; // Sesuaikan IP Anda

  @override
  void initState() {
    super.initState();
    loadUserProfile();
  }

  Future<void> loadUserProfile() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/v1/users/usr_dummy_01'));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          if (mounted) {
            setState(() {
              _userData = decoded['data'];
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Stack(
          children: [
            DynamicBackground(),
            Center(child: CircularProgressIndicator(color: Color(0xFFE91E63))),
          ],
        ),
      );
    }

    final name = _userData?['name'] ?? 'Pengguna ToneMatch';
    final email = _userData?['email'] ?? 'user@tonematch.com';
    final role = _userData?['role'] ?? 'user';

    return Scaffold(
      body: Stack(
        children: [
          const DynamicBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                const Text('Profil Saya', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF4A2333))),
                const SizedBox(height: 24),
                
                // Kartu Informasi Profil
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 70, height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFff9a9e)]),
                            ),
                            child: const Icon(Icons.person, size: 35, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                                const SizedBox(height: 4),
                                Text(email, style: const TextStyle(fontSize: 13, color: Color(0xFF7A5C61))),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE91E63).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('Role: ${role.toUpperCase()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE91E63))),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                const Text('Menu Utama', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                const SizedBox(height: 12),

                // Tombol Edit Profil
                _buildMenuTile(
                  icon: Icons.edit_outlined,
                  title: 'Edit Profil',
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                    );
                    if (result == true) loadUserProfile();
                  },
                ),

                // Tombol Produk Tersimpan (Wishlist)
                _buildMenuTile(
                  icon: Icons.favorite_outline,
                  title: 'Produk Tersimpan',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedProductsScreen()));
                  },
                ),

                // Menu Khusus Admin (CRUD Produk)
                if (role == 'admin' || role == 'super_admin') ...[
                  const SizedBox(height: 16),
                  const Text('Panel Admin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                  const SizedBox(height: 12),
                  _buildMenuTile(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Manajemen Katalog Produk',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminProductScreen()));
                    },
                  ),
                ],

                // Menu Khusus Super Admin (Analytics & User Management)
                if (role == 'super_admin') ...[
                  _buildMenuTile(
                    icon: Icons.supervisor_account_outlined,
                    title: 'Super Admin Dashboard',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SuperAdminDashboardScreen()));
                    },
                  ),
                ],

                const SizedBox(height: 30),
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keluar akun berhasil')));
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Keluar Akun', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile({required IconData icon, required String title, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              leading: Icon(icon, color: const Color(0xFFE91E63)),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF7A5C61)),
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }
}