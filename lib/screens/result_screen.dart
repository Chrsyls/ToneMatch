import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
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
  List<dynamic> _filteredRecommendations = [];
  bool _isLoading = true;
  final String baseUrl = 'http://10.4.89.111:8000';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecommendations() async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse('$baseUrl/api/v1/recommendations/${widget.detectedUndertone}');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            final targetTone = widget.detectedUndertone.toLowerCase();
            _recommendations = (data['data'] ?? []).where((prod) {
              final prodTone = (prod['undertone'] ?? '').toString().toLowerCase();
              return prodTone == targetTone;
            }).toList();
            _filteredRecommendations = _recommendations;
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal memuat rekomendasi: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredRecommendations = _recommendations.where((prod) {
        final name = (prod['product_name'] ?? '').toLowerCase();
        final brand = (prod['brand'] ?? '').toLowerCase();
        return name.contains(query) || brand.contains(query);
      }).toList();
    });
  }

  Future<void> _toggleSaveProduct(String productId, bool isCurrentlySaved) async {
    try {
      final endpoint = _getFavoritesEndpoint(isCurrentlySaved, productId);
      final response = await endpoint;

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isCurrentlySaved ? 'Produk dihapus dari tersimpan' : 'Produk berhasil disimpan! ❤️')),
          );
        }
        _fetchRecommendations(); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengubah status simpan')));
      }
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

  String _formatRupiah(dynamic price) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    double parsedPrice = double.tryParse(price.toString()) ?? 0.0;
    return currencyFormatter.format(parsedPrice);
  }

  // FITUR 2: FUNGSI BUKA LINK MARKETPLACE (SHOPEE / TOKOPEDIA)
  Future<void> _launchMarketplace(String platform, String productName, String brand) async {
    final query = Uri.encodeComponent('$brand $productName');
    String url = '';
    if (platform == 'shopee') {
      url = 'https://shopee.co.id/search?keyword=$query';
    } else if (platform == 'tokopedia') {
      url = 'https://www.tokopedia.com/search?st=product&q=$query';
    }

    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak dapat membuka $platform: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // FITUR 5: KARTU SHARE HASIL ANALISIS KE MEDIA SOSIAL
  void _showShareCardDialog() {
    final undertoneTitle = widget.detectedUndertone.toUpperCase();
    final userPhotoUrl = widget.imagePath != null ? '$baseUrl/${widget.imagePath}' : null;
    final topProducts = _recommendations.take(2).map((e) => "• ${e['brand']} - ${e['product_name']}").join("\n");

    final shareText = "✨ *Hasil Analisis ToneMatch* ✨\n\n"
        "Undertone Kulitku: *$undertoneTitle*\n"
        "Karakter: Cocok dengan rona makeup yang hangat/seirama.\n\n"
        "💄 *Rekomendasi Produk Terbaik:*\n"
        "${topProducts.isNotEmpty ? topProducts : '- Belum ada produk'}\n\n"
        "Yuk cek undertone wajahmu di aplikasi *ToneMatch*!";

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Desain Kartu Estetik untuk Screenshot / Share
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF0F5), Color(0xFFFCE4EC), Color(0xFFF8BBD0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 8))],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.auto_awesome, color: Color(0xFFE91E63), size: 20),
                        SizedBox(width: 6),
                        Text('TONEMATCH BEAUTY CARD', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12, color: Color(0xFF4A2333))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (userPhotoUrl != null)
                      Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE91E63), width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                        ),
                        child: ClipOval(
                          child: Image.network(
                            userPhotoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Icon(Icons.person, size: 45, color: Color(0xFFE91E63)),
                          ),
                        ),
                      )
                    else
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: Color(0xFFE91E63),
                        child: Icon(Icons.face_retouching_natural, size: 45, color: Colors.white),
                      ),
                    const SizedBox(height: 14),
                    const Text('My Skin Undertone is', style: TextStyle(color: Color(0xFF7A5C61), fontSize: 13)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE91E63),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(undertoneTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2)),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Top Makeup Matches:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4A2333))),
                          const SizedBox(height: 6),
                          if (_recommendations.isEmpty)
                            const Text('Belum ada produk spesifik', style: TextStyle(fontSize: 12, color: Colors.grey))
                          else
                            ..._recommendations.take(2).map((p) => Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, size: 14, color: Color(0xFFE91E63)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${p['brand']} - ${p['product_name']}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A2333)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('📸 Screenshot kartu ini untuk IG Story!', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF7A5C61))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Tombol Aksi Share
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF4A2333),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: shareText));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Teks hasil analisis berhasil disalin! Siap ditempel ke medsos 📋'), backgroundColor: Colors.green),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Salin Teks', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366), // Warna WhatsApp
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        final waUrl = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(shareText)}');
                        await launchUrl(waUrl, mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // MODAL DETAIL PRODUK + TOMBOL MARKETPLACE (FITUR 2)
  void _showProductDetail(Map<String, dynamic> prod) {
    final imageUrl = prod['image_url'];
    final productName = prod['product_name'] ?? 'Makeup Item';
    final brand = prod['brand'] ?? 'Brand Kosmetik';
    final price = _formatRupiah(prod['price'] ?? 0);
    final undertone = (prod['undertone'] ?? widget.detectedUndertone).toUpperCase();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: imageUrl != null && imageUrl.toString().isNotEmpty
                      ? Image.network(imageUrl, width: 120, height: 120, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.image, size: 80, color: Colors.grey))
                      : Container(width: 120, height: 120, color: Colors.pink.shade50, child: const Icon(Icons.brush, size: 50, color: Color(0xFFE91E63))),
                ),
              ),
              const SizedBox(height: 20),
              Text(brand, style: const TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(productName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF4A2333))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(8)),
                    child: Text('Undertone: $undertone', style: const TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Deskripsi & Kesesuaian:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
              const SizedBox(height: 6),
              Text(
                'Produk ini dirancang khusus untuk menyatu sempurna dengan rona kulit berkarakter $undertone. Memberikan hasil akhir yang natural, tahan lama, dan merata.',
                style: const TextStyle(color: Color(0xFF7A5C61), height: 1.4),
              ),
              const SizedBox(height: 20),
              const Text('Beli Produk di Marketplace:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4A2333))),
              const SizedBox(height: 10),
              // Tombol Deep Link Shopee & Tokopedia
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEE4D2D), // Warna Shopee
                        side: const BorderSide(color: Color(0xFFEE4D2D), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _launchMarketplace('shopee', productName, brand),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                      label: const Text('Shopee', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF03AC0E), // Warna Tokopedia
                        side: const BorderSide(color: Color(0xFF03AC0E), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _launchMarketplace('tokopedia', productName, brand),
                      icon: const Icon(Icons.storefront_outlined, size: 18),
                      label: const Text('Tokopedia', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _toggleSaveProduct(prod['product_id'].toString(), prod['is_saved'] ?? false);
                },
                child: const Text('Simpan ke Favorit ❤️', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String undertoneTitle = widget.detectedUndertone.toUpperCase();
    final userPhotoUrl = widget.imagePath != null ? '$baseUrl/${widget.imagePath}' : null;

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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF4A2333)),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Text('Hasil Analisis', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF4A2333))),
                        ],
                      ),
                      // Tombol Share Hasil Analisis (Fitur 5)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.share_rounded, color: Color(0xFFE91E63)),
                          tooltip: 'Bagikan Hasil Analisis',
                          onPressed: _showShareCardDialog,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      // Card Profil Undertone dengan Foto User
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
                                if (userPhotoUrl != null) ...[
                                  Container(
                                    width: 80, height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFE91E63), width: 2),
                                    ),
                                    child: ClipOval(
                                      child: Image.network(
                                        userPhotoUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => const Icon(Icons.person, size: 40, color: Color(0xFFE91E63)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ] else ...[
                                  const Icon(Icons.auto_awesome, size: 40, color: Color(0xFFE91E63)),
                                  const SizedBox(height: 12),
                                ],
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
                      
                      // Kolom Pencarian Produk
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari produk atau brand...',
                          prefixIcon: const Icon(Icons.search, color: Color(0xFFE91E63)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Area Rekomendasi Murni Sesuai Undertone
                      _isLoading
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(child: CircularProgressIndicator(color: Color(0xFFE91E63))),
                            )
                          : _filteredRecommendations.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 30),
                                  child: Center(
                                    child: Text(
                                      'Belum ada produk spesifik untuk undertone $undertoneTitle. Silakan tambahkan produk melalui menu Manajemen Produk Admin.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Color(0xFF7A5C61), height: 1.4),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _filteredRecommendations.length,
                                  itemBuilder: (context, index) {
                                    final prod = _filteredRecommendations[index];
                                    final isSaved = prod['is_saved'] ?? false;
                                    final imageUrl = prod['image_url'];

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.white, width: 1),
                                      ),
                                      child: ListTile(
                                        onTap: () => _showProductDetail(prod),
                                        leading: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: imageUrl != null && imageUrl.toString().isNotEmpty
                                              ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image))
                                              : Container(
                                                  width: 50, height: 50,
                                                  decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(10)),
                                                  child: const Icon(Icons.brush, color: Color(0xFFE91E63)),
                                                ),
                                        ),
                                        title: Text(prod['product_name'] ?? 'Makeup Item', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                                        subtitle: Text('${prod['brand']} • ${_formatRupiah(prod['price'] ?? 0)}', style: const TextStyle(color: Color(0xFF7A5C61), fontSize: 13)),
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