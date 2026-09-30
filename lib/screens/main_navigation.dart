import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'result_screen.dart'; // Import halaman Result

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const HistoryScreen(),
    const ProfileScreen(),
  ];

  // ==========================================
  // FUNGSI UNTUK MENAMPILKAN MENU DEBUG (PINTASAN)
  // ==========================================
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
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🛠️ Developer Debug Menu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                const SizedBox(height: 16),
                
                // Pintasan ke Result Screen
                ListTile(
                  leading: const Icon(Icons.auto_awesome, color: Color(0xFFE91E63)),
                  title: const Text('Buka Halaman Result'),
                  subtitle: const Text('Melihat UI hasil dengan data simulasi'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context); // Tutup menu
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ResultScreen(
                          detectedUndertone: 'neutral', // Data dummy
                          imagePath: null,
                        ),
                      ),
                    );
                  },
                ),

                // Pintasan ke Login (Placeholder)
                ListTile(
                  leading: const Icon(Icons.login, color: Colors.blue),
                  title: const Text('Buka Halaman Login'),
                  subtitle: const Text('Belum dibuat (Placeholder)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DummyScreen(title: 'Login Screen')),
                    );
                  },
                ),

                // Pintasan ke Register (Placeholder)
                ListTile(
                  leading: const Icon(Icons.app_registration, color: Colors.green),
                  title: const Text('Buka Halaman Register'),
                  subtitle: const Text('Belum dibuat (Placeholder)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DummyScreen(title: 'Register Screen')),
                    );
                  },
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
      
      // ==========================================
      // TOMBOL DEBUG MELAYANG (Hanya untuk masa development)
      // ==========================================
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDebugMenu(context),
        backgroundColor: Colors.black87,
        mini: true, // Ukuran kecil agar tidak mengganggu UI desain
        elevation: 10,
        child: const Icon(Icons.bug_report, color: Colors.white, size: 20),
      ),

      // Bottom Navigation Bar (Tetap sama)
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFFE91E63),
          unselectedItemColor: Colors.grey.shade400,
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

// ==========================================
// KELAS TAMBAHAN UNTUK HALAMAN YANG BELUM DIBUAT
// ==========================================
class DummyScreen extends StatelessWidget {
  final String title;
  const DummyScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '$title\n(Akan kita bangun nanti)',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ),
    );
  }
}