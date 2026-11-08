import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class VirtualTryOnScreen extends StatefulWidget {
  final String undertone;
  final String? initialCategory;
  final String? initialColorHex;
  final String? initialProductName;
  final bool isFreeExperiment;

  const VirtualTryOnScreen({
    super.key,
    required this.undertone,
    this.initialCategory,
    this.initialColorHex,
    this.initialProductName,
    this.isFreeExperiment = false,
  });

  @override
  State<VirtualTryOnScreen> createState() => _VirtualTryOnScreenState();
}

class _VirtualTryOnScreenState extends State<VirtualTryOnScreen> {
  WebViewController? _controller;
  bool _isPermissionGranted = false;
  bool _isEngineLoading = true;
  
  // 3 Mode Panel: 'full', 'compact' (minimize), 'hidden' (sembunyikan)
  String _panelMode = 'full';

  bool _isComparingBefore = false;
  bool _isMirrorLocked = true;

  List _apiProducts = [];
  Map? _matchedProduct;
  bool _isLoadingProducts = false;
  String _currentUid = 'usr_dummy_01';
  final String _localBaseUrl = 'http://10.4.89.111:8000';

  bool get _isFreeExperiment =>
      widget.isFreeExperiment || widget.undertone.toLowerCase() == 'free_experiment';

  String _experimentMode = 'preset';
  double _customRed = 224;
  double _customGreen = 90;
  double _customBlue = 71;
  double _makeupOpacity = 0.85;

  String _selectedCategory = 'lipstick';
  String? _selectedColor;

  final Map<String, String?> _activeMakeupStates = {
    'lipstick': null,
    'blush': null,
    'foundation': null,
    'eyeshadow': null,
    'eyeliner': null,
  };

  final List _categories = [
    {'id': 'lipstick', 'label': 'Lipstick'},
    {'id': 'blush', 'label': 'Blush'},
    {'id': 'foundation', 'label': 'Foundation'},
    {'id': 'eyeshadow', 'label': 'Eyeshadow'},
    {'id': 'eyeliner', 'label': 'Eyeliner'},
  ];

  List get _makeupTemplates {
    String targetTone = widget.undertone.toLowerCase();
    if (_isFreeExperiment) {
      if (_experimentMode == 'warm') {
        targetTone = 'warm';
      } else if (_experimentMode == 'cool') {
        targetTone = 'cool';
      } else if (_experimentMode == 'neutral') {
        targetTone = 'neutral';
      } else {
        targetTone = 'all_preset';
      }
    }

    if (targetTone == 'warm') {
      return [
        {'name': 'Latina Baddie', 'icon': Icons.local_fire_department, 'layers': {'lipstick': '#8C1D18', 'blush': '#A84A38', 'foundation': '#D6A473', 'eyeshadow': '#542A1C', 'eyeliner': '#1A1A1A'}},
        {'name': 'Arabic Glam', 'icon': Icons.auto_awesome, 'layers': {'lipstick': '#915B32', 'blush': '#B86A50', 'foundation': '#E5B88B', 'eyeshadow': '#AD5D3B', 'eyeliner': '#1A1A1A'}},
        {'name': 'Sunkissed Igari', 'icon': Icons.wb_sunny, 'layers': {'lipstick': '#E8523A', 'blush': '#E86842', 'foundation': '#F3D6B6', 'eyeshadow': '#D48B6A', 'eyeliner': '#5C3A21'}},
        {'name': 'Warm Sunset', 'icon': Icons.wb_twilight, 'layers': {'lipstick': '#E05A47', 'blush': '#D96B43', 'foundation': '#E5B88B', 'eyeshadow': '#B55239', 'eyeliner': '#4A3525'}},
        {'name': 'Golden Glow', 'icon': Icons.flare, 'layers': {'lipstick': '#C67B5C', 'blush': '#E08A68', 'foundation': '#F3D6B6', 'eyeshadow': '#C68B59', 'eyeliner': '#1A1A1A'}},
        {'name': 'Peachy Coral', 'icon': Icons.local_florist, 'layers': {'lipstick': '#F27961', 'blush': '#F48B72', 'foundation': '#F7E1C6', 'eyeshadow': '#D97B59', 'eyeliner': '#5C3A21'}},
        {'name': 'Spiced Autumn', 'icon': Icons.park, 'layers': {'lipstick': '#9E2A2B', 'blush': '#B83B2A', 'foundation': '#DCAC80', 'eyeshadow': '#7D3522', 'eyeliner': '#1A1A1A'}},
        {'name': 'Caramel Latte', 'icon': Icons.coffee, 'layers': {'lipstick': '#B86A50', 'blush': '#C67B5C', 'foundation': '#EDD0AA', 'eyeshadow': '#8D4E3F', 'eyeliner': '#5C3A21'}},
        {'name': 'Terracotta Goddess', 'icon': Icons.terrain, 'layers': {'lipstick': '#B83B2A', 'blush': '#C85A32', 'foundation': '#E5B88B', 'eyeshadow': '#9E4732', 'eyeliner': '#4A3525'}},
      ];
    } else if (targetTone == 'cool') {
      return [
        {'name': 'Siren Eyes', 'icon': Icons.water, 'layers': {'lipstick': '#8E2457', 'blush': '#A83B5E', 'foundation': '#E5B8A8', 'eyeshadow': '#3E4E6C', 'eyeliner': '#1A1A1A'}},
        {'name': 'Soft Goth', 'icon': Icons.nights_stay, 'layers': {'lipstick': '#590822', 'blush': '#821D48', 'foundation': '#FCE8E1', 'eyeshadow': '#3D1430', 'eyeliner': '#1A1A1A'}},
        {'name': 'Douyin Doll', 'icon': Icons.face_3, 'layers': {'lipstick': '#E35D82', 'blush': '#F08CAE', 'foundation': '#FDF0EC', 'eyeshadow': '#E8B4C8', 'eyeliner': '#4A1A4B'}},
        {'name': 'Berry Chic', 'icon': Icons.spa, 'layers': {'lipstick': '#B4002E', 'blush': '#C85A7C', 'foundation': '#ECC4B2', 'eyeshadow': '#8E44AD', 'eyeliner': '#1A1A1A'}},
        {'name': 'Cool Mauve', 'icon': Icons.ac_unit, 'layers': {'lipstick': '#7A1C4B', 'blush': '#B95C82', 'foundation': '#F7DFD4', 'eyeshadow': '#7D4E6D', 'eyeliner': '#33333D'}},
        {'name': 'Icy Rose', 'icon': Icons.diamond_outlined, 'layers': {'lipstick': '#D94E78', 'blush': '#F08CAE', 'foundation': '#E5B8A8', 'eyeshadow': '#A36A8E', 'eyeliner': '#1B2845'}},
        {'name': 'Cherry Blossom', 'icon': Icons.filter_vintage, 'layers': {'lipstick': '#E35D82', 'blush': '#F285A2', 'foundation': '#FCE8E1', 'eyeshadow': '#D48BA8', 'eyeliner': '#5A1A32'}},
        {'name': 'Midnight Siren', 'icon': Icons.dark_mode, 'layers': {'lipstick': '#6B0F2B', 'blush': '#8E2457', 'foundation': '#D8A590', 'eyeshadow': '#3D1430', 'eyeliner': '#1B2845'}},
        {'name': 'Cranberry Luxe', 'icon': Icons.celebration, 'layers': {'lipstick': '#9E143B', 'blush': '#C2466D', 'foundation': '#ECC4B2', 'eyeshadow': '#7A284B', 'eyeliner': '#1A1A1A'}},
      ];
    } else if (targetTone == 'neutral') {
      return [
        {'name': 'Clean Girl', 'icon': Icons.water_drop, 'layers': {'lipstick': '#C86D73', 'blush': '#E89296', 'foundation': '#F4D9C6', 'eyeshadow': '#D8B4A0', 'eyeliner': '#6E473B'}},
        {'name': 'Mob Wife Glam', 'icon': Icons.diamond, 'layers': {'lipstick': '#73242B', 'blush': '#964B54', 'foundation': '#DCB294', 'eyeshadow': '#47302B', 'eyeliner': '#1A1A1A'}},
        {'name': 'Y2K Grunge', 'icon': Icons.headphones, 'layers': {'lipstick': '#5E2420', 'blush': '#8C3B54', 'foundation': '#EBCAB3', 'eyeshadow': '#5E4B4E', 'eyeliner': '#262626'}},
        {'name': 'Natural Neutral', 'icon': Icons.face_retouching_natural, 'layers': {'lipstick': '#C05C67', 'blush': '#B56B60', 'foundation': '#F4D9C6', 'eyeshadow': '#A84A5C', 'eyeliner': '#33333D'}},
        {'name': 'Soft Rosewood', 'icon': Icons.auto_awesome, 'layers': {'lipstick': '#8F2D38', 'blush': '#C46D6E', 'foundation': '#E2B89A', 'eyeshadow': '#8D4E3F', 'eyeliner': '#1A1A1A'}},
        {'name': 'Everyday MLBB', 'icon': Icons.favorite_border, 'layers': {'lipstick': '#C86D73', 'blush': '#D97E82', 'foundation': '#FAE3D4', 'eyeshadow': '#A66F65', 'eyeliner': '#4A3525'}},
        {'name': 'Velvet Mocha', 'icon': Icons.coffee_outlined, 'layers': {'lipstick': '#7A3E37', 'blush': '#A65E54', 'foundation': '#CCA07C', 'eyeshadow': '#6E453B', 'eyeliner': '#1A1A1A'}},
        {'name': 'Dusty Peony', 'icon': Icons.local_florist, 'layers': {'lipstick': '#B85A65', 'blush': '#CF767E', 'foundation': '#F4D9C6', 'eyeshadow': '#9E5E66', 'eyeliner': '#5A1A32'}},
        {'name': 'Vintage Nude', 'icon': Icons.camera_enhance, 'layers': {'lipstick': '#B56B60', 'blush': '#C98279', 'foundation': '#E2B89A', 'eyeshadow': '#94675E', 'eyeliner': '#4A3525'}},
      ];
    } else {
      return [
        {'name': 'Latina Baddie', 'icon': Icons.local_fire_department, 'layers': {'lipstick': '#8C1D18', 'blush': '#A84A38', 'foundation': '#D6A473', 'eyeshadow': '#542A1C', 'eyeliner': '#1A1A1A'}},
        {'name': 'Arabic Glam', 'icon': Icons.auto_awesome, 'layers': {'lipstick': '#915B32', 'blush': '#B86A50', 'foundation': '#E5B88B', 'eyeshadow': '#AD5D3B', 'eyeliner': '#1A1A1A'}},
        {'name': 'Siren Eyes', 'icon': Icons.water, 'layers': {'lipstick': '#8E2457', 'blush': '#A83B5E', 'foundation': '#E5B8A8', 'eyeshadow': '#3E4E6C', 'eyeliner': '#1A1A1A'}},
        {'name': 'Douyin Doll', 'icon': Icons.face_3, 'layers': {'lipstick': '#E35D82', 'blush': '#F08CAE', 'foundation': '#FDF0EC', 'eyeshadow': '#E8B4C8', 'eyeliner': '#4A1A4B'}},
        {'name': 'Y2K Grunge', 'icon': Icons.headphones, 'layers': {'lipstick': '#5E2420', 'blush': '#8C3B54', 'foundation': '#EBCAB3', 'eyeshadow': '#5E4B4E', 'eyeliner': '#262626'}},
        {'name': 'Mob Wife', 'icon': Icons.diamond, 'layers': {'lipstick': '#73242B', 'blush': '#964B54', 'foundation': '#DCB294', 'eyeshadow': '#47302B', 'eyeliner': '#1A1A1A'}},
        {'name': 'Clean Girl', 'icon': Icons.water_drop, 'layers': {'lipstick': '#C86D73', 'blush': '#E89296', 'foundation': '#F4D9C6', 'eyeshadow': '#D8B4A0', 'eyeliner': '#6E473B'}},
        {'name': 'Igari Blush', 'icon': Icons.favorite, 'layers': {'lipstick': '#E05A47', 'blush': '#EA6A57', 'foundation': '#F3D6B6', 'eyeshadow': '#C96A50', 'eyeliner': '#5A1A32'}},
        {'name': 'Latte Makeup', 'icon': Icons.coffee, 'layers': {'lipstick': '#9E5842', 'blush': '#B86A50', 'foundation': '#DCAC80', 'eyeshadow': '#7D4832', 'eyeliner': '#4A3525'}},
        {'name': 'Soft Goth', 'icon': Icons.nights_stay, 'layers': {'lipstick': '#590822', 'blush': '#821D48', 'foundation': '#FCE8E1', 'eyeshadow': '#3D1430', 'eyeliner': '#1A1A1A'}},
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    final String initCat = (widget.initialCategory ?? 'lipstick').toLowerCase();
    _selectedCategory = _activeMakeupStates.containsKey(initCat) ? initCat : 'lipstick';
    if (widget.initialColorHex != null) {
      _selectedColor = widget.initialColorHex;
      _activeMakeupStates[_selectedCategory] = _selectedColor;
    }
    _fetchProductsFromBackend();
    _initCameraPermissionAndWebView();
  }

  String _formatRupiah(dynamic price) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    double parsedPrice = double.tryParse(price.toString()) ?? 0.0;
    return currencyFormatter.format(parsedPrice);
  }

  Future<void> _fetchProductsFromBackend() async {
    setState(() => _isLoadingProducts = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUid = prefs.getString('user_uid') ?? 'usr_dummy_01';

      String targetTone = widget.undertone.toLowerCase();
      if (_isFreeExperiment) {
        if (_experimentMode == 'warm') {
          targetTone = 'warm';
        } else if (_experimentMode == 'cool') {
          targetTone = 'cool';
        } else if (_experimentMode == 'neutral') {
          targetTone = 'neutral';
        } else {
          targetTone = 'neutral';
        }
      }

      final response = await http
          .get(Uri.parse('$_localBaseUrl/api/v1/recommendations/$targetTone?user_id=$_currentUid'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          setState(() {
            _apiProducts = decoded['data'] ?? [];
            _updateMatchedProduct();
          });
          return;
        }
      }
      _updateMatchedProduct();
    } catch (e) {
      debugPrint("Gagal mengambil produk API: $e");
      _updateMatchedProduct();
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  String _getCurrentShadeName(String category, String? colorHex) {
    final List palettes = _getPalettesForCategory(category);
    if (colorHex != null) {
      for (var item in palettes) {
        if (item['hex'].toString().toLowerCase() == colorHex.toLowerCase()) {
          return item['name'].toString();
        }
      }
    }
    return palettes.isNotEmpty ? palettes.first['name'].toString() : 'Default Shade';
  }

  Map _getFallbackProductForCategory(String category, String shadeName) {
    final String activeTone = _isFreeExperiment
        ? (_experimentMode == 'warm' || _experimentMode == 'cool' || _experimentMode == 'neutral'
            ? _experimentMode.toUpperCase()
            : 'ALL TONE')
        : widget.undertone.toUpperCase();

    if (category == 'lipstick') {
      return {
        'product_id': 'fallback_lip',
        'brand': 'Wardah / Make Over',
        'product_name': 'Colorfit Velvet Matte Lip Mousse - $shadeName',
        'price': 79000,
        'undertone': activeTone,
        'image_url': null,
        'is_saved': false,
      };
    } else if (category == 'blush') {
      return {
        'product_id': 'fallback_blush',
        'brand': 'Emina / Somethinc',
        'product_name': 'Cheek Lit Pressed Blush On - $shadeName',
        'price': 45000,
        'undertone': activeTone,
        'image_url': null,
        'is_saved': false,
      };
    } else if (category == 'foundation') {
      return {
        'product_id': 'fallback_found',
        'brand': 'Skintific',
        'product_name': 'Cover All Perfect Cushion - $shadeName',
        'price': 159000,
        'undertone': activeTone,
        'image_url': null,
        'is_saved': false,
      };
    } else if (category == 'eyeshadow') {
      return {
        'product_id': 'fallback_eye',
        'brand': 'ESQA',
        'product_name': 'Goddess Eyeshadow Palette - $shadeName',
        'price': 135000,
        'undertone': activeTone,
        'image_url': null,
        'is_saved': false,
      };
    } else {
      return {
        'product_id': 'fallback_liner',
        'brand': 'Maybelline',
        'product_name': 'Hyper Sharp Power Waterproof Eyeliner - $shadeName',
        'price': 99000,
        'undertone': activeTone,
        'image_url': null,
        'is_saved': false,
      };
    }
  }

  Map _findProductMatchFor(String category, String colorHex) {
    final String shadeName = _getCurrentShadeName(category, colorHex).toLowerCase();

    if (_apiProducts.isEmpty) {
      return _getFallbackProductForCategory(category, shadeName.toUpperCase());
    }

    final List categoryMatches = _apiProducts.where((prod) {
      final name = (prod['product_name'] ?? '').toString().toLowerCase();
      if (category == 'lipstick') {
        return name.contains('lip') || name.contains('tint') || name.contains('matte') || name.contains('gloss') || name.contains('cream') || name.contains('crayon');
      } else if (category == 'blush') {
        return name.contains('blush') || name.contains('cheek') || name.contains('flush');
      } else if (category == 'foundation') {
        return name.contains('cushion') || name.contains('foundation') || name.contains('base') || name.contains('powder');
      } else if (category == 'eyeshadow') {
        return name.contains('eye') || name.contains('shadow') || name.contains('palette');
      } else if (category == 'eyeliner') {
        return name.contains('liner') || name.contains('pen') || name.contains('kohl') || name.contains('pencil');
      }
      return false;
    }).toList();

    if (categoryMatches.isEmpty) {
      return _getFallbackProductForCategory(category, shadeName.toUpperCase());
    }

    dynamic bestMatch = categoryMatches.first;
    for (var prod in categoryMatches) {
      final name = (prod['product_name'] ?? '').toString().toLowerCase();
      final words = shadeName.split(' ');
      if (words.any((w) => w.length > 2 && name.contains(w))) {
        bestMatch = prod;
        break;
      }
    }
    return Map.from(bestMatch as Map);
  }

  void _updateMatchedProduct() {
    String? activeColor = _activeMakeupStates[_selectedCategory] ?? _selectedColor;
    if (activeColor == null) {
      setState(() {
        _matchedProduct = _getFallbackProductForCategory(_selectedCategory, "Default");
      });
      return;
    }
    setState(() {
      _matchedProduct = _findProductMatchFor(_selectedCategory, activeColor);
    });
  }

  Future<void> _launchMarketplace(String platform, String productName, String brand) async {
    final query = Uri.encodeComponent('$brand $productName');
    String url = platform == 'shopee'
        ? 'https://shopee.co.id/search?keyword=$query'
        : 'https://www.tokopedia.com/search?st=product&q=$query';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _toggleSaveProduct(String productId, bool isCurrentlySaved) async {
    if (productId.startsWith('fallback_')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk rekomendasi berhasil ditandai ke favorit! ❤️')),
      );
      return;
    }
    try {
      http.Response response;
      if (isCurrentlySaved) {
        response = await http.delete(Uri.parse('$_localBaseUrl/api/v1/favorites/$_currentUid/$productId'));
      } else {
        response = await http.post(
          Uri.parse('$_localBaseUrl/api/v1/favorites'),
          headers: {"Content-Type": "application/json"},
          body: json.encode({"user_id": _currentUid, "product_id": productId}),
        );
      }
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isCurrentlySaved ? 'Produk dihapus dari tersimpan' : 'Produk berhasil disimpan! ❤️')),
          );
        }
        _fetchProductsFromBackend();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengubah status simpan')),
        );
      }
    }
  }

  void _showAllActiveProducts() {
    final List activeItems = [];
    
    _activeMakeupStates.forEach((cat, color) {
      if (color != null) {
        Map prod = _findProductMatchFor(cat, color);
        activeItems.add({
          'category': cat,
          'color': color,
          'shade_name': _getCurrentShadeName(cat, color),
          'product': prod,
        });
      }
    });

    if (activeItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anda belum menerapkan makeup apapun!')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(modalContext).padding.bottom + 20,
          ),
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Daftar Produk yang Sedang Digunakan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A2333)),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: activeItems.length,
                  itemBuilder: (context, idx) {
                    final item = activeItems[idx];
                    final prod = item['product'];
                    final String catName = item['category'].toString().toUpperCase();
                    final Color shadeColor = Color(int.parse(item['color'].replaceFirst('#', '0xFF')));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF8BBD0)),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: prod['image_url'] != null
                                ? Image.network(prod['image_url'].toString(), width: 60, height: 60, fit: BoxFit.cover)
                                : Container(width: 60, height: 60, color: Colors.pink.shade50, child: const Icon(Icons.brush, color: Colors.pink)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFE91E63), borderRadius: BorderRadius.circular(4)),
                                      child: Text(catName, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 10, height: 10,
                                      decoration: BoxDecoration(color: shadeColor, shape: BoxShape.circle, border: Border.all(color: Colors.black26)),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        item['shade_name'].toString(),
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE91E63)),
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  prod['product_name'].toString(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4A2333)),
                                  maxLines: 2, overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${prod['brand']} • ${_formatRupiah(prod['price'])}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.shopping_bag, color: Color(0xFFE91E63)),
                            onPressed: () => _launchMarketplace('shopee', prod['product_name'].toString(), prod['brand'].toString()),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMatchedProductDetail() {
    final Map prod = _matchedProduct ?? _getFallbackProductForCategory(_selectedCategory, _getCurrentShadeName(_selectedCategory, _selectedColor));
    final imageUrl = prod['image_url'];
    final String shadeName = _getCurrentShadeName(_selectedCategory, _selectedColor);
    final String productName = (prod['product_name'] ?? 'Makeup Item').toString();
    final String brand = (prod['brand'] ?? 'Brand Kosmetik').toString();
    final String price = _formatRupiah(prod['price'] ?? 0);
    final String undertone = (prod['undertone'] ??
            (_isFreeExperiment ? _experimentMode.toUpperCase() : widget.undertone))
        .toString()
        .toUpperCase();
    final bool isSaved = prod['is_saved'] == true;
    final String activeHex =
        _activeMakeupStates[_selectedCategory] ?? _selectedColor ?? '#E05A47';
    final Color shadeColorObj = Color(int.parse(activeHex.replaceFirst('#', '0xFF')));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(modalContext).viewInsets.bottom +
                MediaQuery.of(modalContext).padding.bottom +
                24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: imageUrl != null && imageUrl.toString().isNotEmpty
                        ? Image.network(
                            imageUrl.toString(),
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              width: 120,
                              height: 120,
                              color: Colors.pink.shade50,
                              child: const Icon(Icons.brush, size: 50, color: Color(0xFFE91E63)),
                            ),
                          )
                        : Container(
                            width: 120,
                            height: 120,
                            color: Colors.pink.shade50,
                            child: const Icon(Icons.brush, size: 50, color: Color(0xFFE91E63)),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      brand,
                      style: const TextStyle(
                        color: Color(0xFFE91E63),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF8BBD0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: shadeColorObj,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black26),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Shade: $shadeName',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A2333),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  productName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A2333),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4A2333),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE4EC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Undertone: $undertone',
                        style: const TextStyle(
                          color: Color(0xFFE91E63),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Beli Produk Ini di E-Commerce:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7A5C61),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEE4D2D),
                          side: const BorderSide(color: Color(0xFFEE4D2D), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _launchMarketplace('shopee', productName, brand),
                        icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                        label: const Text(
                          'Shopee',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF03AC0E),
                          side: const BorderSide(color: Color(0xFF03AC0E), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _launchMarketplace('tokopedia', productName, brand),
                        icon: const Icon(Icons.storefront_outlined, size: 18),
                        label: const Text(
                          'Tokopedia',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(modalContext);
                    _toggleSaveProduct((prod['product_id'] ?? 'fallback_id').toString(), isSaved);
                  },
                  icon: Icon(isSaved ? Icons.favorite : Icons.favorite_border, size: 18),
                  label: Text(
                    isSaved ? 'Hapus dari Favorit' : 'Simpan ke Favorit ❤️',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _rgbToHex(int r, int g, int b) {
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  List _getPalettesForCategory(String category) {
    if (_isFreeExperiment && _experimentMode == 'custom') {
      final customHex = _rgbToHex(_customRed.toInt(), _customGreen.toInt(), _customBlue.toInt());
      return [
        {'name': 'Custom Mix', 'hex': customHex},
      ];
    }

    String effectiveTone = widget.undertone.toLowerCase();
    if (_isFreeExperiment) {
      if (_experimentMode == 'warm') effectiveTone = 'warm';
      if (_experimentMode == 'cool') effectiveTone = 'cool';
      if (_experimentMode == 'neutral') effectiveTone = 'neutral';
      if (_experimentMode == 'preset') effectiveTone = 'all_preset';
    }

    if (category == 'foundation') {
      if (effectiveTone == 'warm') {
        return [
          {'name': 'Warm Alabaster', 'hex': '#FBF0D9'},
          {'name': 'Warm Porcelain', 'hex': '#F7E1C6'},
          {'name': 'Soft Cream', 'hex': '#F5DCB8'},
          {'name': 'Warm Ivory', 'hex': '#F3D6B6'},
          {'name': 'Golden Butter', 'hex': '#EDD0AA'},
          {'name': 'Warm Vanilla', 'hex': '#E9C49B'},
          {'name': 'Golden Beige', 'hex': '#E5B88B'},
          {'name': 'Sunlit Sand', 'hex': '#DCAC80'},
          {'name': 'Honey Ochre', 'hex': '#D6A473'},
          {'name': 'Warm Honey', 'hex': '#D19C67'},
          {'name': 'Golden Amber', 'hex': '#C68A53'},
          {'name': 'Warm Tan', 'hex': '#B87D4B'},
          {'name': 'Toasted Bronze', 'hex': '#A66D3F'},
          {'name': 'Warm Cinnamon', 'hex': '#915B32'},
        ];
      } else if (effectiveTone == 'cool') {
        return [
          {'name': 'Pearl Ivory', 'hex': '#FDF0EC'},
          {'name': 'Cool Alabaster', 'hex': '#FCE8E1'},
          {'name': 'Porcelain Rose', 'hex': '#F7DFD4'},
          {'name': 'Rosy Silk', 'hex': '#F5D8CC'},
          {'name': 'Pink Petal', 'hex': '#F2D2C4'},
          {'name': 'Cool Vanilla', 'hex': '#ECC4B2'},
          {'name': 'Shell Beige', 'hex': '#E5B8A8'},
          {'name': 'Cool Bisque', 'hex': '#DFB09E'},
          {'name': 'Rose Beige', 'hex': '#D8A590'},
          {'name': 'Fawn Rose', 'hex': '#CA947F'},
          {'name': 'Cool Almond', 'hex': '#BC846E'},
          {'name': 'Chestnut Rose', 'hex': '#B07762'},
          {'name': 'Rose Cocoa', 'hex': '#A36B56'},
          {'name': 'Deep Espresso', 'hex': '#8C5642'},
        ];
      } else if (effectiveTone == 'neutral') {
        return [
          {'name': 'Cloud Ivory', 'hex': '#FCF0E6'},
          {'name': 'Pure Linen', 'hex': '#FAE3D4'},
          {'name': 'Natural Ivory', 'hex': '#F4D9C6'},
          {'name': 'Chiffon Nude', 'hex': '#F0D1BC'},
          {'name': 'Soft Buff', 'hex': '#EBCAB3'},
          {'name': 'Neutral Beige', 'hex': '#E2B89A'},
          {'name': 'Cashew Nude', 'hex': '#DCB294'},
          {'name': 'Nude Bisque', 'hex': '#D7AD8E'},
          {'name': 'Medium Sand', 'hex': '#CCA07C'},
          {'name': 'Toasted Hazelnut', 'hex': '#BE8F6B'},
          {'name': 'Neutral Caramel', 'hex': '#B07F59'},
          {'name': 'Rich Pecan', 'hex': '#996845'},
          {'name': 'Mocha Truffle', 'hex': '#87593A'},
          {'name': 'Deep Walnut', 'hex': '#73482D'},
        ];
      } else {
        return [
          {'name': 'Pearl Ivory', 'hex': '#FDF0EC'},
          {'name': 'Warm Alabaster', 'hex': '#FBF0D9'},
          {'name': 'Cool Alabaster', 'hex': '#FCE8E1'},
          {'name': 'Pure Linen', 'hex': '#FAE3D4'},
          {'name': 'Warm Ivory', 'hex': '#F3D6B6'},
          {'name': 'Porcelain Rose', 'hex': '#F7DFD4'},
          {'name': 'Natural Ivory', 'hex': '#F4D9C6'},
          {'name': 'Golden Butter', 'hex': '#EDD0AA'},
          {'name': 'Pink Petal', 'hex': '#F2D2C4'},
          {'name': 'Soft Buff', 'hex': '#EBCAB3'},
          {'name': 'Golden Beige', 'hex': '#E5B88B'},
          {'name': 'Cool Vanilla', 'hex': '#ECC4B2'},
          {'name': 'Neutral Beige', 'hex': '#E2B89A'},
          {'name': 'Sunlit Sand', 'hex': '#DCAC80'},
          {'name': 'Warm Honey', 'hex': '#D19C67'},
          {'name': 'Rose Beige', 'hex': '#D8A590'},
          {'name': 'Medium Sand', 'hex': '#CCA07C'},
          {'name': 'Warm Tan', 'hex': '#B87D4B'},
          {'name': 'Cool Almond', 'hex': '#BC846E'},
          {'name': 'Rich Pecan', 'hex': '#996845'},
        ];
      }
    }

    if (category == 'eyeliner') {
      return [
        {'name': 'Jet Black', 'hex': '#1A1A1A'},
        {'name': 'Carbon Matte', 'hex': '#262626'},
        {'name': 'Espresso', 'hex': '#4A3525'},
        {'name': 'Cocoa Brown', 'hex': '#5C3A21'},
        {'name': 'Warm Taupe', 'hex': '#6E473B'},
        {'name': 'Bronze Copper', 'hex': '#8C5230'},
        {'name': 'Charcoal', 'hex': '#33333D'},
        {'name': 'Graphite Grey', 'hex': '#4E515C'},
        {'name': 'Burgundy', 'hex': '#5A1A32'},
        {'name': 'Berry Liner', 'hex': '#781E42'},
        {'name': 'Deep Plum', 'hex': '#4A1A4B'},
        {'name': 'Midnight Navy', 'hex': '#1B2845'},
        {'name': 'Royal Sapphire', 'hex': '#1F3B73'},
        {'name': 'Forest Emerald', 'hex': '#1E3F2D'},
        {'name': 'Olive Gold', 'hex': '#54522B'},
        {'name': 'Champagne Glow', 'hex': '#E5C39C'},
      ];
    }

    if (category == 'eyeshadow') {
      if (effectiveTone == 'warm') {
        return [
          {'name': 'Vanilla Gold', 'hex': '#F2DCB3'},
          {'name': 'Champagne Gold', 'hex': '#E5C39C'},
          {'name': 'Sunlit Amber', 'hex': '#E0A96D'},
          {'name': 'Peach Shimmer', 'hex': '#E28B6B'},
          {'name': 'Apricot Silk', 'hex': '#D48B6A'},
          {'name': 'Honey Mustard', 'hex': '#C68B59'},
          {'name': 'Warm Bronze', 'hex': '#B56B45'},
          {'name': 'Copper Penny', 'hex': '#AD5D3B'},
          {'name': 'Cinnamon Spice', 'hex': '#B55239'},
          {'name': 'Ginger Rust', 'hex': '#A84A32'},
          {'name': 'Terracotta Clay', 'hex': '#9E4732'},
          {'name': 'Rustic Orange', 'hex': '#8F4728'},
          {'name': 'Sienna Earth', 'hex': '#823D24'},
          {'name': 'Warm Mocha', 'hex': '#7D3522'},
          {'name': 'Olive Bronze', 'hex': '#6E5C38'},
          {'name': 'Dark Espresso', 'hex': '#542A1C'},
        ];
      } else if (effectiveTone == 'cool') {
        return [
          {'name': 'Frosty Pearl', 'hex': '#F2E6EE'},
          {'name': 'Icy Pink', 'hex': '#E8B4C8'},
          {'name': 'Lilac Mist', 'hex': '#D6A8DF'},
          {'name': 'Rose Quartz', 'hex': '#D48BA8'},
          {'name': 'Ballet Mauve', 'hex': '#B5728D'},
          {'name': 'Orchid Haze', 'hex': '#A36A8E'},
          {'name': 'Cool Lilac', 'hex': '#9B59B6'},
          {'name': 'Dusty Lavender', 'hex': '#8E6A9E'},
          {'name': 'Mauve Taupe', 'hex': '#7D4E6D'},
          {'name': 'Amethyst', 'hex': '#8E44AD'},
          {'name': 'Plum Velvet', 'hex': '#753B7A'},
          {'name': 'Berry Wine', 'hex': '#7A284B'},
          {'name': 'Smoky Plum', 'hex': '#522146'},
          {'name': 'Silver Slate', 'hex': '#6E7382'},
          {'name': 'Ocean Twilight', 'hex': '#3E4E6C'},
          {'name': 'Midnight Berry', 'hex': '#3D1430'},
        ];
      } else if (effectiveTone == 'neutral') {
        return [
          {'name': 'Ivory Satin', 'hex': '#EBDDD4'},
          {'name': 'Soft Cashmere', 'hex': '#D8B4A0'},
          {'name': 'Champagne Rose', 'hex': '#D9A99A'},
          {'name': 'Nude Rose', 'hex': '#C48B84'},
          {'name': 'Blush Taupe', 'hex': '#B5827A'},
          {'name': 'Taupe Silk', 'hex': '#A66F65'},
          {'name': 'Dusty Cedar', 'hex': '#9E5E66'},
          {'name': 'Rosewood', 'hex': '#A84A5C'},
          {'name': 'Toasted Almond', 'hex': '#9C5B53'},
          {'name': 'Vintage Mink', 'hex': '#94675E'},
          {'name': 'Choco Latte', 'hex': '#8D4E3F'},
          {'name': 'Muted Mauve', 'hex': '#82525E'},
          {'name': 'Hazelnut Cocoa', 'hex': '#785046'},
          {'name': 'Velvet Cocoa', 'hex': '#6E453B'},
          {'name': 'Smoky Quartz', 'hex': '#5E4B4E'},
          {'name': 'Dark Truffle', 'hex': '#47302B'},
        ];
      } else {
        return [
          {'name': 'Champagne Gold', 'hex': '#E5C39C'},
          {'name': 'Icy Pink', 'hex': '#E8B4C8'},
          {'name': 'Soft Cashmere', 'hex': '#D8B4A0'},
          {'name': 'Rose Quartz', 'hex': '#D48BA8'},
          {'name': 'Peach Shimmer', 'hex': '#E28B6B'},
          {'name': 'Cool Lilac', 'hex': '#9B59B6'},
          {'name': 'Nude Rose', 'hex': '#C48B84'},
          {'name': 'Honey Mustard', 'hex': '#C68B59'},
          {'name': 'Dusty Lavender', 'hex': '#8E6A9E'},
          {'name': 'Taupe Silk', 'hex': '#A66F65'},
          {'name': 'Cinnamon Spice', 'hex': '#B55239'},
          {'name': 'Amethyst', 'hex': '#8E44AD'},
          {'name': 'Rosewood', 'hex': '#A84A5C'},
          {'name': 'Copper Penny', 'hex': '#AD5D3B'},
          {'name': 'Berry Wine', 'hex': '#7A284B'},
          {'name': 'Choco Latte', 'hex': '#8D4E3F'},
          {'name': 'Terracotta', 'hex': '#9E4732'},
          {'name': 'Smoky Plum', 'hex': '#522146'},
          {'name': 'Velvet Cocoa', 'hex': '#6E453B'},
          {'name': 'Silver Slate', 'hex': '#6E7382'},
        ];
      }
    }

    if (category == 'blush') {
      if (effectiveTone == 'warm') {
        return [
          {'name': 'Sunlit Nectar', 'hex': '#F79D84'},
          {'name': 'Apricot Nectar', 'hex': '#F48B72'},
          {'name': 'Papaya Sorbet', 'hex': '#F27D5E'},
          {'name': 'Peach Coral', 'hex': '#E05A47'},
          {'name': 'Tangerine Pop', 'hex': '#E86842'},
          {'name': 'Coral Reef', 'hex': '#EA6A57'},
          {'name': 'Warm Guava', 'hex': '#E07A68'},
          {'name': 'Honey Peach', 'hex': '#E08A68'},
          {'name': 'Sunlit Terracotta', 'hex': '#D96B43'},
          {'name': 'Persimmon', 'hex': '#C85A32'},
          {'name': 'Ginger Peach', 'hex': '#C46243'},
          {'name': 'Cinnamon Flush', 'hex': '#B83B2A'},
          {'name': 'Golden Bronze', 'hex': '#C67B5C'},
          {'name': 'Caramel Rose', 'hex': '#B86A50'},
          {'name': 'Spiced Chai', 'hex': '#A84A38'},
          {'name': 'Toasted Almond', 'hex': '#9E4732'},
        ];
      } else if (effectiveTone == 'cool') {
        return [
          {'name': 'Sakura Pink', 'hex': '#F7A1BA'},
          {'name': 'Baby Doll Pink', 'hex': '#F285A2'},
          {'name': 'Icy Petals', 'hex': '#F08CAE'},
          {'name': 'Bubblegum Pop', 'hex': '#EB6A9A'},
          {'name': 'Cotton Candy', 'hex': '#E06C9F'},
          {'name': 'Pink Flamingo', 'hex': '#DE5488'},
          {'name': 'Mauve Pink', 'hex': '#C85A7C'},
          {'name': 'Lavender Flush', 'hex': '#C97AA6'},
          {'name': 'Rose Berry', 'hex': '#B95C82'},
          {'name': 'Fuchsia Flush', 'hex': '#D81B60'},
          {'name': 'Raspberry Tart', 'hex': '#C2466D'},
          {'name': 'Plum Sorbet', 'hex': '#A83B5E'},
          {'name': 'Cool Mulberry', 'hex': '#9E2A5B'},
          {'name': 'Wild Orchid', 'hex': '#8E44AD'},
          {'name': 'Blackberry Wine', 'hex': '#821D48'},
          {'name': 'Sangria Wine', 'hex': '#7A1C4B'},
        ];
      } else if (effectiveTone == 'neutral') {
        return [
          {'name': 'Cashmere Pink', 'hex': '#E89296'},
          {'name': 'Soft Peony', 'hex': '#E2726E'},
          {'name': 'Blushing Nude', 'hex': '#D97E82'},
          {'name': 'Tea Rose', 'hex': '#CF767E'},
          {'name': 'Dusty Rose', 'hex': '#C05C67'},
          {'name': 'Rosewood Flush', 'hex': '#C46D6E'},
          {'name': 'Petal Mauve', 'hex': '#C46D76'},
          {'name': 'Vintage Rose', 'hex': '#C98279'},
          {'name': 'Classic Nude', 'hex': '#B56B60'},
          {'name': 'Toasted Rose', 'hex': '#B06A5E'},
          {'name': 'Soft Mauve', 'hex': '#A84A5C'},
          {'name': 'Coral Cashmere', 'hex': '#D9534F'},
          {'name': 'Warm Fig', 'hex': '#A65E54'},
          {'name': 'Desert Rose', 'hex': '#964B54'},
          {'name': 'Plum Woods', 'hex': '#8C3B54'},
          {'name': 'Berry Nude', 'hex': '#8F2D38'},
        ];
      } else {
        return [
          {'name': 'Apricot Nectar', 'hex': '#F48B72'},
          {'name': 'Baby Doll Pink', 'hex': '#F285A2'},
          {'name': 'Soft Peony', 'hex': '#E2726E'},
          {'name': 'Peach Coral', 'hex': '#E05A47'},
          {'name': 'Cotton Candy', 'hex': '#E06C9F'},
          {'name': 'Blushing Nude', 'hex': '#D97E82'},
          {'name': 'Tangerine Pop', 'hex': '#E86842'},
          {'name': 'Mauve Pink', 'hex': '#C85A7C'},
          {'name': 'Dusty Rose', 'hex': '#C05C67'},
          {'name': 'Warm Guava', 'hex': '#E07A68'},
          {'name': 'Rose Berry', 'hex': '#B95C82'},
          {'name': 'Classic Nude', 'hex': '#B56B60'},
          {'name': 'Sunlit Terracotta', 'hex': '#D96B43'},
          {'name': 'Fuchsia Flush', 'hex': '#D81B60'},
          {'name': 'Soft Mauve', 'hex': '#A84A5C'},
          {'name': 'Cinnamon Flush', 'hex': '#B83B2A'},
          {'name': 'Plum Sorbet', 'hex': '#A83B5E'},
          {'name': 'Coral Cashmere', 'hex': '#D9534F'},
          {'name': 'Golden Bronze', 'hex': '#C67B5C'},
          {'name': 'Sangria Wine', 'hex': '#7A1C4B'},
        ];
      }
    }

    if (effectiveTone == 'warm') {
      return [
        {'name': 'Apricot Nude', 'hex': '#F48B72'},
        {'name': 'Peachy Nude', 'hex': '#F27961'},
        {'name': 'Sunlit Coral', 'hex': '#EB6A53'},
        {'name': 'Peach Coral', 'hex': '#E05A47'},
        {'name': 'Papaya Punch', 'hex': '#E8523A'},
        {'name': 'Warm Honey', 'hex': '#D97B59'},
        {'name': 'Bronze Sunset', 'hex': '#D47A45'},
        {'name': 'Warm Nude', 'hex': '#C67B5C'},
        {'name': 'Caramel Latte', 'hex': '#B86A50'},
        {'name': 'Butterscotch', 'hex': '#C46238'},
        {'name': 'Cinnamon', 'hex': '#B55239'},
        {'name': 'Ginger Spice', 'hex': '#AD4628'},
        {'name': 'Terracotta', 'hex': '#B83B2A'},
        {'name': 'Pumpkin Spice', 'hex': '#A8422B'},
        {'name': 'Spiced Brick', 'hex': '#9E2A2B'},
        {'name': 'Maple Rust', 'hex': '#96301E'},
        {'name': 'Chili Pepper', 'hex': '#8C1D18'},
        {'name': 'Roasted Espresso', 'hex': '#6E2418'},
      ];
    } else if (effectiveTone == 'cool') {
      return [
        {'name': 'Ballet Slipper', 'hex': '#F08CAE'},
        {'name': 'Cherry Blossom', 'hex': '#E35D82'},
        {'name': 'Rosy Pink', 'hex': '#D94E78'},
        {'name': 'Mauve Pink', 'hex': '#C85A7C'},
        {'name': 'Orchid Rose', 'hex': '#C24676'},
        {'name': 'Strawberry Pop', 'hex': '#E34A6F'},
        {'name': 'Fuchsia Pop', 'hex': '#D81B60'},
        {'name': 'Magenta Berry', 'hex': '#B51756'},
        {'name': 'Berry Rose', 'hex': '#B4002E'},
        {'name': 'Cranberry Crush', 'hex': '#9E143B'},
        {'name': 'Lavender Mauve', 'hex': '#A34878'},
        {'name': 'Cool Lilac', 'hex': '#8E44AD'},
        {'name': 'Plum Velvet', 'hex': '#8E2457'},
        {'name': 'Mulberry Silk', 'hex': '#82184B'},
        {'name': 'Cherry Plum', 'hex': '#7A1C4B'},
        {'name': 'Deep Wine', 'hex': '#6B0F2B'},
        {'name': 'Vampy Maroon', 'hex': '#590822'},
        {'name': 'Blackberry Night', 'hex': '#42061B'},
      ];
    } else if (effectiveTone == 'neutral') {
      return [
        {'name': 'Nude Cashmere', 'hex': '#D98284'},
        {'name': 'Tea Rose', 'hex': '#D47A7E'},
        {'name': 'Blush Petal', 'hex': '#C86D73'},
        {'name': 'Dusty Rose', 'hex': '#C05C67'},
        {'name': 'Peony Mauve', 'hex': '#B85A65'},
        {'name': 'Classic Nude', 'hex': '#B56B60'},
        {'name': 'Soft Mauve', 'hex': '#A84A5C'},
        {'name': 'Velvet Fig', 'hex': '#AD4C58'},
        {'name': 'Coral Crush', 'hex': '#D9534F'},
        {'name': 'Toasted Almond', 'hex': '#9C5349'},
        {'name': 'Cinnamon Rose', 'hex': '#9E5842'},
        {'name': 'Rosewood', 'hex': '#8F2D38'},
        {'name': 'Choco Latte', 'hex': '#8D4E3F'},
        {'name': 'Mocha Truffle', 'hex': '#7A3E37'},
        {'name': 'Crimson Ruby', 'hex': '#9E1B2B'},
        {'name': 'Red Velvet', 'hex': '#871824'},
        {'name': 'Brick Velvet', 'hex': '#73242B'},
        {'name': 'Dark Cocoa', 'hex': '#5E2420'},
      ];
    } else {
      return [
        {'name': 'Peachy Nude', 'hex': '#F27961'},
        {'name': 'Cherry Blossom', 'hex': '#E35D82'},
        {'name': 'Blush Petal', 'hex': '#C86D73'},
        {'name': 'Peach Coral', 'hex': '#E05A47'},
        {'name': 'Rosy Pink', 'hex': '#D94E78'},
        {'name': 'Dusty Rose', 'hex': '#C05C67'},
        {'name': 'Papaya Punch', 'hex': '#E8523A'},
        {'name': 'Mauve Pink', 'hex': '#C85A7C'},
        {'name': 'Classic Nude', 'hex': '#B56B60'},
        {'name': 'Warm Nude', 'hex': '#C67B5C'},
        {'name': 'Fuchsia Pop', 'hex': '#D81B60'},
        {'name': 'Soft Mauve', 'hex': '#A84A5C'},
        {'name': 'Caramel Latte', 'hex': '#B86A50'},
        {'name': 'Magenta Berry', 'hex': '#B51756'},
        {'name': 'Coral Crush', 'hex': '#D9534F'},
        {'name': 'Cinnamon', 'hex': '#B55239'},
        {'name': 'Berry Rose', 'hex': '#B4002E'},
        {'name': 'Rosewood', 'hex': '#8F2D38'},
        {'name': 'Terracotta', 'hex': '#B83B2A'},
        {'name': 'Plum Velvet', 'hex': '#8E2457'},
        {'name': 'Choco Latte', 'hex': '#8D4E3F'},
        {'name': 'Spiced Brick', 'hex': '#9E2A2B'},
        {'name': 'Deep Wine', 'hex': '#6B0F2B'},
        {'name': 'Vampy Maroon', 'hex': '#590822'},
      ];
    }
  }

  Future<void> _initCameraPermissionAndWebView() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _isPermissionGranted = false;
          _isEngineLoading = false;
        });
      }
      return;
    }

    setState(() => _isPermissionGranted = true);

    const PlatformWebViewControllerCreationParams params =
        PlatformWebViewControllerCreationParams();
    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'ToneMatchChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'READY') {
            if (mounted) {
              setState(() => _isEngineLoading = false);
            }
            if (widget.initialColorHex != null) {
              _syncLayersToSdk();
            } else {
              _controller?.runJavaScript("if(window.clearToneMatchMakeup) window.clearToneMatchMakeup();");
            }
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) async {
            await _injectCleanMirrorAndBridge();
          },
        ),
      );

    if (controller.platform is AndroidWebViewController) {
      final AndroidWebViewController androidController =
          controller.platform as AndroidWebViewController;
      await androidController.setMediaPlaybackRequiresUserGesture(false);
      await androidController.setOnPlatformPermissionRequest(
        (PlatformWebViewPermissionRequest request) {
          request.grant();
        },
      );
    }

    _controller = controller;
    _controller!.loadRequest(Uri.parse('https://ehsanwwe.github.io/open-makeup-sdk/'));
  }

  Future<void> _injectCleanMirrorAndBridge() async {
    if (_controller == null) return;

    const String jsScript = '''
      (function() {
        window.__isCameraMirrored = true;

        var style = document.createElement('style');
        style.id = 'tonematch-mirror-style';
        style.innerHTML = `
          header, footer { display: none !important; }
          body, html {
            background: #000 !important;
            overflow: hidden !important;
            margin: 0 !important;
            padding: 0 !important;
            width: 100vw !important;
            height: 100vh !important;
          }
          body > div > div > div:last-child {
            position: fixed !important;
            left: -9999px !important;
            opacity: 0 !important;
            pointer-events: none !important;
          }
          section {
            position: fixed !important;
            top: 0 !important;
            left: 0 !important;
            width: 100vw !important;
            height: 100vh !important;
            margin: 0 !important;
            padding: 0 !important;
            border: none !important;
            z-index: 1 !important;
            transform: none !important;
          }
          video, canvas {
            position: fixed !important;
            top: 0 !important;
            left: 0 !important;
            width: 100vw !important;
            height: 100vh !important;
            object-fit: cover !important;
            margin: 0 !important;
            padding: 0 !important;
            border: none !important;
            border-radius: 0 !important;
            z-index: 1 !important;
            transform: scaleX(-1) !important;
            -webkit-transform: scaleX(-1) !important;
          }
        `;
        document.head.appendChild(style);

        window.applyCameraOrientation = function() {
          var scaleVal = window.__isCameraMirrored ? 'scaleX(-1)' : 'scaleX(1)';
          var mediaEls = document.querySelectorAll('video, canvas');
          for (var i = 0; i < mediaEls.length; i++) {
            mediaEls[i].style.setProperty('transform', scaleVal, 'important');
            mediaEls[i].style.setProperty('-webkit-transform', scaleVal, 'important');
          }
        };

        window.setCameraMirror = function(mirrored) {
          window.__isCameraMirrored = mirrored;
          window.applyCameraOrientation();
        };

        var observer = new MutationObserver(function() {
          window.applyCameraOrientation();
        });
        observer.observe(document.body, { childList: true, subtree: true });

        function selectSdkTab(category) {
          var target = category.trim().toLowerCase();
          var buttons = document.querySelectorAll('[role="tablist"] button, [role="tab"], button');
          for (var i = 0; i < buttons.length; i++) {
            var txt = (buttons[i].textContent || '').trim().toLowerCase();
            if (txt === target || (target === 'lipstick' && txt === 'lips') || txt.indexOf(target) !== -1) {
              buttons[i].click();
              return true;
            }
          }
          return false;
        }

        function triggerDomClearActions() {
          var btns = document.querySelectorAll('button, [role="button"]');
          for (var i = 0; i < btns.length; i++) {
            var t = (btns[i].textContent || '').trim().toLowerCase();
            if (t.includes('clear') || t.includes('reset') || t.includes('none') || t.includes('off') || t.includes('remove')) {
              btns[i].click();
            }
          }
        }

        window.setBeforeMode = function(isBefore, activeList) {
          try {
            var videos = document.querySelectorAll('video');
            var canvases = document.querySelectorAll('canvas');
            window.applyCameraOrientation();

            if (isBefore && videos.length > 0 && canvases.length > 0) {
              for (var v = 0; v < videos.length; v++) {
                videos[v].style.setProperty('display', 'block', 'important');
                videos[v].style.setProperty('opacity', '1', 'important');
                videos[v].style.setProperty('visibility', 'visible', 'important');
                videos[v].style.setProperty('z-index', '2', 'important');
              }
              for (var c = 0; c < canvases.length; c++) {
                canvases[c].style.setProperty('opacity', '0', 'important');
              }
            } else if (!isBefore && canvases.length > 0) {
              for (var c2 = 0; c2 < canvases.length; c2++) {
                canvases[c2].style.setProperty('opacity', '1', 'important');
                canvases[c2].style.setProperty('z-index', '3', 'important');
              }
            } else {
              if (isBefore) {
                window.clearToneMatchMakeup();
              } else if (activeList) {
                window.syncAndApplyLayers(activeList, 1.0);
              }
            }
          } catch (e) {}
        };

        window.syncAndApplyLayers = function(activeList, opacityVal) {
          try {
            if (window.mk && typeof window.mk.clearAll === 'function') {
              window.mk.clearAll();
            }
            triggerDomClearActions();

            setTimeout(function() {
              activeList.forEach(function(item, index) {
                setTimeout(function() {
                  selectSdkTab(item.category);

                  setTimeout(function() {
                    var allBtns = document.querySelectorAll('button');
                    for (var p = 0; p < allBtns.length; p++) {
                      var pTxt = (allBtns[p].textContent || '').trim();
                      if (pTxt === '1' || pTxt === '#1') {
                        allBtns[p].click();
                        break;
                      }
                    }

                    if (window.mk && typeof window.mk.apply === 'function') {
                      window.mk.apply(item.category, {
                        color: item.color,
                        finish: 'matte',
                        pattern: 1,
                        opacity: opacityVal !== undefined ? opacityVal : 0.85
                      });
                    }
                    var colorInput = document.querySelector('input[type="color"]');
                    if (colorInput) {
                      colorInput.value = item.color;
                      colorInput.dispatchEvent(new Event('input', { bubbles: true }));
                      colorInput.dispatchEvent(new Event('change', { bubbles: true }));
                    }
                    window.applyCameraOrientation();
                  }, 80);
                }, index * 200);
              });
            }, 140);
          } catch(e) {}
        };

        window.clearToneMatchMakeup = function() {
          try {
            if (window.mk && typeof window.mk.clearAll === 'function') {
              window.mk.clearAll();
            }
            triggerDomClearActions();

            var cats = ['lipstick', 'blush', 'foundation', 'eyeshadow', 'eyeliner'];
            cats.forEach(function(c, i) {
              setTimeout(function() {
                selectSdkTab(c);
                setTimeout(triggerDomClearActions, 40);
              }, i * 70);
            });
          } catch (e) {}
        };

        setTimeout(function() {
          window.applyCameraOrientation();
          window.clearToneMatchMakeup();
          if (window.ToneMatchChannel) {
            window.ToneMatchChannel.postMessage('READY');
          }
        }, 1000);
      })();
    ''';

    await _controller!.runJavaScript(jsScript);
    if (mounted) {
      setState(() => _isEngineLoading = false);
    }
  }

  void _toggleCameraMirror() {
    if (_controller == null) return;
    setState(() {
      _isMirrorLocked = !_isMirrorLocked;
    });
    _controller!.runJavaScript("if(window.setCameraMirror) window.setCameraMirror($_isMirrorLocked);");
  }

  void _setBeforeComparison(bool showBefore) {
    if (_controller == null) return;
    if (_isComparingBefore == showBefore) return;

    setState(() {
      _isComparingBefore = showBefore;
    });

    final List activeLayers = [];
    _activeMakeupStates.forEach((cat, color) {
      if (color != null) {
        activeLayers.add({'category': cat, 'color': color});
      }
    });
    final String jsonPayload = jsonEncode(activeLayers);

    _controller!.runJavaScript(
      "if(window.setBeforeMode) window.setBeforeMode($showBefore, $jsonPayload);",
    );
  }

  void _syncLayersToSdk() {
    if (_controller == null) return;
    if (_isComparingBefore) {
      _setBeforeComparison(false);
    }

    final List activeLayers = [];
    _activeMakeupStates.forEach((cat, color) {
      if (color != null) {
        activeLayers.add({'category': cat, 'color': color});
      }
    });

    final String jsonPayload = jsonEncode(activeLayers);
    _controller!.runJavaScript(
        "if(window.syncAndApplyLayers) window.syncAndApplyLayers($jsonPayload, $_makeupOpacity);");
  }

  void _selectColorAndApply(String hexColor) {
    setState(() {
      _selectedColor = hexColor;
      _activeMakeupStates[_selectedCategory] = hexColor;
    });
    _updateMatchedProduct();
    _syncLayersToSdk();
  }

  void _applyTemplate(Map templateLayers) {
    setState(() {
      templateLayers.forEach((cat, hex) {
        if (_activeMakeupStates.containsKey(cat)) {
          _activeMakeupStates[cat] = hex;
        }
      });
      if (_activeMakeupStates.containsKey(_selectedCategory)) {
        _selectedColor = _activeMakeupStates[_selectedCategory];
      }
    });
    _updateMatchedProduct();
    _syncLayersToSdk();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Template Makeup Style diterapkan! ✨'),
        backgroundColor: Color(0xFFE91E63),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _clearSingleCategory() {
    if (_controller == null) return;
    final String targetCat = _selectedCategory;
    setState(() {
      _activeMakeupStates[targetCat] = null;
      _selectedColor = null;
    });
    _updateMatchedProduct();
    _syncLayersToSdk();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Makeup ${targetCat.toUpperCase()} berhasil dihapus'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _clearAllMakeup() {
    if (_controller == null) return;
    if (_isComparingBefore) {
      _setBeforeComparison(false);
    }
    setState(() {
      _activeMakeupStates.updateAll((key, value) => null);
      _selectedColor = null;
    });
    _controller!.runJavaScript("if(window.clearToneMatchMakeup) window.clearToneMatchMakeup();");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Semua lapisan makeup berhasil dihapus (Muka Polos)!'),
        backgroundColor: Color(0xFFE91E63),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List palettes = _getPalettesForCategory(_selectedCategory);
    final bool isCurrentCategoryActive = _activeMakeupStates[_selectedCategory] != null;
    final bool hasAnyActiveMakeup = _activeMakeupStates.values.any((e) => e != null);
    final String? activeColorForCurrentCat = _activeMakeupStates[_selectedCategory];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isPermissionGranted && _controller != null)
            Positioned.fill(
              child: WebViewWidget(controller: _controller!),
            )
          else if (!_isEngineLoading && !_isPermissionGranted)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off_outlined, size: 64, color: Colors.white54),
                    const SizedBox(height: 16),
                    const Text(
                      'Izin Kamera Diperlukan untuk Virtual Try-On',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63)),
                      onPressed: () => openAppSettings(),
                      child: const Text('Buka Pengaturan Izin', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),

          if (_isEngineLoading)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(color: Color(0xFFE91E63)),
                    SizedBox(height: 18),
                    Text(
                      'Menyiapkan Cermin AR & Kamera...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        widget.initialProductName != null
                            ? 'Try-On: ${widget.initialProductName}'
                            : (_isFreeExperiment
                                ? 'Virtual Try-On • FREE EXPERIMENT'
                                : 'Virtual Try-On • ${widget.undertone.toUpperCase()}'),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          tooltip: 'Balik Cermin Kamera (Mirror)',
                          icon: Icon(
                            Icons.flip_rounded,
                            color: _isMirrorLocked ? Colors.amberAccent : Colors.white,
                            size: 19,
                          ),
                          onPressed: _toggleCameraMirror,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (hasAnyActiveMakeup) ...[
                        CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            tooltip: 'Lihat Makeup yang Digunakan',
                            icon: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 19),
                            onPressed: _showAllActiveProducts,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _setBeforeComparison(!_isComparingBefore),
                          onLongPressStart: (_) => _setBeforeComparison(true),
                          onLongPressEnd: (_) => _setBeforeComparison(false),
                          child: CircleAvatar(
                            backgroundColor: _isComparingBefore
                                ? Colors.amberAccent
                                : Colors.black54,
                            child: Icon(
                              Icons.compare_rounded,
                              color: _isComparingBefore ? Colors.black87 : Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      CircleAvatar(
                        backgroundColor:
                            hasAnyActiveMakeup ? const Color(0xFFE91E63) : Colors.black54,
                        child: IconButton(
                          tooltip: 'Reset / Hapus Semua Makeup',
                          icon: const Icon(Icons.layers_clear_rounded, color: Colors.white, size: 20),
                          onPressed: _clearAllMakeup,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_isComparingBefore)
            Positioned(
              top: MediaQuery.of(context).padding.top + 65,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.visibility_off_outlined, size: 15, color: Colors.black87),
                      SizedBox(width: 6),
                      Text(
                        'MODE BEFORE: WAJAH POLOS',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (!_isEngineLoading)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasAnyActiveMakeup)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16, bottom: 6),
                          child: GestureDetector(
                            onTap: () => _setBeforeComparison(!_isComparingBefore),
                            onLongPressStart: (_) => _setBeforeComparison(true),
                            onLongPressEnd: (_) => _setBeforeComparison(false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: _isComparingBefore
                                    ? Colors.amberAccent
                                    : Colors.black.withOpacity(0.82),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: _isComparingBefore ? Colors.white : const Color(0xFFE91E63),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.45),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.compare_rounded,
                                    size: 16,
                                    color: _isComparingBefore ? Colors.black87 : Colors.amberAccent,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isComparingBefore
                                        ? 'BEFORE (Polos) • Ketuk Kembali'
                                        : 'Tahan / Ketuk: Before-After',
                                    style: TextStyle(
                                      color: _isComparingBefore ? Colors.black87 : Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.92),
                            const Color(0xFF2B121C).withOpacity(0.96),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _panelMode = _panelMode == 'hidden' ? 'full' : 'hidden';
                              });
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.tune_rounded, color: Color(0xFFE91E63), size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      _panelMode == 'hidden'
                                          ? 'Buka Panel Pilihan Makeup (${_selectedCategory.toUpperCase()})'
                                          : 'Panel Makeup (${_selectedCategory.toUpperCase()})',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => setState(() => _panelMode = 'full'),
                                      child: Icon(
                                        Icons.fullscreen_rounded,
                                        size: 22,
                                        color: _panelMode == 'full' ? Colors.white : Colors.white38,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: () => setState(() => _panelMode = 'compact'),
                                      child: Icon(
                                        Icons.close_fullscreen_rounded,
                                        size: 20,
                                        color: _panelMode == 'compact' ? Colors.white : Colors.white38,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: () => setState(() => _panelMode = 'hidden'),
                                      child: Icon(
                                        Icons.visibility_off_rounded,
                                        size: 20,
                                        color: _panelMode == 'hidden' ? Colors.white : Colors.white38,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          if (_panelMode != 'hidden') ...[
                            const SizedBox(height: 8),

                            // --- BAGIAN FULL MODE ONLY ---
                            if (_panelMode == 'full') ...[
                              if (_isFreeExperiment) ...[
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildModeChip('Auto Preset', 'preset'),
                                      const SizedBox(width: 6),
                                      _buildModeChip('Warm Tone', 'warm'),
                                      const SizedBox(width: 6),
                                      _buildModeChip('Cool Tone', 'cool'),
                                      const SizedBox(width: 6),
                                      _buildModeChip('Neutral Tone', 'neutral'),
                                      const SizedBox(width: 6),
                                      _buildModeChip('Custom Slider', 'custom'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],

                              if (_isFreeExperiment && _experimentMode == 'custom') ...[
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Custom Color Slider (RGB)', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                                      Row(
                                        children: [
                                          const Text('R', style: TextStyle(color: Colors.redAccent, fontSize: 10)),
                                          Expanded(
                                            child: Slider(
                                              activeColor: Colors.redAccent,
                                              value: _customRed, min: 0, max: 255,
                                              onChanged: (val) {
                                                setState(() => _customRed = val);
                                                _selectColorAndApply(_rgbToHex(_customRed.toInt(), _customGreen.toInt(), _customBlue.toInt()));
                                              },
                                            ),
                                          ),
                                          const Text('G', style: TextStyle(color: Colors.greenAccent, fontSize: 10)),
                                          Expanded(
                                            child: Slider(
                                              activeColor: Colors.greenAccent,
                                              value: _customGreen, min: 0, max: 255,
                                              onChanged: (val) {
                                                setState(() => _customGreen = val);
                                                _selectColorAndApply(_rgbToHex(_customRed.toInt(), _customGreen.toInt(), _customBlue.toInt()));
                                              },
                                            ),
                                          ),
                                          const Text('B', style: TextStyle(color: Colors.blueAccent, fontSize: 10)),
                                          Expanded(
                                            child: Slider(
                                              activeColor: Colors.blueAccent,
                                              value: _customBlue, min: 0, max: 255,
                                              onChanged: (val) {
                                                setState(() => _customBlue = val);
                                                _selectColorAndApply(_rgbToHex(_customRed.toInt(), _customGreen.toInt(), _customBlue.toInt()));
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Text('Intensitas Cahaya / Opacity', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                                          const Spacer(),
                                          Text('${(_makeupOpacity * 100).toInt()}%', style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      Slider(
                                        activeColor: Colors.amberAccent,
                                        value: _makeupOpacity, min: 0.1, max: 1.0,
                                        onChanged: (val) {
                                          setState(() => _makeupOpacity = val);
                                          _syncLayersToSdk();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],

                              Text(
                                'Makeup Style / Template Instan (${_makeupTemplates.length} Styles)',
                                style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: _makeupTemplates.map((tpl) {
                                    return GestureDetector(
                                      onTap: () => _applyTemplate(Map.from(tpl['layers'] as Map)),
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4A2333),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.pinkAccent.withOpacity(0.4)),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(tpl['icon'] as IconData, size: 14, color: Colors.amberAccent),
                                            const SizedBox(width: 4),
                                            Text(tpl['name'].toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            // --- AKHIR FULL MODE ONLY ---

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Pilihan Warna ${_selectedCategory.toUpperCase()} (${palettes.length} Shades)',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isCurrentCategoryActive) const SizedBox(width: 8),
                                if (isCurrentCategoryActive)
                                  InkWell(
                                    onTap: _clearSingleCategory,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Hapus ${_selectedCategory.toUpperCase()}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            SizedBox(
                              height: 58,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: palettes.length,
                                itemBuilder: (context, idx) {
                                  final item = palettes[idx];
                                  final String hex = item['hex'].toString();
                                  final String shadeName = item['name'].toString();
                                  final bool isSelected = isCurrentCategoryActive &&
                                      activeColorForCurrentCat?.toLowerCase() == hex.toLowerCase();
                                  final Color colorObj = Color(int.parse(hex.replaceFirst('#', '0xFF')));

                                  return GestureDetector(
                                    onTap: () => _selectColorAndApply(hex),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 10),
                                      child: Column(
                                        children: [
                                          Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              color: colorObj,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isSelected ? Colors.white : Colors.white54,
                                                width: isSelected ? 2.5 : 1.0,
                                              ),
                                            ),
                                            child: isSelected
                                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                                : null,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            shadeName,
                                            style: TextStyle(
                                              color: isSelected ? Colors.amberAccent : Colors.white70,
                                              fontSize: 8,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 4),

                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _categories.map((cat) {
                                  final String catId = cat['id'].toString();
                                  final String catLabel = cat['label'].toString();
                                  final bool isSelected = _selectedCategory == catId;
                                  final bool hasActiveMakeup = _activeMakeupStates[catId] != null;

                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedCategory = catId;
                                      });
                                      _updateMatchedProduct();
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFFE91E63) : const Color(0xFF3A1E2B),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected ? Colors.white : Colors.white24,
                                          width: isSelected ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: Text(
                                        hasActiveMakeup ? '$catLabel ✓' : catLabel,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // --- BAGIAN FULL MODE ONLY: Rekomendasi Produk Bawah ---
                            if (_panelMode == 'full') ...[
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: _showMatchedProductDetail,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.pinkAccent.withOpacity(0.5)),
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: _matchedProduct != null && _matchedProduct!['image_url'] != null
                                              ? Image.network(
                                                  _matchedProduct!['image_url'].toString(),
                                                  width: 38,
                                                  height: 38,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (c, e, s) => Container(
                                                    width: 38,
                                                    height: 38,
                                                    color: const Color(0xFFE91E63).withOpacity(0.2),
                                                    child: const Icon(Icons.shopping_bag_outlined, size: 20, color: Color(0xFFE91E63)),
                                                  ),
                                                )
                                              : Container(
                                                  width: 38,
                                                  height: 38,
                                                  color: const Color(0xFFE91E63).withOpacity(0.2),
                                                  child: const Icon(Icons.shopping_bag_outlined, size: 20, color: Color(0xFFE91E63)),
                                                ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _matchedProduct != null
                                                    ? (_matchedProduct!['product_name'] ?? 'Produk Terkait').toString()
                                                    : 'Rekomendasi ${_selectedCategory.toUpperCase()}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _matchedProduct != null
                                                    ? '${_matchedProduct!['brand']} • ${_formatRupiah(_matchedProduct!['price'])} • Shade: ${_getCurrentShadeName(_selectedCategory, _selectedColor)}'
                                                    : 'Ketuk untuk lihat detail & beli di Shopee/Tokopedia',
                                                style: const TextStyle(color: Colors.amberAccent, fontSize: 9.5, fontWeight: FontWeight.w600),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE91E63),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Text(
                                                'Beli',
                                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                              SizedBox(width: 2),
                                              Icon(Icons.open_in_new_rounded, color: Colors.white, size: 12),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
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

  Widget _buildModeChip(String label, String modeVal) {
    final bool isSelected = _experimentMode == modeVal;
    return GestureDetector(
      onTap: () {
        setState(() => _experimentMode = modeVal);
        _fetchProductsFromBackend();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE91E63) : Colors.white12,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? Colors.white : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}