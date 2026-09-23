import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ResultScreen extends StatelessWidget {
  final String detectedUndertone;
  final String? imageUrl; // Sekarang menerima URL internet

  const ResultScreen({
    super.key, 
    required this.detectedUndertone, 
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Analisis'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Menampilkan foto langsung dari internet (Firebase Storage)
          if (imageUrl != null)
            Container(
              width: double.infinity,
              height: 250,
              color: Colors.grey[200],
              child: Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: const Color(0xFFFCE4EC),
            child: Column(
              children: [
                const Text('Undertone Anda adalah', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text(
                  detectedUndertone.toUpperCase(),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFE91E63)),
                ),
              ],
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Rekomendasi Makeup',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('makeup_products')
                  .where('suitable_undertone', arrayContains: detectedUndertone)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Belum ada rekomendasi produk.'));
                }

                final products = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final data = products[index].data() as Map<String, dynamic>;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _hexToColor(data['hex_color']),
                          radius: 20,
                        ),
                        title: Text(data['name'] ?? 'Nama Produk', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Rp ${data['price'] ?? 0}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _hexToColor(String? hexString) {
    if (hexString == null) return Colors.grey;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}