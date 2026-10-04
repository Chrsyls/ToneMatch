import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/dynamic_background.dart';
import 'result_screen.dart'; // Import halaman result

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _historyData = [];
  bool _isLoading = true;
  String? _errorMessage;
  final String baseUrl = 'http://192.168.11.166:8000'; // Sesuaikan IP Anda

  @override
  void initState() {
    super.initState();
    _fetchHistoryFromMySQL();
  }

  Future<void> _fetchHistoryFromMySQL() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse('$baseUrl/api/v1/history/usr_dummy_01');
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
    }
  }

  String _formatDate(String isoString) {
    DateTime date = DateTime.parse(isoString);
    return "${date.day}-${date.month}-${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                                  // Navigasi ke ResultScreen saat riwayat diklik
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ResultScreen(
                                          detectedUndertone: rawUndertone.toLowerCase(),
                                          imagePath: item['image_url'], // Kirim path gambar
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