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

        const SizedBox(height: 10),

        // Main Synced Playback HUD
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
                    icon: const Icon(Icons.playlist_play_rounded, color: Colors.white),
                    tooltip: 'Change Reel',
                    onPressed: onOpenReelSelector,
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
                    icon: const Icon(Icons.replay_5_rounded, color: Colors.white70, size: 26),
                    onPressed: canControl ? () => onSeekDelta(-5) : null,
                  ),

                  // Synced Play / Pause Button
                  GestureDetector(
                    onTap: canControl ? onTogglePlay : null,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.instaGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.instaRed.withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        room.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),

                  // Forward 5s
                  IconButton(
                    icon: const Icon(Icons.forward_5_rounded, color: Colors.white70, size: 26),
                    onPressed: canControl ? () => onSeekDelta(5) : null,
                  ),

                  // Next Reel Button
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
                    tooltip: 'Next Curated Reel',
                    onPressed: canControl ? onNextReel : null,
                  ),
                ],
              ),

              if (room.hostOnlyControl && !isHost)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    '🔒 Host only control is active',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
