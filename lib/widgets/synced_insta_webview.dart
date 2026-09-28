import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../models/reel_item.dart';
import '../theme/app_theme.dart';

class SyncedInstaWebview extends StatefulWidget {
  final String reelUrl;
  final bool isPlaying;
  final double syncPositionSeconds;
  final int lastActionTimestamp;
  final String lastActionBy;
  final String currentUserId;
  final bool isHost;
  final Function(bool isPlaying, double position)? onLocalPlaybackChanged;
  final VoidCallback? onVideoLoaded;

  const SyncedInstaWebview({
    super.key,
    required this.reelUrl,
    required this.isPlaying,
    required this.syncPositionSeconds,
    required this.lastActionTimestamp,
    required this.lastActionBy,
    required this.currentUserId,
    required this.isHost,
    this.onLocalPlaybackChanged,
    this.onVideoLoaded,
  });

  @override
  State<SyncedInstaWebview> createState() => SyncedInstaWebviewState();
}

class SyncedInstaWebviewState extends State<SyncedInstaWebview> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _loadProgress = 0.0;
  String _currentLoadedUrl = '';
  bool _useEmbedMode = true;
  bool _isLocallyInteracting = false;
  Timer? _interactionDebounce;
  Timer? _jsWatcherTimer;

  static const String _syncJsScript = '''
    (function() {
      if (window.reelSync) return;
      window.reelSync = {
        getVideo: function() {
          return document.querySelector('video');
        },
        play: function() {
          var v = this.getVideo();
          if (v) {
            v.muted = false;
            var p = v.play();
            if (p !== undefined) {
              p.catch(function(e) {
                v.muted = true;
                v.play();
              });
            }
            return true;
          }
          return false;
        },
        pause: function() {
          var v = this.getVideo();
          if (v) {
            v.pause();
            return true;
          }
          return false;
        },
        seekTo: function(seconds) {
          var v = this.getVideo();
          if (v) {
            v.currentTime = seconds;
            return true;
          }
          return false;
        },
        getCurrentTime: function() {
          var v = this.getVideo();
          return v ? v.currentTime : 0;
        },
        isPaused: function() {
          var v = this.getVideo();
          return v ? v.paused : true;
        },
        bindEvents: function() {
          var v = this.getVideo();
          if (v && !v._hasReelSync) {
            v._hasReelSync = true;
            v.addEventListener('play', function() {
              if (window.ReelSyncBridge) {
                window.ReelSyncBridge.postMessage(JSON.stringify({
                  type: 'play',
                  time: v.currentTime
                }));
              }
            });
            v.addEventListener('pause', function() {
              if (window.ReelSyncBridge) {
                window.ReelSyncBridge.postMessage(JSON.stringify({
                  type: 'pause',
                  time: v.currentTime
                }));
              }
            });
          }
        }
      };
      
      // Auto-watch for video DOM element
      setInterval(function() {
        if (window.reelSync) {
          window.reelSync.bindEvents();
        }
      }, 1000);
    })();
  ''';

  @override
  void initState() {
    super.initState();
    _initWebViewController();
  }

  void _initWebViewController() {
    final effectiveUrl = _useEmbedMode
        ? ReelItem.formatToEmbedUrl(widget.reelUrl)
        : ReelItem.formatToDirectUrl(widget.reelUrl);

    _currentLoadedUrl = effectiveUrl;

    final WebViewController controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppTheme.background)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36')
      ..addJavaScriptChannel(
        'ReelSyncBridge',
        onMessageReceived: _handleJsBridgeMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _loadProgress = progress / 100.0;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) async {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            await _injectSyncScript();
            widget.onVideoLoaded?.call();
            _applySyncState();
          },
        ),
      );

    // Platform-specific setup for autoplay and media playback
    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;
    _controller.loadRequest(Uri.parse(effectiveUrl));

    // Periodic check to keep video injected and synchronized
    _jsWatcherTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && !_isLoading) {
        _injectSyncScript();
      }
    });
  }

  Future<void> _injectSyncScript() async {
    try {
      await _controller.runJavaScript(_syncJsScript);
    } catch (e) {
      // Ignore injection error on early transitions
    }
  }

  void _handleJsBridgeMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message);
      final type = data['type'] as String?;
      final time = (data['time'] as num?)?.toDouble() ?? 0.0;

      // If user directly clicked play/pause inside the Instagram webview
      if (!_isLocallyInteracting && widget.lastActionBy != widget.currentUserId) {
        if (type == 'play') {
          _notifyPlaybackChanged(true, time);
        } else if (type == 'pause') {
          _notifyPlaybackChanged(false, time);
        }
      }
    } catch (e) {
      debugPrint('Bridge message parse error: $e');
    }
  }

  void _notifyPlaybackChanged(bool isPlaying, double position) {
    _isLocallyInteracting = true;
    _interactionDebounce?.cancel();
    _interactionDebounce = Timer(const Duration(milliseconds: 600), () {
      _isLocallyInteracting = false;
    });
    widget.onLocalPlaybackChanged?.call(isPlaying, position);
  }

  @override
  void didUpdateWidget(covariant SyncedInstaWebview oldWidget) {
    super.didUpdateWidget(oldWidget);

    final targetUrl = _useEmbedMode
        ? ReelItem.formatToEmbedUrl(widget.reelUrl)
        : ReelItem.formatToDirectUrl(widget.reelUrl);

    if (targetUrl != _currentLoadedUrl) {
      _currentLoadedUrl = targetUrl;
      setState(() {
        _isLoading = true;
      });
      _controller.loadRequest(Uri.parse(targetUrl));
      return;
    }

    // If change was made by the partner (not me), synchronize playback
    if (widget.lastActionBy != widget.currentUserId) {
      _applySyncState();
    }
  }

  Future<void> _applySyncState() async {
    try {
      if (widget.isPlaying) {
        await _controller.runJavaScript('window.reelSync && window.reelSync.play();');
      } else {
        await _controller.runJavaScript('window.reelSync && window.reelSync.pause();');
      }

      // Check drift compensation
      final currentTimeResult = await _controller.runJavaScriptReturningResult(
        'window.reelSync ? window.reelSync.getCurrentTime() : 0',
      );
      final currentLocalTime = double.tryParse(currentTimeResult.toString()) ?? 0.0;

      // If drift is greater than 1.5 seconds, sync seek position
      final drift = (currentLocalTime - widget.syncPositionSeconds).abs();
      if (drift > 1.5 && widget.syncPositionSeconds > 0) {
        await _controller.runJavaScript(
          'window.reelSync && window.reelSync.seekTo(${widget.syncPositionSeconds});',
        );
      }
    } catch (e) {
      debugPrint('Sync apply error: $e');
    }
  }

  // Public methods that can be called by parent controls
  Future<void> triggerPlay() async {
    _isLocallyInteracting = true;
    await _controller.runJavaScript('window.reelSync && window.reelSync.play();');
    final time = await getCurrentVideoTime();
    _notifyPlaybackChanged(true, time);
  }

  Future<void> triggerPause() async {
    _isLocallyInteracting = true;
    await _controller.runJavaScript('window.reelSync && window.reelSync.pause();');
    final time = await getCurrentVideoTime();
    _notifyPlaybackChanged(false, time);
  }

  Future<void> triggerSeek(double seconds) async {
    _isLocallyInteracting = true;
    await _controller.runJavaScript('window.reelSync && window.reelSync.seekTo($seconds);');
    _notifyPlaybackChanged(widget.isPlaying, seconds);
  }

  Future<double> getCurrentVideoTime() async {
    try {
      final res = await _controller.runJavaScriptReturningResult(
        'window.reelSync ? window.reelSync.getCurrentTime() : 0',
      );
      return double.tryParse(res.toString()) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  void toggleEmbedMode() {
    setState(() {
      _useEmbedMode = !_useEmbedMode;
      _isLoading = true;
    });
    final targetUrl = _useEmbedMode
        ? ReelItem.formatToEmbedUrl(widget.reelUrl)
        : ReelItem.formatToDirectUrl(widget.reelUrl);
    _currentLoadedUrl = targetUrl;
    _controller.loadRequest(Uri.parse(targetUrl));
  }

  @override
  void dispose() {
    _interactionDebounce?.cancel();
    _jsWatcherTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main In-App Instagram WebView
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: WebViewWidget(controller: _controller),
        ),

        // Linear loading progress indicator
        if (_isLoading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: _loadProgress > 0 ? _loadProgress : null,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.instaOrange),
              minHeight: 3,
            ),
          ),

        // Embed vs Web mode switch pill at top-right
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _useEmbedMode ? Icons.aspect_ratio : Icons.public,
                  size: 13,
                  color: AppTheme.instaYellow,
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: toggleEmbedMode,
                  child: Text(
                    _useEmbedMode ? 'Embed View' : 'Full Web',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Loading overlay spinner if still initializing
        if (_isLoading && _loadProgress < 0.3)
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.instaRed),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Connecting to Instagram Reel...',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
