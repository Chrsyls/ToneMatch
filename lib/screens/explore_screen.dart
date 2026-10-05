import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/dynamic_background.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<dynamic> _products = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  final String baseUrl = 'http://192.168.100.68:8000';

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      String url = '$baseUrl/api/v1/products';
      if (_selectedFilter != 'all') {
        url += '?undertone=$_selectedFilter';
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() => _products = data['data'] ?? []);
        }
      }
    } catch (e) {
      // Error handling
    } finally {
      setState(() => _isLoading = false);
    }
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
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Text('Eksplorasi Katalog', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF4A2333))),
                ),
                // Filter Chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      _buildFilterChip('Semua', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Warm', 'warm'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Cool', 'cool'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Neutral', 'neutral'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                      : _products.isEmpty
                          ? const Center(child: Text('Tidak ada produk ditemukan.', style: TextStyle(color: Color(0xFF7A5C61))))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              itemCount: _products.length,
                              itemBuilder: (context, index) {
                                final p = _products[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.4),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.white.withOpacity(0.6)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.shopping_bag_outlined, size: 30, color: Color(0xFFE91E63)),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(p['product_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4A2333))),
                                                  const SizedBox(height: 4),
                                                  Text('${p['brand']} • Cocok untuk: ${p['undertone']?.toUpperCase()}', style: const TextStyle(fontSize: 13, color: Color(0xFF7A5C61))),
                                                ],
                                              ),
                                            ),
                                            Text('Rp ${p['price'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE91E63))),
                                          ],
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
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    bool isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFFE91E63),
      labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF4A2333), fontWeight: FontWeight.bold),
      backgroundColor: Colors.white.withOpacity(0.5),
      onSelected: (bool selected) {
        setState(() => _selectedFilter = value);
        _fetchProducts();
      },
    );
  }
}