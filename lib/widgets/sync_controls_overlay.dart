import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/party_room.dart';
import '../theme/app_theme.dart';

class SyncControlsOverlay extends StatelessWidget {
  final PartyRoom room;
  final String currentUserId;
  final bool isHost;
  final VoidCallback onTogglePlay;
  final Function(double delta) onSeekDelta;
  final VoidCallback onNextReel;
  final VoidCallback onOpenReelSelector;
  final VoidCallback onOpenChat;
  final Function(String emoji) onSendReaction;
  final VoidCallback onForceSync;

  const SyncControlsOverlay({
    super.key,
    required this.room,
    required this.currentUserId,
    required this.isHost,
    required this.onTogglePlay,
    required this.onSeekDelta,
    required this.onNextReel,
    required this.onOpenReelSelector,
    required this.onOpenChat,
    required this.onSendReaction,
    required this.onForceSync,
  });

  bool get canControl => !room.hostOnlyControl || isHost;

  @override
  Widget build(BuildContext context) {
    final hasPartner = room.hasGuest;
    final partnerName = isHost ? (room.guestName ?? 'Guest') : room.hostName;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top status pill & Room code
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Partner status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: hasPartner ? Colors.green.withOpacity(0.5) : Colors.orange.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasPartner ? Colors.greenAccent : Colors.orangeAccent,
                        boxShadow: [
                          BoxShadow(
                            color: (hasPartner ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.6),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasPartner
                          ? '$partnerName (Synced)'
                          : 'Waiting for friend...',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Room code pill with copy action
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: room.roomId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Room Code ${room.roomId} copied! Share it with your friend.'),
                      backgroundColor: AppTheme.surfaceElevated,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.share_rounded, size: 13, color: AppTheme.instaYellow),
                      const SizedBox(width: 6),
                      Text(
                        room.roomId,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy_rounded, size: 12, color: Colors.white54),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Emoji Reaction Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['❤️', '🔥', '😂', '😮', '👏'].map((emoji) {
                return GestureDetector(
                  onTap: () => onSendReaction(emoji),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // SYNC NOW button — forces both users to realign playback
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: onForceSync,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C6FF), Color(0xFF7B2FF7)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7B2FF7).withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sync_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'SYNC NOW',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reel Title and Action By Indicator
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.reelTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          room.isPlaying ? '▶ In Sync Playback' : '⏸ Synced Pause',
                          style: TextStyle(
                            fontSize: 11,
                            color: room.isPlaying ? Colors.greenAccent : AppTheme.instaYellow,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Open Reels Library
                  IconButton(
                    icon: Icon(
                      Icons.playlist_play_rounded,
                      color: canControl ? Colors.white : Colors.white38,
                    ),
                    tooltip: canControl ? 'Change Reel' : 'Host controls reel selection',
                    onPressed: canControl ? onOpenReelSelector : () => _showHostNotice(context),
                  ),

                  // Open Chat
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
                        tooltip: 'Watch Party Chat',
                        onPressed: onOpenChat,
                      ),
                      if (room.messages.isNotEmpty)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.instaGradient,
                            ),
                            child: Text(
                              '${room.messages.length}',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Control buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Rewind 5s
                  IconButton(
                    icon: Icon(Icons.replay_5_rounded, color: canControl ? Colors.white70 : Colors.white24, size: 26),
                    onPressed: canControl ? () => onSeekDelta(-5) : () => _showHostNotice(context),
                  ),

                  // Synced Play / Pause Button
                  GestureDetector(
                    onTap: canControl ? onTogglePlay : () => _showHostNotice(context),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: canControl
                            ? AppTheme.instaGradient
                            : const LinearGradient(colors: [Colors.grey, Colors.blueGrey]),
                        boxShadow: [
                          BoxShadow(
                            color: (canControl ? AppTheme.instaRed : Colors.black).withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        room.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: canControl ? Colors.white : Colors.white70,
                        size: 32,
                      ),
                    ),
                  ),

                  // Forward 5s
                  IconButton(
                    icon: Icon(Icons.forward_5_rounded, color: canControl ? Colors.white70 : Colors.white24, size: 26),
                    onPressed: canControl ? () => onSeekDelta(5) : () => _showHostNotice(context),
                  ),

                  // Next Reel Button
                  IconButton(
                    icon: Icon(Icons.skip_next_rounded, color: canControl ? Colors.white : Colors.white24, size: 28),
                    tooltip: canControl ? 'Next Curated Reel' : 'Host controls playback',
                    onPressed: canControl ? onNextReel : () => _showHostNotice(context),
                  ),
                ],
              ),

              if (room.hostOnlyControl && !isHost)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 12, color: AppTheme.instaYellow),
                      SizedBox(width: 6),
                      Text(
                        'Host-Only Control Active (Host leads the watch party)',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.instaYellow,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showHostNotice(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.lock_rounded, color: AppTheme.instaYellow, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text('Host-only control is active. Only the room creator can control playback.'),
            ),
          ],
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
