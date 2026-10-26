import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/dynamic_background.dart';
import 'edit_profile_screen.dart';
import 'saved_products_screen.dart';
import 'admin_product_screen.dart';
import 'super_admin_dashboard_screen.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  static Map<String, dynamic>? _userData;
  static String? _localImagePath;
  static bool _isEditedLocally = false;

  bool _isLoading = true;
  String _currentUid = 'usr_dummy_01';
  final String baseUrl = 'http://10.4.89.111:8000';

  static void resetCache() {
    _userData = null;
    _localImagePath = null;
    _isEditedLocally = false;
  }

  @override
  void initState() {
    super.initState();
    loadUserProfile();
  }

  Future<void> loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUid = prefs.getString('user_uid') ?? 'usr_dummy_01';

    if (_isEditedLocally && _userData != null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/v1/users/$_currentUid'));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          if (mounted) {
            setState(() {
              _userData = decoded['data'];
              _isLoading = false;
            });
            await prefs.setString('user_role', _userData?['role'] ?? 'user');
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // TOMBOL MENU DEBUG GANTI ROLE INSTAN
  void _showDebugRoleModal() {
    final currentRole = _userData?['role'] ?? 'user';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.bug_report_rounded, color: Color(0xFFE91E63), size: 28),
                  SizedBox(width: 10),
                  Text('Debug Menu: Ganti Role Instan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF4A2333))),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Gunakan menu ini untuk menguji tampilan hak akses User, Admin, dan Super Admin secara langsung.', style: TextStyle(fontSize: 12, color: Color(0xFF7A5C61))),
              const SizedBox(height: 16),
              _buildDebugRoleItem('user', 'USER BIASA', currentRole),
              _buildDebugRoleItem('admin', 'ADMIN PRODUK', currentRole),
              _buildDebugRoleItem('super_admin', 'SUPER ADMIN', currentRole),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDebugRoleItem(String roleKey, String label, String activeRole) {
    final bool isSelected = activeRole == roleKey;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: isSelected ? const Color(0xFFFCE4EC) : null,
      leading: Icon(
        roleKey == 'super_admin' ? Icons.security : (roleKey == 'admin' ? Icons.admin_panel_settings : Icons.person),
        color: const Color(0xFFE91E63),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFFE91E63)) : const Icon(Icons.swap_horiz, color: Colors.grey),
      onTap: () async {
        Navigator.pop(context);
        try {
          final response = await http.put(
            Uri.parse('$baseUrl/api/v1/admin/users/$_currentUid/role'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'role': roleKey}),
          );
          if (response.statusCode == 200) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_role', roleKey);
            setState(() {
              if (_userData != null) _userData!['role'] = roleKey;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Role berhasil diganti menjadi ${roleKey.toUpperCase()}!'), backgroundColor: Colors.green),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengubah role: $e'), backgroundColor: Colors.red));
          }
        }
      },
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar Akun', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      resetCache();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _userData == null) {
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
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: const Color(0xFF4A2333),
        tooltip: 'Debug Ganti Role',
        onPressed: _showDebugRoleModal,
        child: const Icon(Icons.bug_report, color: Colors.white),
      ),
      body: Stack(
        children: [
          const DynamicBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Profil Saya', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF4A2333))),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _showDebugRoleModal,
                      icon: const Icon(Icons.bug_report_outlined, size: 18, color: Color(0xFFE91E63)),
                      label: const Text('Ganti Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

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
                              image: _localImagePath != null
                                  ? DecorationImage(image: FileImage(File(_localImagePath!)), fit: BoxFit.cover)
                                  : (_userData?['avatar_url'] != null
                                      ? DecorationImage(
                                          image: NetworkImage('$baseUrl/${_userData!['avatar_url']}'),
                                          fit: BoxFit.cover,
                                        )
                                      : null),
                              gradient: (_localImagePath == null && _userData?['avatar_url'] == null)
                                  ? const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFff9a9e)])
                                  : null,
                            ),
                            child: (_localImagePath == null && _userData?['avatar_url'] == null)
                                ? const Icon(Icons.person, size: 35, color: Colors.white)
                                : null,
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
                                InkWell(
                                  onTap: _showDebugRoleModal,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE91E63).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('Role: ${role.toUpperCase()} ⚙️', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE91E63))),
                                  ),
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

                _buildMenuTile(
                  icon: Icons.edit_outlined,
                  title: 'Edit Profil',
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                    );

                    if (result != null && result is Map<String, dynamic>) {
                      setState(() {
                        _isEditedLocally = true;
                        if (_userData == null) _userData = {};
                        _userData!['name'] = result['name'];
                        _userData!['email'] = result['email'];

                        if (result['isAvatarRemoved'] == true) {
                          _userData!['avatar_url'] = null;
                          _localImagePath = null;
                        } else {
                          if (result['serverAvatarUrl'] != null) {
                            _userData!['avatar_url'] = result['serverAvatarUrl'];
                          }
                          if (result['imagePath'] != null) {
                            _localImagePath = result['imagePath'];
                          }
                        }
                      });
                    }
                  },
                ),

                _buildMenuTile(
                  icon: Icons.favorite_outline,
                  title: 'Produk Tersimpan',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedProductsScreen()));
                  },
                ),

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
                  onPressed: _handleLogout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Keluar Akun', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 60),
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