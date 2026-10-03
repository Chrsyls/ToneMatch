import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'result_screen.dart';

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
                const Text('🛠️ Developer Debug Menu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.auto_awesome, color: Color(0xFFE91E63)),
                  title: const Text('Buka Halaman Result', style: TextStyle(color: Color(0xFF4A2333))),
                  subtitle: const Text('Melihat UI hasil dengan data simulasi', style: TextStyle(color: Color(0xFF7A5C61))),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF7A5C61)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ResultScreen(
                          detectedUndertone: 'warm', 
                          imagePath: null,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.login, color: Colors.blue),
                  title: const Text('Buka Halaman Login', style: TextStyle(color: Color(0xFF4A2333))),
                  subtitle: const Text('Belum dibuat (Placeholder)', style: TextStyle(color: Color(0xFF7A5C61))),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF7A5C61)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DummyScreen(title: 'Login Screen')),
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
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFFE91E63),
          unselectedItemColor: const Color(0xFFD1B3BA), // Soft muted pink
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
          style: const TextStyle(fontSize: 18, color: Color(0xFF7A5C61)),
        ),
      ),
    );
  }
}