import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/dynamic_background.dart';

class AdminProductScreen extends StatefulWidget {
  const AdminProductScreen({super.key});

  @override
  State<AdminProductScreen> createState() => _AdminProductScreenState();
}

class _AdminProductScreenState extends State<AdminProductScreen> {
  List<dynamic> _products = [];
  bool _isLoading = true;
  final String baseUrl = 'http://10.4.89.111:8000';

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/v1/products'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true) {
          setState(() {
            _products = data['data'] ?? [];
            _isLoading = false;
          });
          return;
        }
      }
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error fetching products: $e');
      setState(() => _isLoading = false);
    }
  }

  // MODAL AUTO-SCRAPING
  Future<void> _showScrapeDialog() async {
    final TextEditingController urlController = TextEditingController();
    final TextEditingController brandController = TextEditingController();
    String undertone = 'neutral';
    bool isScraping = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Auto-Scrape Produk', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tarik data katalog otomatis beserta gambar produk langsung dari e-commerce.', style: TextStyle(fontSize: 13, color: Colors.black87)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: urlController, 
                      decoration: const InputDecoration(labelText: 'URL Target E-Commerce', border: OutlineInputBorder(), isDense: true)
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: brandController, 
                      decoration: const InputDecoration(labelText: 'Nama Brand', border: OutlineInputBorder(), isDense: true)
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Target Undertone Bawaan', border: OutlineInputBorder(), isDense: true),
                      value: undertone,
                      items: const [
                        DropdownMenuItem(value: 'warm', child: Text('Warm')),
                        DropdownMenuItem(value: 'cool', child: Text('Cool')),
                        DropdownMenuItem(value: 'neutral', child: Text('Neutral')),
                      ],
                      onChanged: (val) => undertone = val ?? 'neutral',
                    ),
                    if (isScraping) 
                      const Padding(
                        padding: EdgeInsets.only(top: 24.0),
                        child: Center(child: CircularProgressIndicator(color: Color(0xFFE91E63))),
                      )
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isScraping ? null : () => Navigator.pop(context),
                  child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63)),
                  onPressed: isScraping ? null : () async {
                    if (urlController.text.isEmpty || brandController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL dan Brand tidak boleh kosong!'), backgroundColor: Colors.red));
                      return;
                    }

                    setStateDialog(() => isScraping = true);
                    try {
                      final response = await http.post(
                        Uri.parse('$baseUrl/api/v1/admin/products/scrape'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({
                          'url': urlController.text.trim(),
                          'brand': brandController.text.trim(),
                          'target_undertone': undertone
                        }),
                      );

                      final data = json.decode(response.body);
                      if (response.statusCode == 200 && data['success'] == true) {
                        if (mounted) Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.green));
                        _fetchProducts(); 
                      } else {
                        throw Exception(data['message'] ?? 'Gagal memproses data');
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                    } finally {
                      if (mounted && isScraping) {
                        setStateDialog(() => isScraping = false);
                      }
                    }
                  },
                  child: const Text('Scrape Sekarang', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  // MODAL TAMBAH / EDIT PRODUK MANUAL (DENGAN INPUT IMAGE URL)
  void _showAddEditModal({Map<String, dynamic>? product}) {
    final nameController = TextEditingController(text: product?['product_name'] ?? '');
    final brandController = TextEditingController(text: product?['brand'] ?? '');
    final priceController = TextEditingController(text: product?['price']?.toString() ?? '');
    final imageController = TextEditingController(text: product?['image_url'] ?? '');
    String undertone = product?['undertone'] ?? 'warm';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24, right: 24, top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product == null ? 'Tambah Produk Baru' : 'Edit Produk', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
                    const SizedBox(height: 16),
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nama Produk', border: OutlineInputBorder(), isDense: true)),
                    const SizedBox(height: 12),
                    TextField(controller: brandController, decoration: const InputDecoration(labelText: 'Brand', border: OutlineInputBorder(), isDense: true)),
                    const SizedBox(height: 12),
                    TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga (Rp)', border: OutlineInputBorder(), isDense: true)),
                    const SizedBox(height: 12),
                    TextField(controller: imageController, decoration: const InputDecoration(labelText: 'URL Gambar Produk (Opsional)', border: OutlineInputBorder(), isDense: true)),
                    const SizedBox(height: 16),
                    const Text('Target Undertone:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7A5C61))),
                    DropdownButtonFormField<String>(
                      value: undertone,
                      items: const [
                        DropdownMenuItem(value: 'warm', child: Text('Warm')),
                        DropdownMenuItem(value: 'cool', child: Text('Cool')),
                        DropdownMenuItem(value: 'neutral', child: Text('Neutral')),
                      ],
                      onChanged: (val) => undertone = val ?? 'warm',
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63), minimumSize: const Size(double.infinity, 50)),
                      onPressed: isSaving ? null : () async {
                        setModalState(() => isSaving = true);
                        try {
                          final body = json.encode({
                            "product_name": nameController.text.trim(),
                            "brand": brandController.text.trim(),
                            "price": double.tryParse(priceController.text) ?? 0,
                            "undertone": undertone,
                            "image_url": imageController.text.trim(),
                          });
                          final url = product == null ? Uri.parse('$baseUrl/api/v1/admin/products') : Uri.parse('$baseUrl/api/v1/admin/products/${product['product_id']}');
                          final response = await (product == null ? http.post(url, headers: {"Content-Type": "application/json"}, body: body) : http.put(url, headers: {"Content-Type": "application/json"}, body: body));
                          
                          if (response.statusCode == 200) {
                            if (mounted) Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk berhasil disimpan!'), backgroundColor: Colors.green));
                            _fetchProducts(); 
                          } else {
                            final errData = json.decode(response.body);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: ${errData['error']}'), backgroundColor: Colors.red));
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Koneksi Gagal: $e'), backgroundColor: Colors.red));
                        } 
                        setModalState(() => isSaving = false);
                      },
                      child: isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Simpan Produk', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteProduct(String id) async {
    await http.delete(Uri.parse('$baseUrl/api/v1/admin/products/$id'));
    _fetchProducts();
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
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Manajemen Produk', 
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF4A2333)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.language, color: Colors.blueAccent, size: 28),
                            tooltip: 'Scrape Web',
                            onPressed: _showScrapeDialog,
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: Color(0xFFE91E63), size: 32),
                            onPressed: () => _showAddEditModal(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading 
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                      : _products.isEmpty 
                          ? const Center(child: Text("Belum ada produk tersimpan.", style: TextStyle(color: Colors.black54)))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              itemCount: _products.length,
                              itemBuilder: (context, index) {
                                final p = _products[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  child: ListTile(
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: p['image_url'] != null && p['image_url'].toString().isNotEmpty
                                          ? Image.network(
                                              p['image_url'],
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                            )
                                          : Container(
                                              width: 50,
                                              height: 50,
                                              color: Colors.pink.shade50,
                                              child: const Icon(Icons.face_retouching_natural, color: Color(0xFFE91E63)),
                                            ),
                                    ),
                                    title: Text(p['product_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('${p['brand'] ?? '-'} • Rp ${p['price'] ?? 0}\nUndertone: ${p['undertone'] ?? '-'}'),
                                    isThreeLine: true,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showAddEditModal(product: p)),
                                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteProduct(p['product_id'].toString())),
                                      ],
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