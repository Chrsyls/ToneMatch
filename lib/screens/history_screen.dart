import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _historyData = [];
  bool _isLoading = true;
  String? _errorMessage;
  final String baseUrl = 'http://192.168.11.166:8000';

  @override
  void initState() {
    super.initState();
    _fetchHistoryFromMySQL();
  }

  Future<void> _fetchHistoryFromMySQL() async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/history/usr_dummy_01');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData['success'] == true) {
          setState(() {
            _historyData = decodedData['data'];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // CRUD: Fungsi Delete Riwayat
  Future<void> _deleteHistory(String historyId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/api/v1/history/$historyId'));
      if (response.statusCode == 200) {
        setState(() {
          _historyData.removeWhere((item) => item['history_id'] == historyId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Riwayat berhasil dihapus')));
        }
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
                    : _historyData.isEmpty
                      ? const Center(child: Text('Belum ada riwayat analisis wajah.', style: TextStyle(color: Color(0xFF7A5C61))))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: _historyData.length,
                          itemBuilder: (context, index) {
                            final item = _historyData[index];
                            final historyId = item['history_id'];
                            final undertone = item['detected_undertone'].toString().toUpperCase();
                            final score = (item['confidence_score'] * 100).toInt();
                            final date = _formatDate(item['created_at']);
                            final imageUrl = item['image_url'] != null ? '$baseUrl/${item['image_url']}' : null;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
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
                                              Text('Undertone: $undertone', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4A2333))),
                                              const SizedBox(height: 6),
                                              Text(date, style: const TextStyle(color: Color(0xFF7A5C61), fontSize: 14)),
                                            ],
                                          ),
                                        ),
                                        // Tombol Hapus (Delete CRUD)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                          onPressed: () => _deleteHistory(historyId),
                                        ),
                                      ],
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