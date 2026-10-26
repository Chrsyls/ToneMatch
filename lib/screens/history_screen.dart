import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/dynamic_background.dart';
import 'result_screen.dart';
import 'profile_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _historyData = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _currentUid = 'usr_dummy_01';
  String _currentRole = 'user';
  final String baseUrl = 'http://10.4.89.111:8000';

  @override
  void initState() {
    super.initState();
    _initAndFetchHistory();
  }

  Future<void> _initAndFetchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUid = prefs.getString('user_uid') ?? 'usr_dummy_01';
    _currentRole = prefs.getString('user_role') ?? 'user';
    await _fetchHistoryFromMySQL();
  }

  Future<void> _fetchHistoryFromMySQL() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse('$baseUrl/api/v1/history/$_currentUid');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData['success'] == true) {
          if (mounted) setState(() => _historyData = decodedData['data'] ?? []);
        } else {
          if (mounted) setState(() => _errorMessage = decodedData['error'] ?? 'Gagal memuat data');
        }
      } else {
        if (mounted) setState(() => _errorMessage = 'Gagal terhubung ke server.');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Pastikan server backend Python aktif.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteHistory(String historyId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/api/v1/history/$historyId'));
      if (response.statusCode == 200) {
        setState(() => _historyData.removeWhere((item) => item['history_id'] == historyId));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Riwayat berhasil dihapus')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
    }
  }

  // MENU DEBUG GANTI ROLE INSTAN (MEMPERBAIKI BUG TOMBOL KUMBANG 🐞 DI SCREENSHOT)
  void _showDebugRoleSwitcher() {
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
                  Text('Debug Menu: Ganti Role Akun', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF4A2333))),
                ],
              ),
              const SizedBox(height: 8),
              Text('UID Aktif: $_currentUid • Role Saat Ini: ${_currentRole.toUpperCase()}', style: const TextStyle(fontSize: 12, color: Color(0xFF7A5C61))),
              const SizedBox(height: 16),
              _buildRoleOptionTile('user', 'User Biasa', 'Hanya akses analisis, riwayat, dan produk favorit', Icons.person_outline),
              _buildRoleOptionTile('admin', 'Admin Produk', 'Bisa menambah, edit, & scrape katalog produk', Icons.admin_panel_settings_outlined),
              _buildRoleOptionTile('super_admin', 'Super Admin', 'Akses penuh seluruh fitur + kelola & hapus akun user', Icons.security_rounded),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoleOptionTile(String roleValue, String title, String subtitle, IconData icon) {
    final bool isCurrent = _currentRole == roleValue;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isCurrent ? const Color(0xFFFCE4EC) : Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isCurrent ? const Color(0xFFE91E63) : Colors.grey.shade300, width: isCurrent ? 1.5 : 1),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFE91E63)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: isCurrent ? const Icon(Icons.check_circle, color: Color(0xFFE91E63)) : null,
        onTap: () async {
          Navigator.pop(context);
          try {
            final res = await http.put(
              Uri.parse('$baseUrl/api/v1/admin/users/$_currentUid/role'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'role': roleValue}),
            );
            if (res.statusCode == 200) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('user_role', roleValue);
              ProfileScreenState.resetCache();
              setState(() => _currentRole = roleValue);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Role berhasil diubah ke ${roleValue.toUpperCase()}! Cek tab Profil.'), backgroundColor: Colors.green),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal ganti role: $e'), backgroundColor: Colors.red));
            }
          }
        },
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      DateTime date = DateTime.parse(isoString);
      return "${date.day}-${date.month}-${date.year}";
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: const Color(0xFF4A2333),
        tooltip: 'Debug Ganti Role',
        onPressed: _showDebugRoleSwitcher,
        child: const Icon(Icons.bug_report, color: Colors.white),
      ),
      body: Stack(
        children: [
          const DynamicBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('Riwayat Analisis', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF4A2333))),
                ),
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                    : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7A5C61), fontWeight: FontWeight.bold)),
                          ),
                        )
                      : _historyData.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), shape: BoxShape.circle),
                                  child: const Icon(Icons.history_rounded, size: 70, color: Color(0xFFE91E63)),
                                ),
                                const SizedBox(height: 24),
                                const Text('Belum Ada Riwayat', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                                const SizedBox(height: 8),
                                const Text('Yuk, coba ambil foto dan temukan\nundertone wajahmu sekarang!', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF7A5C61), fontSize: 15, height: 1.5)),
                                const SizedBox(height: 80),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: _historyData.length,
                            itemBuilder: (context, index) {
                              final item = _historyData[index];
                              final historyId = item['history_id'];
                              final rawUndertone = item['detected_undertone'].toString();
                              final undertoneDisplay = rawUndertone.toUpperCase();
                              final date = _formatDate(item['created_at']);
                              final imageUrl = item['image_url'] != null ? '$baseUrl/${item['image_url']}' : null;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ResultScreen(
                                          detectedUndertone: rawUndertone.toLowerCase(),
                                          imagePath: item['image_url'],
                                        ),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.4),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 60, height: 60,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.6),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: imageUrl != null 
                                                  ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image))
                                                  : const Icon(Icons.image_outlined, color: Color(0xFFE91E63)),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Undertone: $undertoneDisplay', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4A2333))),
                                                  const SizedBox(height: 6),
                                                  Text(date, style: const TextStyle(color: Color(0xFF7A5C61), fontSize: 14)),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                              onPressed: () => _deleteHistory(historyId),
                                            ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}