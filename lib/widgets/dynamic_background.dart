import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class DynamicBackground extends StatefulWidget {
  const DynamicBackground({super.key});

  @override
  State<DynamicBackground> createState() => _DynamicBackgroundState();
}

class _DynamicBackgroundState extends State<DynamicBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            // 1. Warna Dasar Gradasi Indah
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

            // 2. Orb Dinamis 1 (Kiri Atas)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.1 + (math.sin(_controller.value * 2 * math.pi) * 50),
              left: MediaQuery.of(context).size.width * 0.05 + (math.cos(_controller.value * 2 * math.pi) * 50),
              child: _buildBlob(const Color(0xFFff758c).withOpacity(0.4), 320),
            ),
            
            // 3. Orb Dinamis 2 (Kanan Bawah)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.05 + (math.cos(_controller.value * 2 * math.pi) * 50),
              right: MediaQuery.of(context).size.width * 0.05 + (math.sin(_controller.value * 2 * math.pi) * 50),
              child: _buildBlob(const Color(0xFFff7eb3).withOpacity(0.5), 360),
            ),

            // 4. Filter Kaca Blur Ekstrem untuk Efek Cairan/Ambient Halus
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: Container(color: Colors.transparent),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}