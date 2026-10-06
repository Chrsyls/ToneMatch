import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/dynamic_background.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  bool _isLoading = true;
  int _totalUsers = 0;
  int _totalHistory = 0;
  int _totalProducts = 0;
  final String baseUrl = 'http://10.4.89.111:8000';

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/v1/admin/stats'));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          setState(() {
            _totalUsers = decoded['data']['total_users'] ?? 0;
            _totalHistory = decoded['data']['total_history'] ?? 0;
            _totalProducts = decoded['data']['total_products'] ?? 0;
          });
        }
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildCategoryChartCard(String title, int value, int totalSum, Color color, IconData icon) {
    double percentage = totalSum > 0 ? (value / totalSum) : 0.0;
    String percentText = '${(percentage * 100).toStringAsFixed(1)}%';

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // Diperbaiki ke spaceBetween
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                        child: Icon(icon, color: color, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Text(title, style: const TextStyle(color: Color(0xFF4A2333), fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text(value.toString(), style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 16),
              
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Colors.white.withOpacity(0.6),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 12,
                ),
              ),
              const SizedBox(height: 10),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // Diperbaiki ke spaceBetween
                children: [
                  const Text('Kontribusi terhadap sistem', style: TextStyle(color: Color(0xFF7A5C61), fontSize: 12, fontWeight: FontWeight.w500)),
                  Text(percentText, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalSum = _totalUsers + _totalHistory + _totalProducts;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Dashboard Super Admin', style: TextStyle(color: Color(0xFF4A2333), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF4A2333)),
      ),
      body: Stack(
        children: [
          const DynamicBackground(),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Grafik Analitik Sistem', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF4A2333))),
                        const SizedBox(height: 8),
                        const Text('Statistik visual terperinci untuk setiap kategori data.', style: TextStyle(color: Color(0xFF7A5C61), fontSize: 14)),
                        const SizedBox(height: 20),
                        
                        _buildCategoryChartCard('Pengguna Aktif', _totalUsers, totalSum, const Color(0xFFE91E63), Icons.people_alt_rounded),
                        const SizedBox(height: 16),
                        
                        _buildCategoryChartCard('Riwayat Analisis', _totalHistory, totalSum, const Color(0xFF9C27B0), Icons.analytics_rounded),
                        const SizedBox(height: 16),
                        
                        _buildCategoryChartCard('Katalog Produk', _totalProducts, totalSum, const Color(0xFF3F51B5), Icons.shopping_bag_rounded),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}