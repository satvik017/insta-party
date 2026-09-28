import 'dart:math';
import 'package:flutter/material.dart';
import '../models/party_room.dart';

class ReactionOverlay extends StatefulWidget {
  final List<PartyReaction> reactions;

  const ReactionOverlay({
    super.key,
    required this.reactions,
  });

  @override
  State<ReactionOverlay> createState() => _ReactionOverlayState();
}

class _ReactionOverlayState extends State<ReactionOverlay>
    with TickerProviderStateMixin {
  final List<_ActiveFloatingEmoji> _activeEmojis = [];
  final Set<String> _seenReactionIds = {};

  @override
  void didUpdateWidget(covariant ReactionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final reaction in widget.reactions) {
      if (!_seenReactionIds.contains(reaction.id)) {
        _seenReactionIds.add(reaction.id);
        _spawnEmoji(reaction);
      }
    }
  }

  void _spawnEmoji(PartyReaction reaction) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    final random = Random();
    final startX = 0.3 + (random.nextDouble() * 0.4); // Centered scatter
    final curveDrift = (random.nextDouble() - 0.5) * 0.2;

    final item = _ActiveFloatingEmoji(
      id: reaction.id,
      emoji: reaction.emoji,
      senderName: reaction.senderName,
      startX: startX,
      curveDrift: curveDrift,
      controller: controller,
    );

    setState(() {
      _activeEmojis.add(item);
    });

    controller.forward().then((_) {
      if (mounted) {
        setState(() {
          _activeEmojis.remove(item);
          controller.dispose();
        });
      }
    });
  }

  @override
  void dispose() {
    for (var item in _activeEmojis) {
      item.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_activeEmojis.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: Stack(
        children: _activeEmojis.map((item) {
          return AnimatedBuilder(
            animation: item.controller,
            builder: (context, child) {
              final progress = item.controller.value;
              final y = 1.0 - (progress * 0.85); // Float upwards
              final x = item.startX + (sin(progress * pi * 2) * item.curveDrift);
              final opacity = progress < 0.2
                  ? (progress / 0.2)
                  : progress > 0.7
                      ? (1.0 - progress) / 0.3
                      : 1.0;
              final scale = 0.8 + (sin(progress * pi) * 0.5);

              return Align(
                alignment: FractionalOffset(x.clamp(0.05, 0.95), y.clamp(0.0, 1.0)),
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.emoji,
                          style: const TextStyle(fontSize: 38),
                        ),
                        if (item.senderName.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.senderName,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}

class _ActiveFloatingEmoji {
  final String id;
  final String emoji;
  final String senderName;
  final double startX;
  final double curveDrift;
  final AnimationController controller;

  _ActiveFloatingEmoji({
    required this.id,
    required this.emoji,
    required this.senderName,
    required this.startX,
    required this.curveDrift,
    required this.controller,
  });
}
