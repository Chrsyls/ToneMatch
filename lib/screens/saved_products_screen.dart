import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../widgets/dynamic_background.dart';

class SavedProductsScreen extends StatefulWidget {
  const SavedProductsScreen({super.key});

  @override
  State<SavedProductsScreen> createState() => _SavedProductsScreenState();
}

class _SavedProductsScreenState extends State<SavedProductsScreen> {
  List<dynamic> _favorites = [];
  bool _isLoading = true;
  String? _errorMessage;
  final String baseUrl = 'http://192.168.11.166:8000';

  @override
  void initState() {
    super.initState();
    _fetchFavorites();
  }

  Future<void> _fetchFavorites() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/v1/favorites/usr_dummy_01')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          if (mounted) setState(() => _favorites = decoded['data'] ?? []);
        } else {
          if (mounted) setState(() => _errorMessage = decoded['error'] ?? 'Gagal memuat produk favorit');
        }
      } else {
        if (mounted) setState(() => _errorMessage = 'Server merespons dengan status: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Tidak dapat memuat data favorit.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFavorite(String favoriteId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/api/v1/favorites/$favoriteId'));
      if (response.statusCode == 200) {
        setState(() => _favorites.removeWhere((item) => item['favorite_id'] == favoriteId));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk dihapus dari favorit')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        title: const Text('Produk Tersimpan', style: TextStyle(color: Color(0xFF4A2333), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF4A2333)),
      ),
      body: Stack(
        children: [
          const DynamicBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                  : _errorMessage != null
                      ? Center(child: Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7A5C61), fontWeight: FontWeight.bold)))
                      : _favorites.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), shape: BoxShape.circle),
                                    child: const Icon(Icons.bookmark_border_rounded, size: 70, color: Color(0xFFE91E63)),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text('Belum Ada Produk', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                                  const SizedBox(height: 8),
                                  const Text('Simpan rekomendasi makeup favoritmu\nagar mudah dilihat kembali nanti!', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF7A5C61), fontSize: 15, height: 1.5)),
                                  const SizedBox(height: 60),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _favorites.length,
                              itemBuilder: (context, index) {
                                final item = _favorites[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withOpacity(0.5)),
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: const Color(0xFFE91E63).withOpacity(0.2),
                                        child: const Icon(Icons.bookmark, color: Color(0xFFE91E63)),
                                      ),
                                      title: Text(item['product_name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item['brand_name'], style: const TextStyle(color: Color(0xFF7A5C61))),
                                          Text(_formatRupiah(item['price']), style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFE91E63))),
                                        ],
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                        onPressed: () => _removeFavorite(item['favorite_id']),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}