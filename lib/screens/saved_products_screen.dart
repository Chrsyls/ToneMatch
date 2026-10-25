import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final String baseUrl = 'http://10.4.89.111:8000';

  // State untuk Fitur 4: Mode Komparasi Produk
  bool _isCompareMode = false;
  final List<Map<String, dynamic>> _selectedForCompare = [];

  @override
  void initState() {
    super.initState();
    _fetchFavorites();
  }

  Future<void> _fetchFavorites() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
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
        setState(() {
          _favorites.removeWhere((item) => item['favorite_id'] == favoriteId);
          _selectedForCompare.removeWhere((item) => item['favorite_id'] == favoriteId);
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk dihapus dari favorit')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _formatRupiah(dynamic price) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    double parsedPrice = double.tryParse(price.toString()) ?? 0.0;
    return currencyFormatter.format(parsedPrice);
  }

  // Fungsi Pilih Produk untuk Komparasi
  void _toggleSelectForCompare(Map<String, dynamic> item) {
    setState(() {
      final exists = _selectedForCompare.any((e) => e['favorite_id'] == item['favorite_id']);
      if (exists) {
        _selectedForCompare.removeWhere((e) => e['favorite_id'] == item['favorite_id']);
      } else {
        if (_selectedForCompare.length < 2) {
          _selectedForCompare.add(item);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maksimal pilih 2 produk untuk dibandingkan!')),
          );
        }
      }
    });
  }

  Future<void> _launchShopee(String productName, String brand) async {
    final query = Uri.encodeComponent('$brand $productName');
    final uri = Uri.parse('https://shopee.co.id/search?keyword=$query');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // FITUR 4: MODAL POP-UP KOMPARASI 2 PRODUK SIDE-BY-SIDE
  void _showComparisonModal() {
    if (_selectedForCompare.length < 2) return;

    final prod1 = _selectedForCompare[0];
    final prod2 = _selectedForCompare[1];

    final double price1 = double.tryParse(prod1['price'].toString()) ?? 0;
    final double price2 = double.tryParse(prod2['price'].toString()) ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Komparasi Kosmetik',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF4A2333)),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildCompareColumn(prod1, isCheaper: price1 < price2)),
                  Container(
                    width: 1,
                    height: 280,
                    color: Colors.grey.shade300,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  Expanded(child: _buildCompareColumn(prod2, isCheaper: price2 < price1)),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A2333),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup Perbandingan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompareColumn(Map<String, dynamic> item, {required bool isCheaper}) {
    final imageUrl = item['image_url'];
    final productName = item['product_name'] ?? '-';
    final brand = item['brand_name'] ?? '-';

    return Column(
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: imageUrl != null && imageUrl.toString().isNotEmpty
                  ? Image.network(imageUrl, width: 90, height: 90, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 60))
                  : Container(
                      width: 90, height: 90,
                      color: const Color(0xFFFCE4EC),
                      child: const Icon(Icons.brush, color: Color(0xFFE91E63), size: 40),
                    ),
            ),
            if (isCheaper)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('🔥 Hemat', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          brand.toString().toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE91E63)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 40,
          child: Text(
            productName,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4A2333)),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          decoration: BoxDecoration(
            color: isCheaper ? Colors.green.shade50 : const Color(0xFFFCE4EC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _formatRupiah(item['price']),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: isCheaper ? Colors.green.shade800 : const Color(0xFFE91E63),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFEE4D2D),
            side: const BorderSide(color: Color(0xFFEE4D2D)),
            minimumSize: const Size(double.infinity, 36),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => _launchShopee(productName, brand),
          icon: const Icon(Icons.shopping_bag_outlined, size: 15),
          label: const Text('Cek Shopee', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Produk Tersimpan', style: TextStyle(color: Color(0xFF4A2333), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF4A2333)),
        actions: [
          if (_favorites.length >= 2)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _isCompareMode = !_isCompareMode;
                  _selectedForCompare.clear();
                });
              },
              icon: Icon(
                _isCompareMode ? Icons.close : Icons.compare_arrows_rounded,
                color: const Color(0xFFE91E63),
              ),
              label: Text(
                _isCompareMode ? 'Batal' : 'Bandingkan',
                style: const TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isCompareMode && _selectedForCompare.isNotEmpty
          ? FloatingActionButton.extended(
              backgroundColor: _selectedForCompare.length == 2 ? const Color(0xFFE91E63) : Colors.grey,
              onPressed: _selectedForCompare.length == 2 ? _showComparisonModal : null,
              icon: const Icon(Icons.balance, color: Colors.white),
              label: Text(
                'Bandingkan Sekarang (${_selectedForCompare.length}/2)',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: Stack(
        children: [
          const DynamicBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  if (_isCompareMode)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE91E63).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE91E63)),
                      ),
                      child: const Text(
                        '💡 Pilih 2 produk kosmetik di bawah ini untuk membandingkan harga dan spesifikasinya.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A2333)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Expanded(
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
                                      final imageUrl = item['image_url'];
                                      final isSelected = _selectedForCompare.any((e) => e['favorite_id'] == item['favorite_id']);

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12.0),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(16),
                                          onTap: _isCompareMode ? () => _toggleSelectForCompare(item) : null,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: isSelected ? const Color(0xFFFCE4EC) : Colors.white.withOpacity(0.6),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: isSelected ? const Color(0xFFE91E63) : Colors.white.withOpacity(0.5),
                                                width: isSelected ? 2 : 1,
                                              ),
                                            ),
                                            child: ListTile(
                                              leading: ClipRRect(
                                                borderRadius: BorderRadius.circular(10),
                                                child: imageUrl != null && imageUrl.toString().isNotEmpty
                                                    ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image))
                                                    : Container(
                                                        width: 50, height: 50,
                                                        decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(10)),
                                                        child: const Icon(Icons.bookmark, color: Color(0xFFE91E63)),
                                                      ),
                                              ),
                                              title: Text(item['product_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                                              subtitle: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(item['brand_name'] ?? '', style: const TextStyle(color: Color(0xFF7A5C61))),
                                                  Text(_formatRupiah(item['price']), style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFE91E63))),
                                                ],
                                              ),
                                              trailing: _isCompareMode
                                                  ? Checkbox(
                                                      value: isSelected,
                                                      activeColor: const Color(0xFFE91E63),
                                                      onChanged: (_) => _toggleSelectForCompare(item),
                                                    )
                                                  : IconButton(
                                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                                      onPressed: () => _removeFavorite(item['favorite_id']),
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
          ),
        ],
      ),
    );
  }
}