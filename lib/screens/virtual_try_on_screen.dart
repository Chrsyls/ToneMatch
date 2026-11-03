import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class VirtualTryOnScreen extends StatefulWidget {
  final String undertone;
  final String? initialCategory;
  final String? initialColorHex;
  final String? initialProductName;

  const VirtualTryOnScreen({
    super.key,
    required this.undertone,
    this.initialCategory,
    this.initialColorHex,
    this.initialProductName,
  });

  @override
  State<VirtualTryOnScreen> createState() => _VirtualTryOnScreenState();
}

class _VirtualTryOnScreenState extends State<VirtualTryOnScreen> {
  WebViewController? _controller;
  bool _isPermissionGranted = false;
  bool _isEngineLoading = true;

  late String _selectedCategory;
  late String _selectedColor;
  String _selectedFinish = 'matte';

  final Map<String, String?> _activeMakeupStates = {
    'lipstick': null,
    'blush': null,
    'foundation': null,
    'eyeshadow': null,
    'eyeliner': null,
    'mascara': null,
  };

  final List<dynamic> _categories = [
    {'id': 'lipstick', 'label': 'Lipstick'},
    {'id': 'blush', 'label': 'Blush'},
    {'id': 'foundation', 'label': 'Foundation'},
    {'id': 'eyeshadow', 'label': 'Eyeshadow'},
    {'id': 'eyeliner', 'label': 'Eyeliner'},
    {'id': 'mascara', 'label': 'Mascara'},
  ];

  final List<String> _finishes = ['matte', 'glossy', 'shimmer', 'glitter'];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? 'lipstick';
    final firstItem = _getPalettesForCategory(_selectedCategory).first;
    _selectedColor = widget.initialColorHex ?? firstItem['hex'].toString();
    _activeMakeupStates[_selectedCategory] = _selectedColor;
    _initCameraPermissionAndWebView();
  }

  List<dynamic> _getPalettesForCategory(String category) {
    final tone = widget.undertone.toLowerCase();

    if (category == 'foundation') {
      if (tone == 'warm') {
        return [
          {'name': 'Warm Ivory', 'hex': '#F3D6B6'},
          {'name': 'Golden Beige', 'hex': '#E5B88B'},
          {'name': 'Warm Honey', 'hex': '#D19C67'},
          {'name': 'Warm Tan', 'hex': '#B87D4B'},
        ];
      } else if (tone == 'cool') {
        return [
          {'name': 'Porcelain Rose', 'hex': '#F7DFD4'},
          {'name': 'Cool Vanilla', 'hex': '#ECC4B2'},
          {'name': 'Rose Beige', 'hex': '#D8A590'},
          {'name': 'Cool Almond', 'hex': '#BC846E'},
        ];
      } else {
        return [
          {'name': 'Natural Ivory', 'hex': '#F4D9C6'},
          {'name': 'Neutral Beige', 'hex': '#E2B89A'},
          {'name': 'Medium Sand', 'hex': '#CCA07C'},
          {'name': 'Neutral Caramel', 'hex': '#B07F59'},
        ];
      }
    }

    if (category == 'eyeliner' || category == 'mascara') {
      return [
        {'name': 'Jet Black', 'hex': '#1A1A1A'},
        {'name': 'Espresso', 'hex': '#4A3525'},
        {'name': 'Charcoal', 'hex': '#33333D'},
        {'name': 'Burgundy', 'hex': '#5A1A32'},
      ];
    }

    if (tone == 'warm') {
      return [
        {'name': 'Peach Coral', 'hex': '#E05A47'},
        {'name': 'Terracotta', 'hex': '#B83B2A'},
        {'name': 'Spiced Brick', 'hex': '#9E2A2B'},
        {'name': 'Warm Nude', 'hex': '#C67B5C'},
        {'name': 'Cinnamon', 'hex': '#B55239'},
        {'name': 'Bronze', 'hex': '#D47A45'},
      ];
    } else if (tone == 'cool') {
      return [
        {'name': 'Berry Rose', 'hex': '#B4002E'},
        {'name': 'Mauve Pink', 'hex': '#C85A7C'},
        {'name': 'Cherry Plum', 'hex': '#7A1C4B'},
        {'name': 'Fuchsia', 'hex': '#D81B60'},
        {'name': 'Cool Lilac', 'hex': '#8E44AD'},
        {'name': 'Wine', 'hex': '#6B0F2B'},
      ];
    } else {
      return [
        {'name': 'Dusty Rose', 'hex': '#C05C67'},
        {'name': 'Classic Nude', 'hex': '#B56B60'},
        {'name': 'Soft Mauve', 'hex': '#A84A5C'},
        {'name': 'Rosewood', 'hex': '#8F2D38'},
        {'name': 'Coral', 'hex': '#D9534F'},
        {'name': 'Choco Latte', 'hex': '#8D4E3F'},
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
            _applyCurrentMakeupToSdk();
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
        var style = document.createElement('style');
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
          section, video, canvas {
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
          }
        `;
        document.head.appendChild(style);

        window.applyToneMatchMakeup = function(category, colorHex, finishName) {
          try {
            var tabs = document.querySelectorAll('[role="tab"], button');
            for (var i = 0; i < tabs.length; i++) {
              var txt = (tabs[i].textContent || '').trim().toLowerCase();
              if (txt === category.toLowerCase()) {
                tabs[i].click();
                break;
              }
            }

            setTimeout(function() {
              var colorInput = document.querySelector('input[type="color"]');
              if (colorInput) {
                colorInput.value = colorHex;
                colorInput.dispatchEvent(new Event('input', { bubbles: true }));
                colorInput.dispatchEvent(new Event('change', { bubbles: true }));
              }

              var allBtns = document.querySelectorAll('button');
              for (var j = 0; j < allBtns.length; j++) {
                var bTxt = (allBtns[j].textContent || '').trim().toLowerCase();
                if (bTxt === finishName.toLowerCase()) {
                  allBtns[j].click();
                  break;
                }
              }
            }, 120);
          } catch (e) {}
        };

        window.clearSingleCategory = function(category) {
          try {
            var tabs = document.querySelectorAll('[role="tab"], button');
            for (var i = 0; i < tabs.length; i++) {
              var txt = (tabs[i].textContent || '').trim().toLowerCase();
              if (txt === category.toLowerCase()) {
                tabs[i].click();
                break;
              }
            }
            setTimeout(function() {
              var btns = document.querySelectorAll('button');
              for (var k = 0; k < btns.length; k++) {
                var t = (btns[k].textContent || '').trim().toLowerCase();
                if (t.indexOf('clear') !== -1 || t.indexOf('remove') !== -1 || t.indexOf('off') !== -1) {
                  btns[k].click();
                  break;
                }
              }
            }, 100);
          } catch (e) {}
        };

        window.clearToneMatchMakeup = function() {
          var btns = document.querySelectorAll('button');
          for (var i = 0; i < btns.length; i++) {
            var t = (btns[i].textContent || '').trim().toLowerCase();
            if (t.indexOf('clear') !== -1 || t.indexOf('reset') !== -1) {
              btns[i].click();
            }
          }
        };

        setTimeout(function() {
          if (window.ToneMatchChannel) {
            window.ToneMatchChannel.postMessage('READY');
          }
        }, 1200);
      })();
    ''';

    await _controller!.runJavaScript(jsScript);
    if (mounted) {
      setState(() => _isEngineLoading = false);
    }
    _applyCurrentMakeupToSdk();
  }

  void _applyCurrentMakeupToSdk() {
    if (_controller == null) return;
    setState(() {
      _activeMakeupStates[_selectedCategory] = _selectedColor;
    });
    final jsCall =
        "if(window.applyToneMatchMakeup) window.applyToneMatchMakeup('$_selectedCategory', '$_selectedColor', '$_selectedFinish');";
    _controller!.runJavaScript(jsCall);
  }

  void _clearSingleCategory() {
    if (_controller == null) return;
    setState(() {
      _activeMakeupStates[_selectedCategory] = null;
    });
    _controller!.runJavaScript(
        "if(window.clearSingleCategory) window.clearSingleCategory('$_selectedCategory');");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Makeup ${_selectedCategory.toUpperCase()} dihapus'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _clearAllMakeup() {
    if (_controller == null) return;
    setState(() {
      _activeMakeupStates.updateAll((key, value) => null);
    });
    _controller!.runJavaScript("if(window.clearToneMatchMakeup) window.clearToneMatchMakeup();");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Semua makeup berhasil direset!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> palettes = _getPalettesForCategory(_selectedCategory);
    final bool isCurrentCategoryActive = _activeMakeupStates[_selectedCategory] != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Tampilan Kamera WebView Fullscreen
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

          // 2. Loading Overlay
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

          // 3. Header Bar Atas
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
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        widget.initialProductName != null
                            ? 'Try-On: ${widget.initialProductName}'
                            : 'Virtual Try-On • ${widget.undertone.toUpperCase()}',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      tooltip: 'Reset / Hapus Semua Makeup',
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                      onPressed: _clearAllMakeup,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Panel Kontrol Bawah (Tombol Kategori Kustom dengan Teks Kontras Terbaca Jelas)
          if (!_isEngineLoading)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Shade & Finish',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(width: 8),
                              if (isCurrentCategoryActive)
                                InkWell(
                                  onTap: _clearSingleCategory,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Hapus ${_selectedCategory.toUpperCase()}',
                                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (_selectedCategory != 'eyeliner' && _selectedCategory != 'mascara')
                            SizedBox(
                              height: 32,
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  dropdownColor: const Color(0xFF2B121C),
                                  value: _selectedFinish,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  items: _finishes.map((f) {
                                    return DropdownMenuItem(
                                      value: f,
                                      child: Text(f.toUpperCase()),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedFinish = val);
                                      _applyCurrentMakeupToSdk();
                                    }
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Pilihan Warna Shade (Dengan Latar Belakang Kotak Gelap Agar Teks Terbaca Jelas)
                      SizedBox(
                        height: 68,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: palettes.length,
                          itemBuilder: (context, idx) {
                            final item = palettes[idx];
                            final String hex = item['hex'].toString();
                            final String shadeName = item['name'].toString();
                            final bool isSelected = _selectedColor.toLowerCase() == hex.toLowerCase();
                            final Color colorObj = Color(int.parse(hex.replaceFirst('#', '0xFF')));

                            return GestureDetector(
                              onTap: () {
                                setState(() => _selectedColor = hex);
                                _applyCurrentMakeupToSdk();
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: colorObj,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? Colors.white : Colors.white54,
                                          width: isSelected ? 3.0 : 1.5,
                                        ),
                                        boxShadow: isSelected
                                            ? [BoxShadow(color: colorObj.withOpacity(0.9), blurRadius: 6)]
                                            : null,
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                                          : null,
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.85),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.white24, width: 0.5),
                                      ),
                                      child: Text(
                                        shadeName,
                                        style: TextStyle(
                                          color: isSelected ? Colors.amberAccent : Colors.white,
                                          fontSize: 9,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Pilihan Kategori Makeup (Kustom Container agar Warna Teks 100% Kontras & Terbaca Jelas)
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
                                  if (_activeMakeupStates[catId] != null) {
                                    _selectedColor = _activeMakeupStates[catId]!;
                                  } else {
                                    _selectedColor = _getPalettesForCategory(_selectedCategory).first['hex'].toString();
                                  }
                                });
                                _applyCurrentMakeupToSdk();
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFE91E63) : const Color(0xFF3A1E2B),
                                  borderRadius: BorderRadius.circular(16),
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
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}