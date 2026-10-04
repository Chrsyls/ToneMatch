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
  final String baseUrl = 'http://192.168.11.166:8000'; // Sesuaikan IP Anda

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/v1/products'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true) setState(() => _products = data['data'] ?? []);
      }
    } catch (e) {
      // Error handling
    }
  }

  void _showAddEditModal({Map<String, dynamic>? product}) {
    final nameController = TextEditingController(text: product?['product_name'] ?? '');
    final brandController = TextEditingController(text: product?['brand'] ?? '');
    final priceController = TextEditingController(text: product?['price']?.toString() ?? '');
    String undertone = product?['undertone'] ?? 'warm';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product == null ? 'Tambah Produk Baru' : 'Edit Produk', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A2333))),
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63), minimumSize: const Size(double.infinity, 50)),
                onPressed: () async {
                  final body = json.encode({
                    "product_name": nameController.text,
                    "brand": brandController.text,
                    "price": double.tryParse(priceController.text) ?? 0,
                    "undertone": undertone,
                  });

                  if (product == null) {
                    await http.post(Uri.parse('$baseUrl/api/v1/admin/products'), headers: {"Content-Type": "application/json"}, body: body);
                  } else {
                    await http.put(Uri.parse('$baseUrl/api/v1/admin/products/${product['product_id']}'), headers: {"Content-Type": "application/json"}, body: body);
                  }

                  if (mounted) Navigator.pop(context);
                  _fetchProducts();
                },
                child: const Text('Simpan Produk', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),
            ],
          ),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // Diperbaiki dari .between ke .spaceBetween
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
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final p = _products[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          title: Text(p['product_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${p['brand']} • ${p['undertone']}'),
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