import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/dynamic_background.dart';

class ResultScreen extends StatefulWidget {
  final String detectedUndertone;
  final String? imagePath;

  const ResultScreen({
    super.key,
    required this.detectedUndertone,
    this.imagePath,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  List<dynamic> _recommendations = [];
  bool _isLoading = true;
  final String baseUrl = 'http://192.168.100.68:8000'; // IP Baru Anda

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
  }

  Future<void> _fetchRecommendations() async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse('$baseUrl/api/v1/products?undertone=${widget.detectedUndertone}');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _recommendations = data['data'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal memuat rekomendasi: $e");
    } finally {
      // PENYELESAIAN BUG: Pastikan loading selalu dimatikan walau gagal/kosong
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleSaveProduct(String productId, bool isCurrentlySaved) async {
    try {
      final endpoint = _getFavoritesEndpoint(isCurrentlySaved, productId);
      final response = await endpoint;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isCurrentlySaved ? 'Produk dihapus dari tersimpan' : 'Produk berhasil disimpan! ❤️')),
        );
        _fetchRecommendations(); // Refresh status ikon hati
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengubah status simpan')));
    }
  }

  Future<http.Response> _getFavoritesEndpoint(bool isSaved, String id) {
    if (isSaved) {
      return http.delete(Uri.parse('$baseUrl/api/v1/favorites/usr_dummy_01/$id'));
    } else {
      return http.post(
        Uri.parse('$baseUrl/api/v1/favorites'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"user_id": "usr_dummy_01", "product_id": id}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String undertoneTitle = widget.detectedUndertone.toUpperCase();

    return Scaffold(
      body: Stack(
        children: [
          const DynamicBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF4A2333)),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text('Hasil Analisis', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF4A2333))),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      // Card Profil Undertone
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.auto_awesome, size: 40, color: Color(0xFFE91E63)),
                                const SizedBox(height: 12),
                                const Text('Undertone Anda Terdeteksi:', style: TextStyle(color: Color(0xFF7A5C61), fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(undertoneTitle, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF4A2333))),
                                const SizedBox(height: 12),
                                Text(
                                  'Kulit Anda memiliki rona $undertoneTitle. Warna makeup yang paling cocok adalah yang memiliki basis warna seirama.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Color(0xFF7A5C61), fontSize: 13, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Rekomendasi Produk Makeup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                      const SizedBox(height: 16),
                      
                      // Area Rekomendasi
                      _isLoading
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(child: CircularProgressIndicator(color: Color(0xFFE91E63))),
                            )
                          : _recommendations.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Text('Belum ada rekomendasi produk untuk undertone ini.', style: TextStyle(color: Color(0xFF7A5C61))),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _recommendations.length,
                                  itemBuilder: (context, index) {
                                    final prod = _recommendations[index];
                                    final isSaved = prod['is_saved'] ?? false;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.white, width: 1),
                                      ),
                                      child: ListTile(
                                        leading: Container(
                                          width: 50, height: 50,
                                          decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(12)),
                                          child: const Icon(Icons.brush, color: Color(0xFFE91E63)),
                                        ),
                                        title: Text(prod['product_name'] ?? 'Makeup Item', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                                        subtitle: Text('${prod['brand']} • Rp ${prod['price'] ?? '0'}', style: const TextStyle(color: Color(0xFF7A5C61), fontSize: 13)),
                                        trailing: IconButton(
                                          icon: Icon(isSaved ? Icons.favorite : Icons.favorite_border, color: const Color(0xFFE91E63)),
                                          onPressed: () => _toggleSaveProduct(prod['product_id'].toString(), isSaved),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                      const SizedBox(height: 40),
                    ],
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