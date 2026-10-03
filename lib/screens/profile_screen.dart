import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'saved_products_screen.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'super_admin_dashboard_screen.dart';
import 'user_management_screen.dart';
import '../widgets/dynamic_background.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  // Kosongkan nilai awal agar tidak terjadi kedipan teks yang salah
  String userName = '';
  String userEmail = '';
  String userRole = 'user'; 
  String? avatarUrl;
  bool _isLoading = true; // Status loading aktif di awal
  final String baseUrl = 'http://192.168.100.68:8000';

  @override
  void initState() {
    super.initState();
    loadUserProfile();
  }

  Future<void> loadUserProfile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/v1/users/usr_dummy_01'));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true && mounted) {
          setState(() {
            userName = decoded['data']['name'] ?? 'Pengguna ToneMatch';
            userEmail = decoded['data']['email'] ?? 'test@tonematch.app';
            userRole = decoded['data']['role'] ?? 'user';
            avatarUrl = decoded['data']['avatar_url'];
          });
        }
      }
    } catch (e) {
      // Fallback jika offline
      if (mounted) {
        setState(() {
          userName = 'Alvito Aryo';
          userEmail = 'test@tonematch.app';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildRoleBadge() {
    String label = 'User';
    Color badgeColor = Colors.blueGrey;

    if (userRole == 'super_admin') {
      label = 'Super Admin';
      badgeColor = const Color(0xFF9C27B0); 
    } else if (userRole == 'admin') {
      label = 'Admin';
      badgeColor = const Color(0xFF3F51B5); 
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withOpacity(0.4), width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1),
      ),
    );
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
          const DynamicBackground(),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                : SingleChildScrollView( // Mengatasi masalah overflow dengan membuat halaman bisa di-scroll
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 105, height: 105,
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
                              ? const Icon(Icons.person, size: 65, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(userName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                        const SizedBox(height: 2),
                        Text(userEmail, style: const TextStyle(fontSize: 15, color: Color(0xFF7A5C61))),
                        
                        _buildRoleBadge(),
                        
                        const SizedBox(height: 24),
                        
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
                          if (result == true) loadUserProfile();
                        }),
                        _buildGlassMenu(Icons.bookmark_outline, 'Produk Tersimpan', () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedProductsScreen()));
                        }),

                        // Menu Eksklusif Super Admin
                        if (userRole == 'super_admin') ...[
                          _buildGlassMenu(Icons.dashboard_outlined, 'Dashboard & Laporan Analitik', () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const SuperAdminDashboardScreen()));
                          }),
                          _buildGlassMenu(Icons.manage_accounts_outlined, 'Manajemen Pengguna', () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const UserManagementScreen()));
                          }),
                        ],

                        _buildGlassMenu(Icons.settings_outlined, 'Pengaturan', () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                        }),
                        
                        const SizedBox(height: 12),
                        _buildGlassMenu(Icons.logout, 'Keluar (Logout)', () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesi diakhiri')));
                        }, isDestructive: true),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}