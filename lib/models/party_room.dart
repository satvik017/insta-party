class PartyRoom {
  final String roomId;
  final String hostId;
  final String hostName;
  final String? guestId;
  final String? guestName;
  final String currentReelUrl;
  final String reelTitle;
  final bool isPlaying;
  final double playbackPositionSeconds;
  final int lastActionTimestamp; // Epoch milliseconds
  final String lastActionBy; // userId who triggered last change
  final bool hostOnlyControl;
  final List<PartyChatMessage> messages;
  final List<PartyReaction> activeReactions;

  const PartyRoom({
    required this.roomId,
    required this.hostId,
    required this.hostName,
    this.guestId,
    this.guestName,
    required this.currentReelUrl,
    this.reelTitle = 'Instagram Reel',
    this.isPlaying = true,
    this.playbackPositionSeconds = 0.0,
    required this.lastActionTimestamp,
    required this.lastActionBy,
    this.hostOnlyControl = false,
    this.messages = const [],
    this.activeReactions = const [],
  });

  bool get hasGuest => guestId != null && guestId!.isNotEmpty;

  PartyRoom copyWith({
    String? roomId,
    String? hostId,
    String? hostName,
    String? guestId,
    String? guestName,
    String? currentReelUrl,
    String? reelTitle,
    bool? isPlaying,
    double? playbackPositionSeconds,
    int? lastActionTimestamp,
    String? lastActionBy,
    bool? hostOnlyControl,
    List<PartyChatMessage>? messages,
    List<PartyReaction>? activeReactions,
  }) {
    return PartyRoom(
      roomId: roomId ?? this.roomId,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      guestId: guestId ?? this.guestId,
      guestName: guestName ?? this.guestName,
      currentReelUrl: currentReelUrl ?? this.currentReelUrl,
      reelTitle: reelTitle ?? this.reelTitle,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackPositionSeconds:
          playbackPositionSeconds ?? this.playbackPositionSeconds,
      lastActionTimestamp: lastActionTimestamp ?? this.lastActionTimestamp,
      lastActionBy: lastActionBy ?? this.lastActionBy,
      hostOnlyControl: hostOnlyControl ?? this.hostOnlyControl,
      messages: messages ?? this.messages,
      activeReactions: activeReactions ?? this.activeReactions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'hostId': hostId,
      'hostName': hostName,
      'guestId': guestId,
      'guestName': guestName,
      'currentReelUrl': currentReelUrl,
      'reelTitle': reelTitle,
      'isPlaying': isPlaying,
      'playbackPositionSeconds': playbackPositionSeconds,
      'lastActionTimestamp': lastActionTimestamp,
      'lastActionBy': lastActionBy,
      'hostOnlyControl': hostOnlyControl,
      'messages': messages.map((m) => m.toMap()).toList(),
    };
  }

  factory PartyRoom.fromMap(Map<String, dynamic> map, {String? roomId}) {
    List<PartyChatMessage> msgs = [];
    if (map['messages'] != null) {
      if (map['messages'] is List) {
        msgs = (map['messages'] as List)
            .map((item) => PartyChatMessage.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      } else if (map['messages'] is Map) {
        msgs = (map['messages'] as Map)
            .values
            .map((item) => PartyChatMessage.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }
    }

    return PartyRoom(
      roomId: roomId ?? map['roomId'] ?? '',
      hostId: map['hostId'] ?? '',
      hostName: map['hostName'] ?? 'Host',
      guestId: map['guestId'],
      guestName: map['guestName'],
      currentReelUrl: map['currentReelUrl'] ?? '',
      reelTitle: map['reelTitle'] ?? 'Instagram Reel',
      isPlaying: map['isPlaying'] ?? true,
      playbackPositionSeconds: (map['playbackPositionSeconds'] as num?)?.toDouble() ?? 0.0,
      lastActionTimestamp: (map['lastActionTimestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      lastActionBy: map['lastActionBy'] ?? '',
      hostOnlyControl: map['hostOnlyControl'] ?? false,
      messages: msgs,
    );
  }
}

class PartyChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final int timestamp;

  const PartyChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': timestamp,
    };
  }

  factory PartyChatMessage.fromMap(Map<String, dynamic> map) {
    return PartyChatMessage(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'User',
      text: map['text'] ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class PartyReaction {
  final String id;
  final String emoji;
  final String senderId;
  final String senderName;
  final int timestamp;

  const PartyReaction({
    required this.id,
    required this.emoji,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'emoji': emoji,
      'senderId': senderId,
      'senderName': senderName,
      'timestamp': timestamp,
    };
  }

  factory PartyReaction.fromMap(Map<String, dynamic> map) {
    return PartyReaction(
      id: map['id'] ?? '',
      emoji: map['emoji'] ?? '❤️',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
