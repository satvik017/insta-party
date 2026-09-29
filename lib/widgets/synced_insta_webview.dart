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
  final Function(String newUrl, String title)? onReelChanged;
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
    this.onReelChanged,
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
  Timer? _driftTimer;
  Timer? _heartbeatTimer;
  Timer? _jsWatcherTimer;

  static const String _syncJsScript = '''
    (function() {
      if (window.reelSync) return;
      window.reelSync = {
        getVideo: function() {
          // Direct video tag
          var v = document.querySelector('video');
          if (v) return v;
          // Check inside iframes
          var iframes = document.querySelectorAll('iframe');
          for (var i = 0; i < iframes.length; i++) {
            try {
              var doc = iframes[i].contentDocument || iframes[i].contentWindow.document;
              if (doc) {
                var iv = doc.querySelector('video');
                if (iv) return iv;
              }
            } catch(e) {}
          }
          return null;
        },
        play: function() {
          var v = this.getVideo();
          if (v) {
            v.muted = false;
            var p = v.play();
            if (p !== undefined) {
              p.catch(function(e) {
                // If browser blocks unmuted autoplay, play muted
                v.muted = true;
                v.play();
              });
            }
            return true;
          }
          // Fallback: click play button overlay if video element is covered
          var playBtn = document.querySelector('[aria-label="Play"], [aria-label*="play" i], .play-button, div[role="button"][tabindex="0"]');
          if (playBtn) {
            playBtn.click();
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
          var pauseBtn = document.querySelector('[aria-label="Pause"], [aria-label*="pause" i]');
          if (pauseBtn) {
            pauseBtn.click();
            return true;
          }
          return false;
        },
        seekTo: function(seconds) {
          var v = this.getVideo();
          if (v && Number.isFinite(seconds)) {
            v.currentTime = seconds;
            return true;
          }
          return false;
        },
        getCurrentTime: function() {
          var v = this.getVideo();
          return (v && Number.isFinite(v.currentTime)) ? v.currentTime : 0;
        },
        getDuration: function() {
          var v = this.getVideo();
          return (v && Number.isFinite(v.duration)) ? v.duration : 0;
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
            v.addEventListener('seeked', function() {
              if (window.ReelSyncBridge) {
                window.ReelSyncBridge.postMessage(JSON.stringify({
                  type: 'seek',
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

      // Real-time URL & Navigation watcher (SPA routing & swipe in Instagram)
      var lastReportedUrl = window.location.href;
      function checkUrlChange() {
        try {
          var cur = window.location.href;
          if (cur && cur !== lastReportedUrl) {
            lastReportedUrl = cur;
            if (window.ReelSyncBridge) {
              window.ReelSyncBridge.postMessage(JSON.stringify({
                type: 'url_changed',
                url: cur
              }));
            }
          }
        } catch(e) {}
      }

      // Intercept history.pushState & replaceState (used by Instagram's React router on swipe)
      if (!history._reelSyncHooked) {
        history._reelSyncHooked = true;
        var _origPush = history.pushState;
        if (_origPush) {
          history.pushState = function() {
            var res = _origPush.apply(this, arguments);
            setTimeout(checkUrlChange, 50);
            return res;
          };
        }
        var _origReplace = history.replaceState;
        if (_origReplace) {
          history.replaceState = function() {
            var res = _origReplace.apply(this, arguments);
            setTimeout(checkUrlChange, 50);
            return res;
          };
        }
        window.addEventListener('popstate', function() {
          setTimeout(checkUrlChange, 50);
        });
        window.addEventListener('hashchange', checkUrlChange);
      }

      setInterval(checkUrlChange, 400);
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
          onUrlChange: (UrlChange change) {
            if (change.url != null && change.url!.isNotEmpty) {
              _handleUrlChanged(change.url!);
            }
          },
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
            _handleUrlChanged(url);
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
            _handleUrlChanged(url);
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

    // Periodic JS injection to keep sync bridge alive (every 3s)
    _jsWatcherTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && !_isLoading) {
        _injectSyncScript();
      }
    });

    // Periodic drift check every 4 seconds — auto-correct if partner changed state
    _driftTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isLoading && !_isLocallyInteracting && widget.lastActionBy != widget.currentUserId) {
        _applySyncState();
      }
    });

    // Periodic heartbeat from the actively controlling device every 4 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isLoading &&
          !_isLocallyInteracting &&
          widget.isPlaying &&
          widget.lastActionBy == widget.currentUserId) {
        final time = await getCurrentVideoTime();
        if (time > 0) {
          widget.onLocalPlaybackChanged?.call(true, time);
        }
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

      if (type == 'url_changed') {
        final url = data['url'] as String?;
        if (url != null && url.isNotEmpty) {
          _handleUrlChanged(url);
        }
        return;
      }

      // Always report local video interactions to Firebase
      // (skip only if currently handling via overlay controls to avoid double-fire)
      if (!_isLocallyInteracting) {
        if (type == 'play') {
          _notifyPlaybackChanged(true, time);
        } else if (type == 'pause') {
          _notifyPlaybackChanged(false, time);
        } else if (type == 'seek') {
          _notifyPlaybackChanged(widget.isPlaying, time);
        }
      }
    } catch (e) {
      debugPrint('Bridge message parse error: $e');
    }
  }

  void _handleUrlChanged(String url) {
    if (!mounted) return;

    // Check if the URL is an Instagram reel, video, or post
    final shortcode = ReelItem.extractShortcode(url);
    if (shortcode != null && shortcode.isNotEmpty) {
      final cleanReelUrl = 'https://www.instagram.com/reel/$shortcode/';
      final currentShortcode = ReelItem.extractShortcode(widget.reelUrl);

      // If user navigated or swiped to a different reel/post
      if (shortcode != currentShortcode) {
        debugPrint('[Sync] Webview navigated to new reel shortcode: $shortcode (was $currentShortcode)');
        _currentLoadedUrl = cleanReelUrl;
        widget.onReelChanged?.call(cleanReelUrl, 'Instagram Reel ($shortcode)');
      }
    }
  }

  /// Sync whatever page the webview is currently displaying to the partner
  Future<String?> syncCurrentPageToPartner() async {
    try {
      final res = await _controller.runJavaScriptReturningResult('window.location.href');
      final currentUrl = res.toString().replaceAll('"', '').trim();
      if (currentUrl.isNotEmpty && currentUrl.startsWith('http')) {
        final shortcode = ReelItem.extractShortcode(currentUrl);
        final syncUrl = shortcode != null
            ? 'https://www.instagram.com/reel/$shortcode/'
            : currentUrl;
        final title = shortcode != null ? 'Instagram Reel ($shortcode)' : 'Instagram Page';
        widget.onReelChanged?.call(syncUrl, title);
        return syncUrl;
      }
    } catch (e) {
      debugPrint('[Sync] Error syncing current page: $e');
    }
    return null;
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
      final newCode = ReelItem.extractShortcode(widget.reelUrl);
      final curCode = ReelItem.extractShortcode(_currentLoadedUrl);
      if (newCode != null && curCode != null && newCode == curCode) {
        // Same reel already displayed, do not reload
        _currentLoadedUrl = targetUrl;
      } else {
        _currentLoadedUrl = targetUrl;
        setState(() {
          _isLoading = true;
        });
        _controller.loadRequest(Uri.parse(targetUrl));
        return;
      }
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

      // Check current local time
      final currentTimeResult = await _controller.runJavaScriptReturningResult(
        'window.reelSync ? window.reelSync.getCurrentTime() : 0',
      );
      final rawCurrent = currentTimeResult.toString().replaceAll('"', '').trim();
      final currentLocalTime = double.tryParse(rawCurrent) ?? 0.0;

      // Calculate expected position factoring in elapsed time if playing
      double expectedPosition = widget.syncPositionSeconds;
      if (widget.isPlaying && widget.lastActionTimestamp > 0) {
        final elapsed =
            (DateTime.now().millisecondsSinceEpoch - widget.lastActionTimestamp) / 1000.0;
        if (elapsed > 0 && elapsed < 3600) {
          expectedPosition += elapsed;
        }
      }

      // Check video duration for looping reels
      final durationResult = await _controller.runJavaScriptReturningResult(
        'window.reelSync ? window.reelSync.getDuration() : 0',
      );
      final rawDuration = durationResult.toString().replaceAll('"', '').trim();
      final duration = double.tryParse(rawDuration) ?? 0.0;
      if (duration > 1.0 && expectedPosition > duration) {
        expectedPosition = expectedPosition % duration;
      }

      // Drift threshold: 1.5 seconds
      final drift = (currentLocalTime - expectedPosition).abs();
      if (drift > 1.5 && expectedPosition >= 0) {
        debugPrint('[Sync] Correcting drift: local=${currentLocalTime}s, target=${expectedPosition.toStringAsFixed(2)}s');
        await _controller.runJavaScript(
          'window.reelSync && window.reelSync.seekTo(${expectedPosition.toStringAsFixed(2)});',
        );
      }
    } catch (e) {
      debugPrint('[Sync] Apply sync error: $e');
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

  /// Force sync: seek to the Firebase position and apply play/pause state.
  /// Call this when the user explicitly wants to re-align with their partner.
  Future<void> forceSync() async {
    debugPrint('[Sync] Force sync requested — target=${widget.syncPositionSeconds}s');
    await _injectSyncScript();
    await Future.delayed(const Duration(milliseconds: 200));
    await _applySyncState();
  }

  Future<double> getCurrentVideoTime() async {
    try {
      final res = await _controller.runJavaScriptReturningResult(
        'window.reelSync ? window.reelSync.getCurrentTime() : 0',
      );
      final clean = res.toString().replaceAll('"', '').trim();
      return double.tryParse(clean) ?? 0.0;
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
    _driftTimer?.cancel();
    _heartbeatTimer?.cancel();
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
