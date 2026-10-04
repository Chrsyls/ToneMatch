import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/dynamic_background.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  final String baseUrl = 'http://192.168.11.166:8000';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/v1/admin/users'));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          setState(() => _users = decoded['data'] ?? []);
        }
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeRole(String uid, String currentRole) async {
    String? selectedRole = currentRole;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ubah Peran Pengguna'),
          content: DropdownButtonFormField<String>(
            value: selectedRole,
            items: const [
              DropdownMenuItem(value: 'user', child: Text('User')),
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
              DropdownMenuItem(value: 'super_admin', child: Text('Super Admin')),
            ],
            onChanged: (val) => selectedRole = val,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _updateUserRoleAPI(uid, selectedRole!);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateUserRoleAPI(String uid, String newRole) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/v1/admin/users/$uid/role'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"role": newRole}),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Role berhasil diperbarui')));
        _fetchUsers();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteUser(String uid) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/api/v1/admin/users/$uid'));
      if (response.statusCode == 200) {
        setState(() => _users.removeWhere((u) => u['uid'] == uid));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengguna berhasil dihapus')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Kelola Pengguna', style: TextStyle(color: Color(0xFF4A2333), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF4A2333)),
      ),
      body: Stack(
        children: [
          const DynamicBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                  : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final u = _users[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.6)),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFFE91E63).withOpacity(0.2),
                                    child: const Icon(Icons.person, color: Color(0xFFE91E63)),
                                  ),
                                  title: Text(u['name'] ?? 'Tanpa Nama', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                                  subtitle: Text('${u['email']}\nRole: ${u['role'].toString().toUpperCase()}', style: const TextStyle(color: Color(0xFF7A5C61), fontSize: 13)),
                                  isThreeLine: true,
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (val) {
                                      if (val == 'role') _changeRole(u['uid'], u['role']);
                                      if (val == 'delete') _deleteUser(u['uid']);
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'role', child: Text('Ubah Peran')),
                                      const PopupMenuItem(value: 'delete', child: Text('Hapus Akun', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}