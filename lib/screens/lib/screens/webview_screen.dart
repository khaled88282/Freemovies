import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isOffline = false;
  double _loadingProgress = 0.0;
  bool _isFullscreen = false;

  static const String _url = 'https://streamex.sh/';

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _initWebView();
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = result == ConnectivityResult.none;
    });
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _loadingProgress = progress / 100.0;
              if (progress == 100) _isLoading = false;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            // Inject CSS for better mobile experience
            _controller.runJavaScript('''
              (function() {
                var meta = document.querySelector('meta[name="viewport"]');
                if (!meta) {
                  meta = document.createElement('meta');
                  meta.name = 'viewport';
                  document.head.appendChild(meta);
                }
                meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0';
                
                // Hide scrollbars for cleaner look
                var style = document.createElement('style');
                style.textContent = '::-webkit-scrollbar { display: none; }';
                document.head.appendChild(style);
              })();
            ''');
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame ?? false) {
              setState(() {
                _hasError = true;
                _isLoading = false;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow all navigation within StreameX ecosystem
            return NavigationDecision.navigate;
          },
        ),
      )
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      );

    if (!_isOffline) {
      _controller.loadRequest(Uri.parse(_url));
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    await _checkConnectivity();
    if (!_isOffline) {
      await _controller.reload();
    }
  }

  void _toggleFullscreen(bool full) {
    setState(() => _isFullscreen = full);
    if (full) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  Future<bool> _onWillPop() async {
    if (_isFullscreen) {
      _toggleFullscreen(false);
      return false;
    }
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }
    return true; // Allow app to exit
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _isFullscreen
            ? null
            : AppBar(
                backgroundColor: Colors.black,
                title: const Text(
                  'StreameX',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 1.5,
                  ),
                ),
                centerTitle: true,
                leading: FutureBuilder<bool>(
                  future: _controller.canGoBack(),
                  builder: (context, snapshot) {
                    return IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () async {
                        if (await _controller.canGoBack()) {
                          _controller.goBack();
                        }
                      },
                    );
                  },
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.home_outlined, color: Colors.white),
                    onPressed: () =>
                        _controller.loadRequest(Uri.parse(_url)),
                    tooltip: 'Home',
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _refresh,
                    tooltip: 'Refresh',
                  ),
                ],
                bottom: _isLoading
                    ? PreferredSize(
                        preferredSize: const Size.fromHeight(3),
                        child: LinearProgressIndicator(
                          value: _loadingProgress,
                          backgroundColor: Colors.grey[900],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF00C896)),
                        ),
                      )
                    : null,
              ),
        body: _isOffline
            ? _buildOfflineWidget()
            : _hasError
                ? _buildErrorWidget()
                : RefreshIndicator(
                    onRefresh: _refresh,
                    color: const Color(0xFF00C896),
                    backgroundColor: Colors.grey[900],
                    child: Stack(
                      children: [
                        WebViewWidget(controller: _controller),
                        if (_isLoading)
                          const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF00C896),
                            ),
                          ),
                      ],
                    ),
                  ),
        bottomNavigationBar: _isFullscreen
            ? null
            : BottomAppBar(
                color: Colors.black,
                height: 56,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: Colors.white70, size: 20),
                      onPressed: () async {
                        if (await _controller.canGoBack()) {
                          _controller.goBack();
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios,
                          color: Colors.white70, size: 20),
                      onPressed: () async {
                        if (await _controller.canGoForward()) {
                          _controller.goForward();
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.home,
                          color: Colors.white70, size: 22),
                      onPressed: () =>
                          _controller.loadRequest(Uri.parse(_url)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.fullscreen,
                          color: Colors.white70, size: 24),
                      onPressed: () => _toggleFullscreen(true),
                      tooltip: 'Fullscreen',
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildOfflineWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, color: Colors.white38, size: 72),
            const SizedBox(height: 20),
            const Text(
              'No Internet Connection',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please check your connection and try again.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C896),
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 72),
            const SizedBox(height: 20),
            const Text(
              'Page Failed to Load',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Something went wrong. Please try refreshing.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C896),
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
