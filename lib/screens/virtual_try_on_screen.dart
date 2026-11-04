import 'dart:convert';
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

  String _selectedCategory = 'lipstick';
  String? _selectedColor;

  final Map<String, String?> _activeMakeupStates = {
    'lipstick': null,
    'blush': null,
    'foundation': null,
    'eyeshadow': null,
  };

  final List<dynamic> _categories = [
    {'id': 'lipstick', 'label': 'Lipstick'},
    {'id': 'blush', 'label': 'Blush'},
    {'id': 'foundation', 'label': 'Foundation'},
    {'id': 'eyeshadow', 'label': 'Eyeshadow'},
  ];

  @override
  void initState() {
    super.initState();
    final String initCat = (widget.initialCategory ?? 'lipstick').toLowerCase();
    _selectedCategory = _activeMakeupStates.containsKey(initCat) ? initCat : 'lipstick';
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
            _controller?.runJavaScript("if(window.clearToneMatchMakeup) window.clearToneMatchMakeup();");
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

        // Fungsi akurat untuk mengeklik tab kategori pada DOM SDK agar landmark wajah tidak tertukar
        function selectSdkTab(category) {
          var target = category.trim().toLowerCase();
          if (target === 'lipstick') target = 'lips'; // Penyesuaian parameter SDK untuk bibir
          
          var buttons = document.querySelectorAll('button, [role="tab"], [role="button"]');
          for (var i = 0; i < buttons.length; i++) {
            var txt = (buttons[i].textContent || '').trim().toLowerCase();
            if (txt === target || txt.indexOf(target) !== -1) {
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

        // Sinkronisasi dan penerapan layer makeup dengan memastikan tab aktif diklik terlebih dahulu
        window.syncAndApplyLayers = function(activeList) {
          try {
            if (window.mk && typeof window.mk.clearAll === 'function') {
              window.mk.clearAll();
            }
            triggerDomClearActions();

            setTimeout(function() {
              activeList.forEach(function(item, index) {
                setTimeout(function() {
                  var sdkCategory = item.category === 'lipstick' ? 'lips' : item.category;
                  selectSdkTab(sdkCategory);

                  setTimeout(function() {
                    if (window.mk && typeof window.mk.apply === 'function') {
                      window.mk.apply(sdkCategory, {
                        color: item.color,
                        finish: 'matte',
                        pattern: 1
                      });
                    }
                    var colorInput = document.querySelector('input[type="color"]');
                    if (colorInput) {
                      colorInput.value = item.color;
                      colorInput.dispatchEvent(new Event('input', { bubbles: true }));
                      colorInput.dispatchEvent(new Event('change', { bubbles: true }));
                    }
                  }, 90);
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

            var cats = ['lips', 'lipstick', 'blush', 'foundation', 'eyeshadow'];
            cats.forEach(function(c, i) {
              setTimeout(function() {
                selectSdkTab(c);
                setTimeout(triggerDomClearActions, 40);
              }, i * 70);
            });
          } catch (e) {}
        };

        setTimeout(function() {
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

  void _syncLayersToSdk() {
    if (_controller == null) return;
    final List<dynamic> activeLayers = [];
    _activeMakeupStates.forEach((cat, color) {
      if (color != null) {
        activeLayers.add({'category': cat, 'color': color});
      }
    });

    final String jsonPayload = jsonEncode(activeLayers);
    _controller!.runJavaScript("if(window.syncAndApplyLayers) window.syncAndApplyLayers($jsonPayload);");
  }

  void _selectColorAndApply(String hexColor) {
    setState(() {
      _selectedColor = hexColor;
      _activeMakeupStates[_selectedCategory] = hexColor;
    });
    _syncLayersToSdk();
  }

  void _clearSingleCategory() {
    if (_controller == null) return;
    final String targetCat = _selectedCategory;
    setState(() {
      _activeMakeupStates[targetCat] = null;
      if (_selectedColor == _activeMakeupStates[targetCat]) {
        _selectedColor = null;
      }
    });
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
    final List<dynamic> palettes = _getPalettesForCategory(_selectedCategory);
    final bool isCurrentCategoryActive = _activeMakeupStates[_selectedCategory] != null;
    final bool hasAnyActiveMakeup = _activeMakeupStates.values.any((e) => e != null);

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

          // Header Bar Atas
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
            ),
          ),

          // Panel Kontrol Bawah
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
                          Text(
                            'Pilihan Warna ${_selectedCategory.toUpperCase()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (isCurrentCategoryActive)
                            InkWell(
                              onTap: _clearSingleCategory,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Hapus ${_selectedCategory.toUpperCase()}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Pilihan Warna Shade Terpadu
                      SizedBox(
                        height: 68,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: palettes.length,
                          itemBuilder: (context, idx) {
                            final item = palettes[idx];
                            final String hex = item['hex'].toString();
                            final String shadeName = item['name'].toString();
                            final bool isSelected = isCurrentCategoryActive &&
                                _activeMakeupStates[_selectedCategory]?.toLowerCase() == hex.toLowerCase();
                            final Color colorObj = Color(int.parse(hex.replaceFirst('#', '0xFF')));

                            return GestureDetector(
                              onTap: () => _selectColorAndApply(hex),
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
                      const SizedBox(height: 8),

                      // Pilihan 4 Kategori Utama
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
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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