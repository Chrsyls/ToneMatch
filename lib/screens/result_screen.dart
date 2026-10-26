import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String _currentUid = 'usr_dummy_01';
  final String baseUrl = 'http://10.4.89.111:8000';

  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'all'; // 'all', 'lip', 'base', 'powder', 'blush_eye'

  @override
  void initState() {
    super.initState();
    _initAndFetch();
    _searchController.addListener(_filterProducts);
  }

  Future<void> _initAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUid = prefs.getString('user_uid') ?? 'usr_dummy_01';
    await _fetchRecommendations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecommendations() async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse('$baseUrl/api/v1/recommendations/${widget.detectedUndertone}?user_id=$_currentUid');
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
            _filterProducts();
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

  // FITUR 4: DETEKSI KATEGORI JENIS PRODUK DARI NAMA
  String _detectCategory(String productName) {
    final lower = productName.toLowerCase();
    if (lower.contains('lip') || lower.contains('tint') || lower.contains('matte') || lower.contains('gloss') || lower.contains('cream') || lower.contains('rouge')) {
      return 'lip';
    }
    if (lower.contains('cushion') || lower.contains('foundation') || lower.contains('concealer') || lower.contains('base') || lower.contains('mousse')) {
      return 'base';
    }
    if (lower.contains('powder') || lower.contains('cake') || lower.contains('loose') || lower.contains('compact')) {
      return 'powder';
    }
    if (lower.contains('blush') || lower.contains('cheek') || lower.contains('eye') || lower.contains('palette') || lower.contains('mascara') || lower.contains('brow') || lower.contains('bronzer')) {
      return 'blush_eye';
    }
    return 'base';
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredRecommendations = _recommendations.where((prod) {
        final name = (prod['product_name'] ?? '').toString();
        final brand = (prod['brand'] ?? '').toString();
        final matchesSearch = name.toLowerCase().contains(query) || brand.toLowerCase().contains(query);
        final matchesCategory = _selectedCategory == 'all' || _detectCategory(name) == _selectedCategory;
        return matchesSearch && matchesCategory;
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
      return http.delete(Uri.parse('$baseUrl/api/v1/favorites/$_currentUid/$id'));
    } else {
      return http.post(
        Uri.parse('$baseUrl/api/v1/favorites'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"user_id": _currentUid, "product_id": id}),
      );
    }
  }

  String _formatRupiah(dynamic price) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    double parsedPrice = double.tryParse(price.toString()) ?? 0.0;
    return currencyFormatter.format(parsedPrice);
  }

  // FITUR 2: DATA PALET WARNA PAKAIAN & PERHIASAN SESUAI UNDERTONE
  Map<String, dynamic> _getColorPaletteGuide() {
    final tone = widget.detectedUndertone.toLowerCase();
    if (tone == 'warm') {
      return {
        'jewelry': 'Emas Kuning (Gold) & Brass',
        'jewelryIcon': Icons.wb_sunny_rounded,
        'jewelryColor': const Color(0xFFD4AF37),
        'bestColors': [
          {'name': 'Terracotta', 'color': const Color(0xFFE2725B)},
          {'name': 'Mustard', 'color': const Color(0xFFFFDB58)},
          {'name': 'Olive Green', 'color': const Color(0xFF808000)},
          {'name': 'Warm Peach', 'color': const Color(0xFFFFCBA4)},
          {'name': 'Cream Gold', 'color': const Color(0xFFF5DEB3)},
        ],
        'avoid': 'Biru Es (Icy Blue), Pink Fuchsia Neon, dan Abu-abu Perak Dingin.',
      };
    } else if (tone == 'cool') {
      return {
        'jewelry': 'Perak (Silver) & Platinum',
        'jewelryIcon': Icons.auto_awesome, // PERBAIKAN HURUF KECIL
        'jewelryColor': const Color(0xFF9E9E9E),
        'bestColors': [
          {'name': 'Royal Blue', 'color': const Color(0xFF4169E1)},
          {'name': 'Emerald', 'color': const Color(0xFF50C878)},
          {'name': 'Berry Rose', 'color': const Color(0xFF990F4B)},
          {'name': 'Lavender', 'color': const Color(0xFFB57EDC)},
          {'name': 'Crisp White', 'color': const Color(0xFFF8F9FA)},
        ],
        'avoid': 'Oranye Terang, Kuning Mustard, dan Cokelat Kekuningan.',
      };
    } else {
      return {
        'jewelry': 'Rose Gold, Emas Muda & Perak',
        'jewelryIcon': Icons.diamond_outlined,
        'jewelryColor': const Color(0xFFB76E79),
        'bestColors': [
          {'name': 'Dusty Pink', 'color': const Color(0xFFDCAE96)},
          {'name': 'Jade Green', 'color': const Color(0xFF00A86B)},
          {'name': 'Soft Taupe', 'color': const Color(0xFF8B8589)},
          {'name': 'Teal Lagoon', 'color': const Color(0xFF008080)},
          {'name': 'Creamy Nude', 'color': const Color(0xFFEDE6D6)},
        ],
        'avoid': 'Warna Neon yang terlalu mencolok atau kontras ekstrem.',
      };
    }
  }

  // FITUR 5: KALKULATOR PAKET MAKEUP HEMAT (SMART BUDGET BUILDER)
  void _showBudgetBuilderModal() {
    final TextEditingController budgetCtrl = TextEditingController(text: '250000');
    List<dynamic> bundleResult = [];
    double totalBundlePrice = 0;
    bool hasCalculated = false;

    void calculateBundle(StateSetter setModalState) {
      final double maxBudget = double.tryParse(budgetCtrl.text.replaceAll('.', '').replaceAll(',', '')) ?? 250000;
      
      final sorted = List<dynamic>.from(_recommendations)
        ..sort((a, b) => (double.tryParse(a['price'].toString()) ?? 0).compareTo(double.tryParse(b['price'].toString()) ?? 0));

      final lips = sorted.where((p) => _detectCategory(p['product_name'] ?? '') == 'lip').toList();
      final bases = sorted.where((p) => _detectCategory(p['product_name'] ?? '') == 'base').toList();
      final others = sorted.where((p) => _detectCategory(p['product_name'] ?? '') == 'powder' || _detectCategory(p['product_name'] ?? '') == 'blush_eye').toList();

      List<dynamic> chosen = [];
      double runningTotal = 0;

      for (var group in [lips, bases, others]) {
        for (var item in group) {
          final p = double.tryParse(item['price'].toString()) ?? 0;
          if (runningTotal + p <= maxBudget) {
            chosen.add(item);
            runningTotal += p;
            break;
          }
        }
      }

      if (chosen.length < 3) {
        for (var item in sorted) {
          if (!chosen.contains(item)) {
            final p = double.tryParse(item['price'].toString()) ?? 0;
            if (runningTotal + p <= maxBudget) {
              chosen.add(item);
              runningTotal += p;
              if (chosen.length >= 3) break;
            }
          }
        }
      }

      setModalState(() {
        bundleResult = chosen;
        totalBundlePrice = runningTotal;
        hasCalculated = true;
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (!hasCalculated) {
              calculateBundle(setModalState);
            }
            final double inputBudget = double.tryParse(budgetCtrl.text) ?? 250000;
            final double savedAmount = (inputBudget - totalBundlePrice).clamp(0, double.infinity);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 24, right: 24, top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.calculate_outlined, color: Color(0xFFE91E63)),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Smart Makeup Budget Builder', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF4A2333))),
                              Text('Racik paket makeup lengkap sesuai anggaranmu!', style: TextStyle(fontSize: 12, color: Color(0xFF7A5C61))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: budgetCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Batas Anggaran (Rp)',
                              prefixText: 'Rp ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE91E63),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => calculateBundle(setModalState),
                          child: const Text('Racik Paket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [150000, 250000, 400000, 600000].map((amt) {
                        return ActionChip(
                          label: Text(_formatRupiah(amt), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: const Color(0xFFFCE4EC),
                          onPressed: () {
                            budgetCtrl.text = amt.toString();
                            calculateBundle(setModalState);
                          },
                        );
                      }).toList(),
                    ),
                    const Divider(height: 28),
                    if (bundleResult.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'Anggaran terlalu kecil atau belum ada produk yang cukup. Coba naikkan batas anggaran Anda.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                    else ...[
                      Text('✨ Rekomendasi Paket (${bundleResult.length} Produk):', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                      const SizedBox(height: 10),
                      ...bundleResult.map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: item['image_url'] != null
                                  ? Image.network(item['image_url'], width: 42, height: 42, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.brush, color: Color(0xFFE91E63)))
                                  : const Icon(Icons.brush, color: Color(0xFFE91E63)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['product_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4A2333))),
                                  Text(item['brand'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF7A5C61))),
                                ],
                              ),
                            ),
                            Text(_formatRupiah(item['price']), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFE91E63), fontSize: 13)),
                          ],
                        ),
                      )),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Harga Paket:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                Text(_formatRupiah(totalBundlePrice), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.green.shade800)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: Colors.green.shade700, borderRadius: BorderRadius.circular(10)),
                              child: Text('Hemat ${_formatRupiah(savedAmount)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _launchMarketplace(String platform, String productName, String brand) async {
    final query = Uri.encodeComponent('$brand $productName');
    String url = platform == 'shopee'
        ? 'https://shopee.co.id/search?keyword=$query'
        : 'https://www.tokopedia.com/search?st=product&q=$query';

    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tidak dapat membuka $platform'), backgroundColor: Colors.red));
      }
    }
  }

  void _showShareCardDialog() {
    final undertoneTitle = widget.detectedUndertone.toUpperCase();
    final userPhotoUrl = widget.imagePath != null ? '$baseUrl/${widget.imagePath}' : null;
    final topProducts = _recommendations.take(2).map((e) => "• ${e['brand']} - ${e['product_name']}").join("\n");

    final shareText = "✨ *Hasil Analisis ToneMatch* ✨\n\n"
        "Undertone Kulitku: *$undertoneTitle*\n"
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
                ),
                child: Column(
                  children: [
                    const Text('TONEMATCH BEAUTY CARD', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12, color: Color(0xFF4A2333))),
                    const SizedBox(height: 16),
                    if (userPhotoUrl != null)
                      CircleAvatar(radius: 42, backgroundImage: NetworkImage(userPhotoUrl))
                    else
                      const CircleAvatar(radius: 40, backgroundColor: Color(0xFFE91E63), child: Icon(Icons.face_retouching_natural, size: 42, color: Colors.white)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFE91E63), borderRadius: BorderRadius.circular(20)),
                      child: Text(undertoneTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                    const SizedBox(height: 14),
                    const Text('📸 Screenshot kartu ini untuk IG Story!', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF7A5C61))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF4A2333)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: shareText));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teks disalin! 📋'), backgroundColor: Colors.green));
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Salin Teks'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                      onPressed: () async {
                        final waUrl = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(shareText)}');
                        await launchUrl(waUrl, mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('WhatsApp'),
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: imageUrl != null && imageUrl.toString().isNotEmpty
                      ? Image.network(imageUrl, width: 120, height: 120, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.image, size: 80, color: Colors.grey))
                      : Container(width: 120, height: 120, color: Colors.pink.shade50, child: const Icon(Icons.brush, size: 50, color: Color(0xFFE91E63))),
                ),
              ),
              const SizedBox(height: 16),
              Text(brand, style: const TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold, fontSize: 14)),
              Text(productName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
              const SizedBox(height: 10),
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEE4D2D), side: const BorderSide(color: Color(0xFFEE4D2D))),
                      onPressed: () => _launchMarketplace('shopee', productName, brand),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                      label: const Text('Shopee'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF03AC0E), side: const BorderSide(color: Color(0xFF03AC0E))),
                      onPressed: () => _launchMarketplace('tokopedia', productName, brand),
                      icon: const Icon(Icons.storefront_outlined, size: 18),
                      label: const Text('Tokopedia'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63), minimumSize: const Size(double.infinity, 50)),
                onPressed: () {
                  Navigator.pop(context);
                  _toggleSaveProduct(prod['product_id'].toString(), prod['is_saved'] ?? false);
                },
                child: const Text('Simpan ke Favorit ❤️', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
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
    final paletteGuide = _getColorPaletteGuide();
    final List<Map<String, dynamic>> bestColors = List<Map<String, dynamic>>.from(paletteGuide['bestColors']);

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
                      Container(
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.share_rounded, color: Color(0xFFE91E63)),
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
                      // 1. KARTU PROFIL UNDERTONE
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
                            ),
                            child: Column(
                              children: [
                                if (userPhotoUrl != null) ...[
                                  Container(
                                    width: 80, height: 80,
                                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE91E63), width: 2.5)),
                                    child: ClipOval(
                                      child: Image.network(userPhotoUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.person, size: 40, color: Color(0xFFE91E63))),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                ] else ...[
                                  const Icon(Icons.auto_awesome, size: 40, color: Color(0xFFE91E63)),
                                  const SizedBox(height: 10),
                                ],
                                const Text('Undertone Anda Terdeteksi:', style: TextStyle(color: Color(0xFF7A5C61), fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(undertoneTitle, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF4A2333))),
                                const SizedBox(height: 10),
                                Text(
                                  'Kulit Anda memiliki rona $undertoneTitle. Gunakan panduan palet warna dan produk di bawah ini agar wajah tampak lebih cerah.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Color(0xFF7A5C61), fontSize: 13, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 2. FITUR 2: PANDUAN PALET WARNA & PERHIASAN
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.palette_outlined, color: Color(0xFFE91E63), size: 20),
                                SizedBox(width: 8),
                                Text('Panduan Personal Color & Gaya', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Text('Palet Warna Pakaian Terbaik:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7A5C61))),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: bestColors.map((swatch) {
                                return Column(
                                  children: [
                                    Container(
                                      width: 42, height: 42,
                                      decoration: BoxDecoration(
                                        color: swatch['color'] as Color,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2.5),
                                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(swatch['name'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF4A2333))),
                                  ],
                                );
                              }).toList(),
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                Icon(Icons.workspace_premium, color: paletteGuide['jewelryColor'] as Color, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Perhiasan Cocok: ${paletteGuide['jewelry']}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4A2333)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.block, color: Colors.redAccent, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Hindari: ${paletteGuide['avoid']}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF7A5C61)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. FITUR 5: TOMBOL KALKULATOR PAKET MAKEUP HEMAT
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A2333),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _showBudgetBuilderModal,
                        icon: const Icon(Icons.auto_graph_rounded, color: Color(0xFFFFC107)), // PERBAIKAN HURUF KECIL
                        label: const Text('Racik Paket Makeup Sesuai Budget 💰', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),

                      const SizedBox(height: 24),
                      const Text('Rekomendasi Produk Makeup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                      const SizedBox(height: 12),
                      
                      // Kolom Pencarian
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari produk atau brand...',
                          prefixIcon: const Icon(Icons.search, color: Color(0xFFE91E63)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.55),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 4. FITUR 4: FILTER CHIP KATEGORI JENIS PRODUK
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildCategoryChip('Semua', 'all', Icons.grid_view_rounded),
                            const SizedBox(width: 8),
                            _buildCategoryChip('Lip Products', 'lip', Icons.favorite_border),
                            const SizedBox(width: 8),
                            _buildCategoryChip('Cushion & Base', 'base', Icons.face_retouching_natural),
                            const SizedBox(width: 8),
                            _buildCategoryChip('Powder', 'powder', Icons.blur_on),
                            const SizedBox(width: 8),
                            _buildCategoryChip('Blush & Eye', 'blush_eye', Icons.brush_outlined),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Daftar Produk
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
                                      'Tidak ada produk pada kategori ini untuk undertone $undertoneTitle.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Color(0xFF7A5C61)),
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
                                        color: Colors.white.withOpacity(0.55),
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

  Widget _buildCategoryChip(String label, String value, IconData icon) {
    final bool isSelected = _selectedCategory == value;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFFE91E63)),
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFFE91E63),
      backgroundColor: Colors.white.withOpacity(0.5),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF4A2333),
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      onSelected: (_) {
        setState(() {
          _selectedCategory = value;
          _filterProducts();
        });
      },
    );
  }
}