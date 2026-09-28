import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import '../models/party_room.dart';
import 'sync_service.dart';

class FirebaseSyncService implements SyncService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final _uuid = const Uuid();

  final _roomController = StreamController<PartyRoom?>.broadcast();
  StreamSubscription<DatabaseEvent>? _roomSubscription;

  PartyRoom? _currentRoom;
  String _userId = '';
  String _userName = '';
  bool _isHost = false;
  bool _isConnected = false;

  FirebaseSyncService({String? userId, String? userName}) {
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
  String get backendType => 'Firebase Realtime Database';

  void setProfile(String userId, String userName) {
    _userId = userId;
    _userName = userName;
  }

  DatabaseReference _roomRef(String roomId) => _database.ref('party_rooms/$roomId');

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
      hostOnlyControl: false,
    );

    final ref = _roomRef(roomId);
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
    final cleanRoomId = roomId.trim().toUpperCase();

    final ref = _roomRef(cleanRoomId);
    final snapshot = await ref.get();

    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }

    final rawData = snapshot.value;
    if (rawData is! Map) return null;

    final data = Map<String, dynamic>.from(rawData);
    var room = PartyRoom.fromMap(data, roomId: cleanRoomId);

    // Register guest in the room
    await ref.update({
      'guestId': _userId,
      'guestName': guestName,
    });

    room = room.copyWith(guestId: _userId, guestName: guestName);
    _subscribeToRoom(cleanRoomId);
    _isConnected = true;
    _currentRoom = room;
    _roomController.add(room);
    return room;
  }

  void _subscribeToRoom(String roomId) {
    _roomSubscription?.cancel();
    _roomSubscription = _roomRef(roomId).onValue.listen((event) {
      if (event.snapshot.value == null) {
        _currentRoom = null;
        _roomController.add(null);
        return;
      }

      try {
        final rawData = event.snapshot.value;
        if (rawData is Map) {
          final data = Map<String, dynamic>.from(rawData);
          final updatedRoom = PartyRoom.fromMap(data, roomId: roomId);
          _currentRoom = updatedRoom;
          _roomController.add(updatedRoom);
        }
      } catch (e) {
        // Safe parse fallback
      }
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
    final ref = _roomRef(_currentRoom!.roomId).child('reactions');
    final reaction = PartyReaction(
      id: _uuid.v4(),
      emoji: emoji,
      senderId: _userId,
      senderName: _userName,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await ref.push().set(reaction.toMap());
  }

  @override
  Future<void> sendChatMessage({required String text}) async {
    if (_currentRoom == null || text.trim().isEmpty) return;
    final ref = _roomRef(_currentRoom!.roomId).child('messages');
    final message = PartyChatMessage(
      id: _uuid.v4(),
      senderId: _userId,
      senderName: _userName,
      text: text.trim(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await ref.push().set(message.toMap());
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
        // If host leaves, can archive or delete room
        await _roomRef(_currentRoom!.roomId).remove();
      } else {
        // If guest leaves, clear guestId
        await _roomRef(_currentRoom!.roomId).update({
          'guestId': null,
          'guestName': null,
        });
      }
    }
    _roomSubscription?.cancel();
    _currentRoom = null;
    _isConnected = false;
    _roomController.add(null);
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
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
