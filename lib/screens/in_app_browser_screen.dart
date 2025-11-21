import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class InAppBrowserScreen extends StatefulWidget {
  final String url;
  final String title;

  const InAppBrowserScreen({
    Key? key,
    required this.url,
    required this.title,
  }) : super(key: key);

  @override
  State<InAppBrowserScreen> createState() => _InAppBrowserScreenState();
}

class _InAppBrowserScreenState extends State<InAppBrowserScreen> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  double _progress = 0;
  String _currentUrl = '';
  String _currentTitle = '';
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _currentTitle = widget.title;
  }

  Future<void> _refresh() async {
    await _webViewController?.reload();
  }

  Future<void> _goBack() async {
    if (_canGoBack) {
      await _webViewController?.goBack();
    }
  }

  Future<void> _goForward() async {
    if (_canGoForward) {
      await _webViewController?.goForward();
    }
  }

  void _shareUrl() {
    Share.share(_currentUrl, subject: _currentTitle);
  }

  void _copyUrl() {
    Clipboard.setData(ClipboardData(text: _currentUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('URL disalin ke clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openInExternalBrowser() async {
    final Uri url = Uri.parse(_currentUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No-op, but present in case future context-based use needed.
  }

  void _showMoreOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Refresh'),
                onTap: () {
                  Navigator.pop(context);
                  _refresh();
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(context);
                  _shareUrl();
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Salin URL'),
                onTap: () {
                  Navigator.pop(context);
                  _copyUrl();
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_browser),
                title: const Text('Buka di Browser Eksternal'),
                onTap: () {
                  Navigator.pop(context);
                  _openInExternalBrowser();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentTitle.isEmpty ? widget.title : _currentTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_currentUrl.isNotEmpty)
              Text(
                Uri.parse(_currentUrl).host,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.more_vert,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: _showMoreOptions,
          ),
        ],
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: isDark ? Colors.black : Colors.white,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      body: Column(
        children: [
          // Progress Bar
          if (_isLoading)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE5FF10)),
            ),

          // WebView
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.url)),
              initialSettings: InAppWebViewSettings(
                useShouldOverrideUrlLoading: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                iframeAllow: "camera; microphone",
                iframeAllowFullscreen: true,
                javaScriptEnabled: true,
                javaScriptCanOpenWindowsAutomatically: true,
                useHybridComposition: true,
                supportZoom: true,
                builtInZoomControls: true,
                displayZoomControls: false,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
              onLoadStart: (controller, url) {
                setState(() {
                  _isLoading = true;
                  _currentUrl = url.toString();
                });
              },
              onLoadStop: (controller, url) async {
                setState(() {
                  _isLoading = false;
                  _currentUrl = url.toString();
                });

                // Update navigation buttons state
                final canGoBack = await controller.canGoBack();
                final canGoForward = await controller.canGoForward();
                setState(() {
                  _canGoBack = canGoBack;
                  _canGoForward = canGoForward;
                });

                // Get page title
                final title = await controller.getTitle();
                if (title != null && title.isNotEmpty) {
                  setState(() {
                    _currentTitle = title;
                  });
                }
              },
              onProgressChanged: (controller, progress) {
                setState(() {
                  _progress = progress / 100;
                });
              },
              onUpdateVisitedHistory: (controller, url, isReload) async {
                final canGoBack = await controller.canGoBack();
                final canGoForward = await controller.canGoForward();
                setState(() {
                  _canGoBack = canGoBack;
                  _canGoForward = canGoForward;
                });
              },
            ),
          ),

          // Bottom Navigation Bar
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.black : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        color: _canGoBack
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? Colors.white38 : Colors.black38),
                      ),
                      onPressed: _canGoBack ? _goBack : null,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.arrow_forward_ios,
                        color: _canGoForward
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? Colors.white38 : Colors.black38),
                      ),
                      onPressed: _canGoForward ? _goForward : null,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      onPressed: _refresh,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.share,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      onPressed: _shareUrl,
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