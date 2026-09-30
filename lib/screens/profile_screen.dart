import 'dart:ui';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Widget _buildGlassMenu(IconData icon, String title, {bool isDestructive = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.5)),
            ),
            child: ListTile(
              leading: Icon(icon, color: isDestructive ? Colors.red : const Color(0xFFE91E63)),
              title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDestructive ? Colors.red : const Color(0xFF333333))),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {},
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
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFff9a9e), Color(0xFFfecfef), Color(0xFFfdfbfb)],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Avatar Profil
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      image: const DecorationImage(
                        image: NetworkImage('https://ui-avatars.com/api/?name=Alvito+Aryo&background=E91E63&color=fff'),
                      ),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFE91E63).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Alvito Aryo', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                  const Text('alvito@tonematch.app', style: TextStyle(color: Color(0xFF555555))),
                  const SizedBox(height: 40),
                  
                  // Menu (Preferensi Kulit dihapus)
                  _buildGlassMenu(Icons.favorite_border, 'Produk Tersimpan'),
                  _buildGlassMenu(Icons.settings_outlined, 'Pengaturan UI'),
                  const Spacer(),
                  _buildGlassMenu(Icons.logout, 'Keluar (Logout)', isDestructive: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}