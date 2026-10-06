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

  void _showAddEditModal({Map<String, dynamic>? product}) {
    final nameController = TextEditingController(text: product?['product_name'] ?? '');
    final brandController = TextEditingController(text: product?['brand'] ?? '');
    final priceController = TextEditingController(text: product?['price']?.toString() ?? '');
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
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product == null ? 'Tambah Produk Baru' : 'Edit Produk',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A2333)),
                    ),
                    const SizedBox(height: 16),
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nama Produk')),
                    const SizedBox(height: 12),
                    TextField(controller: brandController, decoration: const InputDecoration(labelText: 'Brand')),
                    const SizedBox(height: 12),
                    TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga (Rp)')),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63), 
                        minimumSize: const Size(double.infinity, 50),
                        disabledBackgroundColor: Colors.grey,
                      ),
                      onPressed: isSaving ? null : () async {
                        setModalState(() => isSaving = true);
                        try {
                          final body = json.encode({
                            "product_name": nameController.text.trim(),
                            "brand": brandController.text.trim(),
                            "price": double.tryParse(priceController.text) ?? 0,
                            "undertone": undertone,
                          });

                          final url = product == null
                              ? Uri.parse('$baseUrl/api/v1/admin/products')
                              : Uri.parse('$baseUrl/api/v1/admin/products/${product['product_id']}');

                          final response = await (product == null
                              ? http.post(url, headers: {"Content-Type": "application/json"}, body: body)
                              : http.put(url, headers: {"Content-Type": "application/json"}, body: body));

                          if (response.statusCode == 200) {
                            final resData = json.decode(response.body);
                            if (resData['success'] == true) {
                              if (mounted) Navigator.pop(context); // Tutup modal
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Produk berhasil disimpan!'), backgroundColor: Colors.green),
                              );
                              _fetchProducts(); // Sinkronisasi ulang
                              return; // Skip set isSaving = false krn modal sdh tertutup
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Gagal: ${resData['error']}'), backgroundColor: Colors.red),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Server Error: ${response.statusCode}'), backgroundColor: Colors.red),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Koneksi Gagal: $e'), backgroundColor: Colors.red),
                          );
                        } 
                        
                        // Hanya jalan jika gagal & modal belum ditutup
                        setModalState(() => isSaving = false);
                      },
                      child: isSaving 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Simpan Produk', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                      const Text('Manajemen Produk', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF4A2333))),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Color(0xFFE91E63), size: 36),
                        onPressed: () => _showAddEditModal(),
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
                                    title: Text(p['product_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('${p['brand'] ?? '-'} • Rp ${p['price'] ?? 0} • ${p['undertone'] ?? '-'}'),
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