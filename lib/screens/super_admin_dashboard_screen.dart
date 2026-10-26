import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/dynamic_background.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  Map<String, dynamic> _stats = {"total_users": 0, "total_history": 0, "total_products": 0};
  List<dynamic> _users = [];
  bool _isLoading = true;
  String _currentUid = '';
  final String baseUrl = 'http://10.4.89.111:8000';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUid = prefs.getString('user_uid') ?? 'usr_dummy_01';

      final statsRes = await http.get(Uri.parse('$baseUrl/api/v1/admin/stats'));
      final usersRes = await http.get(Uri.parse('$baseUrl/api/v1/admin/users'));

      if (statsRes.statusCode == 200) {
        final statsData = json.decode(statsRes.body);
        if (statsData['success'] == true) {
          _stats = statsData['data'];
        }
      }

      if (usersRes.statusCode == 200) {
        final usersData = json.decode(usersRes.body);
        if (usersData['success'] == true) {
          _users = usersData['data'] ?? [];
        }
      }
    } catch (e) {
      debugPrint('Error loading super admin data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUserRole(String targetUid, String newRole) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/v1/admin/users/$targetUid/role'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'role': newRole}),
      );
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Role berhasil diubah ke ${newRole.toUpperCase()}'), backgroundColor: Colors.green),
          );
        }
        _loadDashboardData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengubah role: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // FITUR HAPUS AKUN PENGGUNA OLEH SUPER ADMIN
  Future<void> _confirmDeleteUser(Map<String, dynamic> user) async {
    final targetUid = user['uid'].toString();
    final targetName = user['name'] ?? 'Pengguna';

    if (targetUid == _currentUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anda tidak dapat menghapus akun Super Admin yang sedang Anda gunakan!'), backgroundColor: Colors.orange),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Akun Pengguna?', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
        content: Text('Apakah Anda yakin ingin menghapus akun "$targetName" (${user['email']}) secara permanen beserta seluruh riwayat analisis dan favoritnya?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus Permanen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await http.delete(Uri.parse('$baseUrl/api/v1/admin/users/$targetUid'));
        final data = json.decode(res.body);
        if (res.statusCode == 200 && data['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data['message'] ?? 'Akun dihapus'), backgroundColor: Colors.green),
            );
          }
          _loadDashboardData();
        } else {
          throw Exception(data['error'] ?? 'Gagal menghapus akun');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Super Admin Dashboard', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4A2333))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4A2333)),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: Stack(
        children: [
          const DynamicBackground(),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                : ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      // Kartu Statistik Sistem
                      Row(
                        children: [
                          Expanded(child: _buildStatCard('Total User', _stats['total_users'].toString(), Icons.people_alt_rounded, Colors.pink)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildStatCard('Scan Wajah', _stats['total_history'].toString(), Icons.camera_front_rounded, Colors.purple)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildStatCard('Produk', _stats['total_products'].toString(), Icons.shopping_bag_rounded, Colors.orange)),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Kelola Akun Pengguna', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                          Text('${_users.length} Akun', style: const TextStyle(color: Color(0xFF7A5C61), fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Daftar Pengguna + Fitur Ganti Role & Hapus Akun
                      ..._users.map((u) {
                        final uid = u['uid'].toString();
                        final role = (u['role'] ?? 'user').toString();
                        final isMe = uid == _currentUid;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: isMe ? const Color(0xFFE91E63) : Colors.white, width: isMe ? 1.5 : 1),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFFFCE4EC),
                                child: Icon(
                                  role == 'super_admin' ? Icons.security : (role == 'admin' ? Icons.admin_panel_settings : Icons.person),
                                  color: const Color(0xFFE91E63),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            u['name'] ?? 'Tanpa Nama',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4A2333)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isMe)
                                          Container(
                                            margin: const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: const Color(0xFFE91E63), borderRadius: BorderRadius.circular(6)),
                                            child: const Text('Anda', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                      ],
                                    ),
                                    Text(u['email'] ?? '-', style: const TextStyle(fontSize: 12, color: Color(0xFF7A5C61))),
                                    const SizedBox(height: 6),
                                    DropdownButtonHideUnderline(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: DropdownButton<String>(
                                          value: ['user', 'admin', 'super_admin'].contains(role) ? role : 'user',
                                          isDense: true,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4A2333)),
                                          items: const [
                                            DropdownMenuItem(value: 'user', child: Text('Role: USER')),
                                            DropdownMenuItem(value: 'admin', child: Text('Role: ADMIN')),
                                            DropdownMenuItem(value: 'super_admin', child: Text('Role: SUPER ADMIN')),
                                          ],
                                          onChanged: (val) {
                                            if (val != null && val != role) {
                                              _updateUserRole(uid, val);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_forever_rounded, color: isMe ? Colors.grey : Colors.redAccent, size: 26),
                                tooltip: 'Hapus Akun Pengguna',
                                onPressed: () => _confirmDeleteUser(u),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(count, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF4A2333))),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF7A5C61), fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}