import 'dart:ui';
import 'package:flutter/material.dart';

class ResultScreen extends StatelessWidget {
  final String detectedUndertone;
  final String? imagePath;

  const ResultScreen({super.key, required this.detectedUndertone, this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF333333)),
      ),
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
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hasil Analisis', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF333333))),
                  const SizedBox(height: 24),
                  
                  // Glass Panel Hasil
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                        ),
                        child: Column(
                          children: [
                            const Text('Undertone Anda', style: TextStyle(fontSize: 16, color: Color(0xFF555555))),
                            const SizedBox(height: 8),
                            Text(
                              detectedUndertone.toUpperCase(),
                              // Perbaikan error FontWeight.black menjadi FontWeight.w900 ada di baris bawah ini:
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFFE91E63), letterSpacing: 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  const Text('Rekomendasi Makeup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                  const SizedBox(height: 16),
                  
                  // Dummy Rekomendasi (Sebelum disambung ke MySQL)
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 0),
                      itemCount: 3,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              leading: const CircleAvatar(backgroundColor: Color(0xFFB5654A), radius: 20),
                              title: const Text('Velvet Matte - Terracotta', style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: const Text('Rp 89.000'),
                              trailing: IconButton(
                                icon: const Icon(Icons.face_retouching_natural, color: Color(0xFFE91E63)),
                                onPressed: () {},
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
          ),
        ],
      ),
    );
  }
}