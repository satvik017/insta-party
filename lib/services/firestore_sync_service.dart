import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/party_room.dart';
import 'sync_service.dart';

class FirestoreSyncService implements SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  final _roomController = StreamController<PartyRoom?>.broadcast();
  StreamSubscription<DocumentSnapshot>? _roomSubscription;
  StreamSubscription<QuerySnapshot>? _chatSubscription;
  StreamSubscription<QuerySnapshot>? _reactionSubscription;

  PartyRoom? _currentRoom;
  String _userId = '';
  String _userName = '';
  bool _isHost = false;
  bool _isConnected = false;

  FirestoreSyncService({String? userId, String? userName}) {
    _userId = userId ?? 'user_${DateTime.now().millisecondsSinceEpoch % 10000}';
    _userName = userName ?? 'PartyUser';
  }

  @override
  Stream<PartyRoom?> get roomStream => _roomController.stream;

  @override
  PartyRoom? get currentRoom => _currentRoom;

  @override
  String get currentUserId => _userId;

  @override
  String get currentUserName => _userName;

  @override
  bool get isHost => _isHost;

  @override
  bool get isConnected => _isConnected;

  @override
  String get backendType => 'Firebase Cloud Firestore';

  void setProfile(String userId, String userName) {
    _userId = userId;
    _userName = userName;
  }

  DocumentReference _roomRef(String roomId) =>
      _firestore.collection('party_rooms').doc(roomId);

  static String normalizeCode(String code) {
    final clean = code.trim().toUpperCase();
    if (!clean.startsWith('SYNC-')) {
      return 'SYNC-$clean';
    }
    return clean;
  }

  @override
  Future<PartyRoom> createRoom({
    required String hostName,
    required String initialUrl,
    String? title,
  }) async {
    _userName = hostName;
    _isHost = true;
    final roomId = _generateRoomCode();

    final room = PartyRoom(
      roomId: roomId,
      hostId: _userId,
      hostName: hostName,
      currentReelUrl: initialUrl,
      reelTitle: title ?? 'Instagram Reel',
      isPlaying: true,
      playbackPositionSeconds: 0.0,
      lastActionTimestamp: DateTime.now().millisecondsSinceEpoch,
      lastActionBy: _userId,
      hostOnlyControl: true,
    );

    final ref = _roomRef(roomId);

    // Write room to Firestore — will throw if rules block write or DB not created
    await ref.set(room.toMap());

    _subscribeToRoom(roomId);
    _isConnected = true;
    _currentRoom = room;
    _roomController.add(room);
    return room;
  }

  @override
  Future<PartyRoom?> joinRoom({
    required String roomId,
    required String guestName,
  }) async {
    _userName = guestName;
    _isHost = false;

    // Try exact code first, then with SYNC- prefix, then without prefix
    final candidates = [
      roomId.trim().toUpperCase(),
      normalizeCode(roomId),
    ];

    for (final targetId in candidates.toSet().toList()) {
      try {
        final doc = await _roomRef(targetId)
            .get(const GetOptions(source: Source.server));

        if (!doc.exists || doc.data() == null) continue;

        final data = Map<String, dynamic>.from(doc.data() as Map);
        var room = PartyRoom.fromMap(data, roomId: targetId);

        // Register this user as guest
        await _roomRef(targetId).update({
          'guestId': _userId,
          'guestName': guestName,
        });

        room = room.copyWith(guestId: _userId, guestName: guestName);
        _subscribeToRoom(targetId);
        _isConnected = true;
        _currentRoom = room;
        _roomController.add(room);
        return room;
      } catch (e) {
        // Re-throw permission errors so they're visible to user
        if (e.toString().contains('PERMISSION_DENIED') ||
            e.toString().contains('permission-denied')) {
          throw Exception(
            'Firebase Firestore permission denied.\n'
            'Go to Firebase Console > Firestore > Rules and set:\n'
            '  allow read, write: if true;\n'
            'Then click Publish.',
          );
        }
        // For other errors, continue trying next candidate
      }
    }

    return null;
  }

  void _subscribeToRoom(String roomId) {
    _roomSubscription?.cancel();
    _chatSubscription?.cancel();
    _reactionSubscription?.cancel();

    _roomSubscription = _roomRef(roomId).snapshots().listen((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        _currentRoom = null;
        _roomController.add(null);
        return;
      }

      try {
        final data = Map<String, dynamic>.from(snapshot.data() as Map);
        final updatedRoom = PartyRoom.fromMap(data, roomId: roomId);

        // Keep active local messages and reactions if subcollection hasn't fired yet
        final currentMessages = _currentRoom?.messages ?? [];
        final currentReactions = _currentRoom?.activeReactions ?? [];

        _currentRoom = updatedRoom.copyWith(
          messages: updatedRoom.messages.isNotEmpty ? updatedRoom.messages : currentMessages,
          activeReactions: currentReactions,
        );
        _roomController.add(_currentRoom);
      } catch (e) {
        // Safe fallback
      }
    });

    // Listen to messages subcollection
    _chatSubscription = _roomRef(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((query) {
      if (_currentRoom == null) return;
      final msgs = query.docs
          .map((d) => PartyChatMessage.fromMap(d.data()))
          .toList();
      _currentRoom = _currentRoom!.copyWith(messages: msgs);
      _roomController.add(_currentRoom);
    });

    // Listen to reactions subcollection
    _reactionSubscription = _roomRef(roomId)
        .collection('reactions')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .listen((query) {
      if (_currentRoom == null) return;
      final reactions = query.docs
          .map((d) => PartyReaction.fromMap(d.data()))
          .toList();
      _currentRoom = _currentRoom!.copyWith(activeReactions: reactions);
      _roomController.add(_currentRoom);
    });
  }

  @override
  Future<void> updatePlayback({
    required bool isPlaying,
    required double positionSeconds,
  }) async {
    if (_currentRoom == null) return;
    if (_currentRoom!.hostOnlyControl && !_isHost) return;

    final ref = _roomRef(_currentRoom!.roomId);
    final now = DateTime.now().millisecondsSinceEpoch;

    await ref.update({
      'isPlaying': isPlaying,
      'playbackPositionSeconds': positionSeconds,
      'lastActionTimestamp': now,
      'lastActionBy': _userId,
    });
  }

  @override
  Future<void> changeReel({
    required String newUrl,
    required String title,
  }) async {
    if (_currentRoom == null) return;
    if (_currentRoom!.hostOnlyControl && !_isHost) return;

    final ref = _roomRef(_currentRoom!.roomId);
    final now = DateTime.now().millisecondsSinceEpoch;

    await ref.update({
      'currentReelUrl': newUrl,
      'reelTitle': title,
      'playbackPositionSeconds': 0.0,
      'isPlaying': true,
      'lastActionTimestamp': now,
      'lastActionBy': _userId,
    });
  }

  @override
  Future<void> sendReaction({required String emoji}) async {
    if (_currentRoom == null) return;
    final ref = _roomRef(_currentRoom!.roomId).collection('reactions');
    final reaction = PartyReaction(
      id: _uuid.v4(),
      emoji: emoji,
      senderId: _userId,
      senderName: _userName,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await ref.add(reaction.toMap());
  }

  @override
  Future<void> sendChatMessage({required String text}) async {
    if (_currentRoom == null || text.trim().isEmpty) return;
    final ref = _roomRef(_currentRoom!.roomId).collection('messages');
    final message = PartyChatMessage(
      id: _uuid.v4(),
      senderId: _userId,
      senderName: _userName,
      text: text.trim(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await ref.add(message.toMap());
  }

  @override
  Future<void> toggleHostOnlyControl(bool hostOnly) async {
    if (_currentRoom == null || !_isHost) return;
    final ref = _roomRef(_currentRoom!.roomId);
    await ref.update({'hostOnlyControl': hostOnly});
  }

  @override
  Future<void> leaveRoom() async {
    if (_currentRoom != null) {
      if (_isHost) {
        await _roomRef(_currentRoom!.roomId).delete();
      } else {
        await _roomRef(_currentRoom!.roomId).update({
          'guestId': null,
          'guestName': null,
        });
      }
    }
    _roomSubscription?.cancel();
    _chatSubscription?.cancel();
    _reactionSubscription?.cancel();
    _currentRoom = null;
    _isConnected = false;
    _roomController.add(null);
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _chatSubscription?.cancel();
    _reactionSubscription?.cancel();
    _roomController.close();
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String code = '';
    var temp = random;
    for (int i = 0; i < 4; i++) {
      code += chars[temp % chars.length];
      temp ~/= 10;
    }
    return 'SYNC-$code';
  }
}
