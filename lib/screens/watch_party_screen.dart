import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/party_room.dart';
import '../models/reel_item.dart';
import '../services/sync_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/synced_insta_webview.dart';
import '../widgets/reaction_overlay.dart';
import '../widgets/party_chat_sheet.dart';
import '../widgets/reel_selector_sheet.dart';
import '../widgets/sync_controls_overlay.dart';

class WatchPartyScreen extends StatefulWidget {
  final PartyRoom initialRoom;

  const WatchPartyScreen({
    super.key,
    required this.initialRoom,
  });

  @override
  State<WatchPartyScreen> createState() => _WatchPartyScreenState();
}

class _WatchPartyScreenState extends State<WatchPartyScreen> {
  final GlobalKey<SyncedInstaWebviewState> _webviewKey = GlobalKey<SyncedInstaWebviewState>();
  late PartyRoom _room;
  bool _showControls = true;
  int _currentCuratedIndex = 0;

  @override
  void initState() {
    super.initState();
    _room = widget.initialRoom;

    // Set immersive orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  bool get _canControl => SyncManager.instance.isHost || !_room.hostOnlyControl;

  void _showHostOnlyNotice() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.lock_rounded, color: AppTheme.instaYellow, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text('Only the host can control playback & change reels'),
            ),
          ],
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleLocalPlaybackChanged(bool isPlaying, double position) {
    if (!_canControl) return;
    SyncManager.instance.service.updatePlayback(
      isPlaying: isPlaying,
      positionSeconds: position,
    );
  }

  void _forceSync() async {
    if (!_canControl) {
      _webviewKey.currentState?.forceSync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.sync_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Re-aligning playback with host...'),
              ],
            ),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final visibleCode = await _webviewKey.currentState?.detectAndSyncVisiblePost();
    if (visibleCode != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.share_rounded, color: Colors.greenAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Broadcasting post to partner: $visibleCode'),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      _webviewKey.currentState?.forceSync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.sync_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Aligning playback with partner...'),
              ],
            ),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _togglePlayPause() {
    if (!_canControl) {
      _showHostOnlyNotice();
      return;
    }
    final nextState = !_room.isPlaying;
    if (nextState) {
      _webviewKey.currentState?.triggerPlay();
    } else {
      _webviewKey.currentState?.triggerPause();
    }
  }

  void _seekDelta(double delta) async {
    if (!_canControl) {
      _showHostOnlyNotice();
      return;
    }
    final currentTime = await _webviewKey.currentState?.getCurrentVideoTime() ?? 0.0;
    final newTime = (currentTime + delta).clamp(0.0, 9999.0);
    _webviewKey.currentState?.triggerSeek(newTime);
  }

  void _handleWebviewReelChanged(String newUrl, String title) {
    if (!_canControl) {
      debugPrint('[WatchParty] Non-host attempted reel change; suppressed.');
      return;
    }
    if (newUrl != _room.currentReelUrl) {
      debugPrint('[WatchParty] Webview changed reel to $newUrl');
      SyncManager.instance.service.changeReel(
        newUrl: newUrl,
        title: title,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Synced reel with partner!',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _syncCurrentPage() async {
    if (!_canControl) {
      _webviewKey.currentState?.forceSync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.sync_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Re-aligning with host reel...'),
              ],
            ),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final syncedUrl = await _webviewKey.currentState?.syncCurrentPageToPartner();
    if (mounted && syncedUrl != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Broadcasting page to partner...', overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _nextCuratedReel() {
    if (!_canControl) {
      _showHostOnlyNotice();
      return;
    }
    final reels = ReelItem.defaultCuratedReels;
    _currentCuratedIndex = (_currentCuratedIndex + 1) % reels.length;
    final nextReel = reels[_currentCuratedIndex];
    SyncManager.instance.service.changeReel(
      newUrl: nextReel.originalUrl,
      title: nextReel.title,
    );
  }

  void _openReelSelector() {
    if (!_canControl) {
      _showHostOnlyNotice();
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReelSelectorSheet(
        currentReelUrl: _room.currentReelUrl,
        onSelectReel: (newUrl, title) {
          SyncManager.instance.service.changeReel(
            newUrl: newUrl,
            title: title,
          );
        },
      ),
    );
  }

  void _openChatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PartyChatSheet(
        messages: _room.messages,
        currentUserId: SyncManager.instance.userId,
        onSendMessage: (text) {
          SyncManager.instance.service.sendChatMessage(text: text);
        },
      ),
    );
  }

  void _sendReaction(String emoji) {
    SyncManager.instance.service.sendReaction(emoji: emoji);
  }

  void _showRoomDetailsModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            ShaderMask(
              shaderCallback: (b) => AppTheme.instaGradient.createShader(b),
              child: const Icon(Icons.celebration_rounded, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('Party Details', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Room Code', _room.roomId, isCode: true),
            const SizedBox(height: 12),
            _detailRow('Host', _room.hostName),
            const SizedBox(height: 8),
            _detailRow('Guest', _room.guestName ?? 'Waiting to join...'),
            const SizedBox(height: 8),
            _detailRow('Sync Engine', SyncManager.instance.service.backendType),
            const Divider(color: AppTheme.border, height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.sync_alt_rounded, size: 16),
                label: const Text('Sync Current Page to Party', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.instaRed,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _syncCurrentPage();
                },
              ),
            ),
            if (SyncManager.instance.isHost) ...[
              const Divider(color: AppTheme.border, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Host Only Control', style: TextStyle(color: Colors.white, fontSize: 13)),
                  Switch(
                    value: _room.hostOnlyControl,
                    activeTrackColor: AppTheme.instaRed,
                    onChanged: (val) {
                      SyncManager.instance.service.toggleHostOnlyControl(val);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _room.roomId));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Room code copied!')),
              );
            },
            child: const Text('Copy Code', style: TextStyle(color: AppTheme.instaOrange)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isCode = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: isCode ? AppTheme.instaYellow : Colors.white,
            fontWeight: isCode ? FontWeight.bold : FontWeight.w500,
            fontSize: isCode ? 15 : 13,
          ),
        ),
      ],
    );
  }

  Future<void> _leaveParty() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave Watch Party?'),
        content: Text(
          SyncManager.instance.isHost
              ? 'As host, leaving will close the room for both users.'
              : 'You will exit the synchronized watch party.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.instaRed),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await SyncManager.instance.leaveParty();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PartyRoom?>(
      stream: SyncManager.instance.roomStream,
      initialData: _room,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          _room = snapshot.data!;
        } else if (snapshot.connectionState == ConnectionState.active && snapshot.data == null) {
          // Room was terminated
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Watch party ended by host')),
              );
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          });
        }

        final isHost = SyncManager.instance.isHost;

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: SafeArea(
            child: Stack(
              children: [
                // Layer 1: In-App Instagram Reel Synced WebView
                Positioned.fill(
                  bottom: _showControls ? 140 : 0,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showControls = !_showControls;
                      });
                    },
                    child: SyncedInstaWebview(
                      key: _webviewKey,
                      reelUrl: _room.currentReelUrl,
                      isPlaying: _room.isPlaying,
                      syncPositionSeconds: _room.playbackPositionSeconds,
                      lastActionTimestamp: _room.lastActionTimestamp,
                      lastActionBy: _room.lastActionBy,
                      currentUserId: SyncManager.instance.userId,
                      isHost: isHost,
                      canControl: _canControl,
                      onLocalPlaybackChanged: _handleLocalPlaybackChanged,
                      onReelChanged: _handleWebviewReelChanged,
                    ),
                  ),
                ),

                // Layer 2: Floating Animated Emoji Burst Reactions
                Positioned.fill(
                  child: ReactionOverlay(
                    reactions: _room.activeReactions,
                  ),
                ),

                // Layer 3: Top Navigation Bar
                Positioned(
                  top: 8,
                  left: 12,
                  right: 12,
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back / Leave button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                            onPressed: _leaveParty,
                          ),
                        ),

                        // Party Room Title Banner
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ShaderMask(
                                shaderCallback: (b) => AppTheme.instaGradient.createShader(b),
                                child: const Icon(Icons.live_tv_rounded, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isHost ? 'Host View' : 'Guest View',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Actions: Quick Sync + Details / Settings
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white12),
                              ),
                              child: IconButton(
                                tooltip: 'Sync this page with partner',
                                icon: const Icon(Icons.sync_alt_rounded, color: AppTheme.instaYellow, size: 18),
                                onPressed: _syncCurrentPage,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white12),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                                onPressed: _showRoomDetailsModal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Layer 4: Synced Playback & Reaction HUD
                if (_showControls)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SyncControlsOverlay(
                      room: _room,
                      currentUserId: SyncManager.instance.userId,
                      isHost: isHost,
                      onTogglePlay: _togglePlayPause,
                      onSeekDelta: _seekDelta,
                      onNextReel: _nextCuratedReel,
                      onOpenReelSelector: _openReelSelector,
                      onOpenChat: _openChatSheet,
                      onSendReaction: _sendReaction,
                      onForceSync: _forceSync,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
