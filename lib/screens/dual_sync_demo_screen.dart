import 'package:flutter/material.dart';
import '../models/party_room.dart';
import '../models/reel_item.dart';
import '../services/simulated_sync_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/synced_insta_webview.dart';
import '../widgets/reaction_overlay.dart';

class DualSyncDemoScreen extends StatefulWidget {
  const DualSyncDemoScreen({super.key});

  @override
  State<DualSyncDemoScreen> createState() => _DualSyncDemoScreenState();
}

class _DualSyncDemoScreenState extends State<DualSyncDemoScreen> {
  late SyncService _hostService;
  late SyncService _guestService;

  PartyRoom? _room;
  bool _isInitialized = false;

  final GlobalKey<SyncedInstaWebviewState> _hostWebviewKey = GlobalKey<SyncedInstaWebviewState>();
  final GlobalKey<SyncedInstaWebviewState> _guestWebviewKey = GlobalKey<SyncedInstaWebviewState>();

  @override
  void initState() {
    super.initState();
    _setupDualSession();
  }

  Future<void> _setupDualSession() async {
    _hostService = SimulatedSyncService(userId: 'user_host_101', userName: 'User 1 (Host)');
    _guestService = SimulatedSyncService(userId: 'user_guest_202', userName: 'User 2 (Guest)');

    final startingReel = ReelItem.defaultCuratedReels.first;
    final createdRoom = await _hostService.createRoom(
      hostName: 'User 1 (Host)',
      initialUrl: startingReel.originalUrl,
      title: startingReel.title,
    );

    await _guestService.joinRoom(
      roomId: createdRoom.roomId,
      guestName: 'User 2 (Guest)',
    );

    // Listen to updates
    _hostService.roomStream.listen((updatedRoom) {
      if (mounted && updatedRoom != null) {
        setState(() {
          _room = updatedRoom;
        });
      }
    });

    setState(() {
      _room = createdRoom;
      _isInitialized = true;
    });
  }

  void _triggerPlayPause() {
    if (_room == null) return;
    final nextState = !_room!.isPlaying;
    _hostService.updatePlayback(
      isPlaying: nextState,
      positionSeconds: _room!.playbackPositionSeconds,
    );
  }

  void _sendEmojiFromUser1(String emoji) {
    _hostService.sendReaction(emoji: emoji);
  }

  void _sendEmojiFromUser2(String emoji) {
    _guestService.sendReaction(emoji: emoji);
  }

  void _nextReel() {
    final reels = ReelItem.defaultCuratedReels;
    final currentIndex = reels.indexWhere((r) => r.originalUrl == _room?.currentReelUrl);
    final next = reels[(currentIndex + 1) % reels.length];
    _hostService.changeReel(newUrl: next.originalUrl, title: next.title);
  }

  @override
  void dispose() {
    _hostService.dispose();
    _guestService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _room == null) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.instaRed),
        ),
      );
    }

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dual Real-Time Sync View', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Simulating 2 Connected Users Simultaneously', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.greenAccent),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sync_rounded, size: 14, color: Colors.greenAccent),
                SizedBox(width: 4),
                Text('Real-time Synced', style: TextStyle(fontSize: 11, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Dual Viewports (Side-by-side or stacked)
          Expanded(
            child: isLandscape
                ? Row(
                    children: [
                      Expanded(child: _buildUserViewport('User 1 (Host)', _hostWebviewKey, 'user_host_101', true)),
                      Container(width: 2, color: AppTheme.border),
                      Expanded(child: _buildUserViewport('User 2 (Guest)', _guestWebviewKey, 'user_guest_202', false)),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(child: _buildUserViewport('User 1 (Host)', _hostWebviewKey, 'user_host_101', true)),
                      Container(height: 2, color: AppTheme.border),
                      Expanded(child: _buildUserViewport('User 2 (Guest)', _guestWebviewKey, 'user_guest_202', false)),
                    ],
                  ),
          ),

          // Synced Shared Controls Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceElevated,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                // Play/Pause button
                ElevatedButton.icon(
                  onPressed: _triggerPlayPause,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.instaRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: Icon(_room!.isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(_room!.isPlaying ? 'Pause Both' : 'Play Both'),
                ),
                const SizedBox(width: 8),

                // Next Reel
                OutlinedButton.icon(
                  onPressed: _nextReel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.skip_next, size: 18),
                  label: const Text('Next Reel'),
                ),
                const Spacer(),

                // Reaction triggers
                IconButton(
                  icon: const Text('❤️', style: TextStyle(fontSize: 22)),
                  onPressed: () => _sendEmojiFromUser1('❤️'),
                  tooltip: 'Send Heart from User 1',
                ),
                IconButton(
                  icon: const Text('🔥', style: TextStyle(fontSize: 22)),
                  onPressed: () => _sendEmojiFromUser2('🔥'),
                  tooltip: 'Send Fire from User 2',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserViewport(
    String label,
    GlobalKey<SyncedInstaWebviewState> key,
    String userId,
    bool isHost,
  ) {
    return Stack(
      children: [
        SyncedInstaWebview(
          key: key,
          reelUrl: _room!.currentReelUrl,
          isPlaying: _room!.isPlaying,
          syncPositionSeconds: _room!.playbackPositionSeconds,
          lastActionTimestamp: _room!.lastActionTimestamp,
          lastActionBy: _room!.lastActionBy,
          currentUserId: userId,
          isHost: isHost,
          onLocalPlaybackChanged: (isPlaying, pos) {
            final service = isHost ? _hostService : _guestService;
            service.updatePlayback(isPlaying: isPlaying, positionSeconds: pos);
          },
        ),

        // Reaction animations overlay
        Positioned.fill(
          child: ReactionOverlay(reactions: _room!.activeReactions),
        ),

        // User label header tag
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isHost ? AppTheme.instaRed : AppTheme.instaOrange),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isHost ? Icons.star_rounded : Icons.person_rounded,
                  size: 14,
                  color: isHost ? AppTheme.instaYellow : Colors.white70,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
