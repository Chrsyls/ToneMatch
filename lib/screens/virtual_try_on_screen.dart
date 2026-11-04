import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  
  // Status untuk Toggle Dropdown / Minimalkan Panel Kontrol Bawah
  bool _isPanelExpanded = true;

  List<dynamic> _apiProducts = [];
  Map<String, dynamic>? _matchedProduct;
  bool _isLoadingProducts = false;
  final String _localBaseUrl = 'http://10.4.89.111:8000';

  bool get _isFreeExperiment => widget.undertone.toLowerCase() == 'free_experiment';

  String _experimentMode = 'preset';
  double _customRed = 224;
  double _customGreen = 90;
  double _customBlue = 71;

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
    final tone = widget.undertone.toLowerCase();
    if (tone == 'warm') {
      return [
        {
          'name': 'Warm Sunset',
          'icon': Icons.wb_sunny_outlined,
          'layers': {'lipstick': '#E05A47', 'blush': '#B83B2A', 'foundation': '#E5B88B', 'eyeshadow': '#B55239', 'eyeliner': '#4A3525'}
        },
        {
          'name': 'Golden Glow',
          'icon': Icons.auto_awesome,
          'layers': {'lipstick': '#C67B5C', 'blush': '#D47A45', 'foundation': '#F3D6B6', 'eyeshadow': '#D19C67', 'eyeliner': '#1A1A1A'}
        },
      ];
    } else if (tone == 'cool') {
      return [
        {
          'name': 'Berry Chic',
          'icon': Icons.spa_outlined,
          'layers': {'lipstick': '#B4002E', 'blush': '#C85A7C', 'foundation': '#ECC4B2', 'eyeshadow': '#8E44AD', 'eyeliner': '#1A1A1A'}
        },
        {
          'name': 'Cool Mauve',
          'icon': Icons.ac_unit,
          'layers': {'lipstick': '#7A1C4B', 'blush': '#D81B60', 'foundation': '#F7DFD4', 'eyeshadow': '#6B0F2B', 'eyeliner': '#33333D'}
        },
      ];
    } else if (tone == 'neutral') {
      return [
        {
          'name': 'Natural Neutral',
          'icon': Icons.face_retouching_natural,
          'layers': {'lipstick': '#C05C67', 'blush': '#B56B60', 'foundation': '#F4D9C6', 'eyeshadow': '#A84A5C', 'eyeliner': '#33333D'}
        },
        {
          'name': 'Soft Rosewood',
          'icon': Icons.auto_awesome,
          'layers': {'lipstick': '#8F2D38', 'blush': '#A84A5C', 'foundation': '#E2B89A', 'eyeshadow': '#8D4E3F', 'eyeliner': '#1A1A1A'}
        },
      ];
    } else {
      return [
        {
          'name': 'Natural Glow',
          'icon': Icons.wb_sunny_outlined,
          'layers': {'lipstick': '#F4D9C6', 'blush': '#E05A47', 'foundation': '#E2B89A', 'eyeshadow': '#C67B5C', 'eyeliner': '#33333D'}
        },
        {
          'name': 'Bold Glam',
          'icon': Icons.auto_awesome,
          'layers': {'lipstick': '#B4002E', 'blush': '#7A1C4B', 'foundation': '#D19C67', 'eyeshadow': '#8E44AD', 'eyeliner': '#1A1A1A'}
        },
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

  Future<void> _fetchProductsFromBackend() async {
    setState(() => _isLoadingProducts = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('user_uid') ?? 'usr_dummy_01';
      final targetTone = _isFreeExperiment ? 'neutral' : widget.undertone.toLowerCase();
      
      final response = await http.get(Uri.parse('$_localBaseUrl/api/v1/recommendations/$targetTone?user_id=$uid'));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          setState(() {
            _apiProducts = decoded['data'] ?? [];
            _updateMatchedProduct();
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal mengambil produk API: $e");
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  void _updateMatchedProduct() {
    if (_apiProducts.isEmpty) {
      _matchedProduct = null;
      return;
    }

    final matched = _apiProducts.firstWhere((prod) {
      final name = (prod['product_name'] ?? '').toString().toLowerCase();
      if (_selectedCategory == 'lipstick') {
        return name.contains('lip') || name.contains('tint') || name.contains('matte') || name.contains('gloss');
      } else if (_selectedCategory == 'blush') {
        return name.contains('blush') || name.contains('cheek') || name.contains('rouge');
      } else if (_selectedCategory == 'foundation') {
        return name.contains('cushion') || name.contains('foundation') || name.contains('base');
      } else if (_selectedCategory == 'eyeshadow') {
        return name.contains('eye') || name.contains('shadow') || name.contains('palette');
      } else if (_selectedCategory == 'eyeliner') {
        return name.contains('liner') || name.contains('pen') || name.contains('kohl');
      }
      return false;
    }, orElse: () => _apiProducts.first);

    setState(() {
      _matchedProduct = matched;
    });
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
      if (_experimentMode == 'preset') effectiveTone = 'neutral';
    }

    if (category == 'foundation') {
      if (effectiveTone == 'warm') {
        return [
          {'name': 'Warm Ivory', 'hex': '#F3D6B6'},
          {'name': 'Golden Beige', 'hex': '#E5B88B'},
          {'name': 'Warm Honey', 'hex': '#D19C67'},
          {'name': 'Warm Tan', 'hex': '#B87D4B'},
        ];
      } else if (effectiveTone == 'cool') {
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

    if (category == 'eyeliner') {
      return [
        {'name': 'Jet Black', 'hex': '#1A1A1A'},
        {'name': 'Espresso', 'hex': '#4A3525'},
        {'name': 'Charcoal', 'hex': '#33333D'},
        {'name': 'Burgundy', 'hex': '#5A1A32'},
      ];
    }

    if (effectiveTone == 'warm') {
      return [
        {'name': 'Peach Coral', 'hex': '#E05A47'},
        {'name': 'Terracotta', 'hex': '#B83B2A'},
        {'name': 'Spiced Brick', 'hex': '#9E2A2B'},
        {'name': 'Warm Nude', 'hex': '#C67B5C'},
        {'name': 'Cinnamon', 'hex': '#B55239'},
        {'name': 'Bronze', 'hex': '#D47A45'},
      ];
    } else if (effectiveTone == 'cool') {
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

        function selectSdkTab(category) {
          var target = category.trim().toLowerCase();
          if (target === 'lipstick') target = 'lips';
          
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

            var cats = ['lips', 'lipstick', 'blush', 'foundation', 'eyeshadow', 'eyeliner'];
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
    final List activeLayers = [];
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
                            : (_isFreeExperiment ? 'Virtual Try-On • EKSPERIMEN BEBAS' : 'Virtual Try-On • ${widget.undertone.toUpperCase()}'),
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

          if (!_isEngineLoading)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Container(
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
                      // Tombol Toggle Dropdown / Minimalkan Panel agar Wajah Terlihat Luas
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.tune_rounded, color: Color(0xFFE91E63), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                _isPanelExpanded ? 'Panel Kontrol Makeup' : 'Ketuk untuk Buka Panel',
                                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              _isPanelExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            onPressed: () => setState(() => _isPanelExpanded = !_isPanelExpanded),
                          ),
                        ],
                      ),

                      // Jika panel dibuka (Expanded), tampilkan seluruh opsi kontrol
                      if (_isPanelExpanded) ...[
                        const SizedBox(height: 8),
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
                                          if (_activeMakeupStates[_selectedCategory] != null) {
                                            _selectColorAndApply(_rgbToHex(_customRed.toInt(), _customGreen.toInt(), _customBlue.toInt()));
                                          }
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
                                          if (_activeMakeupStates[_selectedCategory] != null) {
                                            _selectColorAndApply(_rgbToHex(_customRed.toInt(), _customGreen.toInt(), _customBlue.toInt()));
                                          }
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
                                          if (_activeMakeupStates[_selectedCategory] != null) {
                                            _selectColorAndApply(_rgbToHex(_customRed.toInt(), _customGreen.toInt(), _customBlue.toInt()));
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        const Text('Makeup Style / Template Instan', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
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

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Pilihan Warna ${_selectedCategory.toUpperCase()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
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
                                    _updateMatchedProduct();
                                  });
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

                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _matchedProduct != null && _matchedProduct!['image_url'] != null
                                    ? Image.network(_matchedProduct!['image_url'], width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.brush, size: 24, color: Color(0xFFE91E63)))
                                    : Container(width: 36, height: 36, color: const Color(0xFFE91E63).withOpacity(0.2), child: const Icon(Icons.brush, size: 20, color: Color(0xFFE91E63))),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _matchedProduct != null ? (_matchedProduct!['product_name'] ?? 'Produk Terkait') : 'Produk ${_selectedCategory.toUpperCase()}',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      _matchedProduct != null ? '${_matchedProduct!['brand']} • Rp ${_matchedProduct!['price']}' : 'Rekomendasi sesuai shade',
                                      style: const TextStyle(color: Colors.white70, fontSize: 9),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
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
      onTap: () => setState(() => _experimentMode = modeVal),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE91E63) : Colors.white12,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? Colors.white : Colors.white24),
        ),
        child: Text(label, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}