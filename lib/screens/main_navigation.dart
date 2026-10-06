import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'home_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final String baseUrl = 'http://10.4.89.111:8000'; // Sesuaikan IP Anda

  // GlobalKey untuk mengontrol state ProfileScreen dari luar
  final GlobalKey<ProfileScreenState> _profileKey = GlobalKey<ProfileScreenState>();

  late final List<Widget> _pages = [
    const HomeScreen(),
    const HistoryScreen(),
    ProfileScreen(key: _profileKey),
  ];

  Future<void> _switchRole(BuildContext context, String newRole) async {
    Navigator.pop(context); 
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/v1/admin/users/usr_dummy_01/role'),
        headers: {"Content-Type": "application/json"},
        body: '{"role": "$newRole"}',
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Berhasil pindah role ke: ${newRole.toUpperCase()} ✨')),
          );
          _profileKey.currentState?.loadUserProfile();
          setState(() {});
        }
      } else {
        throw Exception('Gagal mengubah role');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Pastikan backend Python & MySQL aktif (${e.toString()})')),
        );
      }
    }
  }

  void _showDebugMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🛠️ Developer Debug Menu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                const SizedBox(height: 16),
                const Text('Simulasi Pindah Role Akun:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF7A5C61))),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => _switchRole(context, 'user'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                      child: const Text('User'),
                    ),
                    ElevatedButton(
                      onPressed: () => _switchRole(context, 'admin'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3F51B5), foregroundColor: Colors.white),
                      child: const Text('Admin'),
                    ),
                    ElevatedButton(
                      onPressed: () => _switchRole(context, 'super_admin'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C27B0), foregroundColor: Colors.white),
                      child: const Text('Super Admin'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDebugMenu(context),
        backgroundColor: const Color(0xFF4A2333),
        mini: true, 
        elevation: 10,
        child: const Icon(Icons.bug_report, color: Colors.white, size: 20),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: const Color(0xFF4A2333).withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            if (index == 2) {
              _profileKey.currentState?.loadUserProfile();
            }
          },
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFFE91E63),
          unselectedItemColor: const Color(0xFFD1B3BA),
          showSelectedLabels: true,
          showUnselectedLabels: false,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.face_retouching_natural), label: 'Deteksi'),
            BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'Riwayat'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}