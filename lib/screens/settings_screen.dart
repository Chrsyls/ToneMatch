import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/dynamic_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Pengaturan', style: TextStyle(color: Color(0xFF4A2333), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF4A2333)),
      ),
      body: Stack(
        children: [
          const DynamicBackground(), // Background Dinamis Aktif!
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ListView(
                children: [
                  const Text('Preferensi Aplikasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF7A5C61))),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.6)),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text('Notifikasi Analisis', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                              subtitle: const Text('Terima pemberitahuan tips kecantikan', style: TextStyle(color: Color(0xFF7A5C61))),
                              value: _notificationsEnabled,
                              activeColor: const Color(0xFFE91E63),
                              onChanged: (val) => setState(() => _notificationsEnabled = val),
                            ),
                            const Divider(height: 1, color: Colors.white30),
                            SwitchListTile(
                              title: const Text('Mode Gelap (Simulasi)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                              subtitle: const Text('Sesuaikan tema antarmuka', style: TextStyle(color: Color(0xFF7A5C61))),
                              value: _darkMode,
                              activeColor: const Color(0xFFE91E63),
                              onChanged: (val) => setState(() => _darkMode = val),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Tentang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF7A5C61))),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.6)),
                        ),
                        child: const ListTile(
                          title: Text('Versi Aplikasi', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                          trailing: Text('1.0.0 (MVP)', style: TextStyle(color: Color(0xFF7A5C61), fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}