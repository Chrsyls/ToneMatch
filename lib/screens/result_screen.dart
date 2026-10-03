import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ResultScreen extends StatefulWidget {
  final String detectedUndertone;
  final String? imagePath;

  const ResultScreen({super.key, required this.detectedUndertone, this.imagePath});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  List<dynamic> _recommendations = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // IP Address Laptop Anda
  final String baseUrl = 'http://192.168.11.166:8000';

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
  }

  Future<void> _fetchRecommendations() async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/recommendations/${widget.detectedUndertone}');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData['success'] == true) {
          setState(() {
            _recommendations = decodedData['data'];
            _isLoading = false;
          });
        } else {
          throw Exception(decodedData['error']);
        }
      } else {
        throw Exception('Gagal memuat rekomendasi.');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // CRUD: Fungsi Menyimpan Produk Favorit (Create)
  Future<void> _saveToFavorites(String productId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/favorites'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"user_id": "usr_dummy_01", "product_id": productId}),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produk berhasil disimpan ke Favorit! ✨'))
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'))
        );
      }
    }
  }

  String _formatRupiah(dynamic price) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    double parsedPrice = double.tryParse(price.toString()) ?? 0.0;
    return currencyFormatter.format(parsedPrice);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF4A2333)),
      ),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hasil Analisis', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF4A2333))),
                  const SizedBox(height: 24),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                        ),
                        child: Column(
                          children: [
                            const Text('Undertone Anda', style: TextStyle(fontSize: 18, color: Color(0xFF7A5C61))),
                            const SizedBox(height: 8),
                            Text(
                              widget.detectedUndertone.toUpperCase(),
                              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Color(0xFFE91E63), letterSpacing: 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Rekomendasi Makeup', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                        : _errorMessage != null
                            ? Center(child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)))
                            : _recommendations.isEmpty
                                ? const Center(child: Text('Belum ada rekomendasi produk untuk undertone ini.', style: TextStyle(color: Color(0xFF7A5C61))))
                                : ListView.builder(
                                    padding: const EdgeInsets.only(top: 0),
                                    itemCount: _recommendations.length,
                                    itemBuilder: (context, index) {
                                      final item = _recommendations[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12.0),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.7),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                                          ),
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: const Color(0xFFE91E63).withOpacity(0.2),
                                              child: const Icon(Icons.brush, color: Color(0xFFE91E63), size: 20),
                                            ),
                                            title: Text(item['product_name'] ?? 'Nama Produk', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4A2333))),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 4),
                                                Text(item['brand_name'] ?? 'Brand', style: const TextStyle(fontSize: 14, color: Color(0xFF7A5C61))),
                                                const SizedBox(height: 4),
                                                Text(_formatRupiah(item['price']), style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFE91E63))),
                                              ],
                                            ),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.favorite_border, color: Color(0xFFE91E63)),
                                              onPressed: () => _saveToFavorites(item['product_id']),
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