import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/party_room.dart';
import 'sync_service.dart';

/// A static in-memory broadcast bus to simulate real-time room communication
class _SharedRoomBus {
  static final _SharedRoomBus instance = _SharedRoomBus._internal();
  _SharedRoomBus._internal();

  final Map<String, PartyRoom> _rooms = {};
  final Map<String, StreamController<PartyRoom?>> _roomControllers = {};

  Stream<PartyRoom?> getStream(String roomId) {
    if (!_roomControllers.containsKey(roomId)) {
      _roomControllers[roomId] = StreamController<PartyRoom?>.broadcast();
    }
    return _roomControllers[roomId]!.stream;
  }

  PartyRoom? getRoom(String roomId) => _rooms[roomId];

  void setRoom(PartyRoom room) {
    _rooms[room.roomId] = room;
    if (!_roomControllers.containsKey(room.roomId)) {
      _roomControllers[room.roomId] = StreamController<PartyRoom?>.broadcast();
    }
    _roomControllers[room.roomId]!.add(room);
  }

  void removeRoom(String roomId) {
    _rooms.remove(roomId);
    if (_roomControllers.containsKey(roomId)) {
      _roomControllers[roomId]!.add(null);
    }
  }
}

class SimulatedSyncService implements SyncService {
  final _uuid = const Uuid();
  final _roomController = StreamController<PartyRoom?>.broadcast();
  StreamSubscription? _busSubscription;

  PartyRoom? _currentRoom;
  String _userId = '';
  String _userName = '';
  bool _isHost = false;
  bool _isConnected = false;

  SimulatedSyncService({String? userId, String? userName}) {
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
  String get backendType => 'Local Real-time Relay (Direct Sync)';

  void setProfile(String userId, String userName) {
    _userId = userId;
    _userName = userName;
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
      hostOnlyControl: false,
    );

    _SharedRoomBus.instance.setRoom(room);
    _listenToBus(roomId);
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

    final existingRoom = _SharedRoomBus.instance.getRoom(cleanRoomId);
    if (existingRoom == null) {
      return null;
    }

    final updated = existingRoom.copyWith(
      guestId: _userId,
      guestName: guestName,
    );

    _SharedRoomBus.instance.setRoom(updated);
    _listenToBus(cleanRoomId);
    _isConnected = true;
    _currentRoom = updated;
    _roomController.add(updated);
    return updated;
  }

  void _listenToBus(String roomId) {
    _busSubscription?.cancel();
    _busSubscription = _SharedRoomBus.instance.getStream(roomId).listen((room) {
      _currentRoom = room;
      _roomController.add(room);
    });
  }

  @override
  Future<void> updatePlayback({
    required bool isPlaying,
    required double positionSeconds,
  }) async {
    if (_currentRoom == null) return;
    if (_currentRoom!.hostOnlyControl && !_isHost) return;

    final updated = _currentRoom!.copyWith(
      isPlaying: isPlaying,
      playbackPositionSeconds: positionSeconds,
      lastActionTimestamp: DateTime.now().millisecondsSinceEpoch,
      lastActionBy: _userId,
    );

    _SharedRoomBus.instance.setRoom(updated);
  }

  @override
  Future<void> changeReel({
    required String newUrl,
    required String title,
  }) async {
    if (_currentRoom == null) return;
    if (_currentRoom!.hostOnlyControl && !_isHost) return;

    final updated = _currentRoom!.copyWith(
      currentReelUrl: newUrl,
      reelTitle: title,
      playbackPositionSeconds: 0.0,
      isPlaying: true,
      lastActionTimestamp: DateTime.now().millisecondsSinceEpoch,
      lastActionBy: _userId,
    );

    _SharedRoomBus.instance.setRoom(updated);
  }

  @override
  Future<void> sendReaction({required String emoji}) async {
    if (_currentRoom == null) return;
    final reaction = PartyReaction(
      id: _uuid.v4(),
      emoji: emoji,
      senderId: _userId,
      senderName: _userName,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    final currentReactions = List<PartyReaction>.from(_currentRoom!.activeReactions)..add(reaction);
    final updated = _currentRoom!.copyWith(activeReactions: currentReactions);
    _SharedRoomBus.instance.setRoom(updated);
  }

  @override
  Future<void> sendChatMessage({required String text}) async {
    if (_currentRoom == null || text.trim().isEmpty) return;
    final message = PartyChatMessage(
      id: _uuid.v4(),
      senderId: _userId,
      senderName: _userName,
      text: text.trim(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    final currentMessages = List<PartyChatMessage>.from(_currentRoom!.messages)..add(message);
    final updated = _currentRoom!.copyWith(messages: currentMessages);
    _SharedRoomBus.instance.setRoom(updated);
  }

  @override
  Future<void> toggleHostOnlyControl(bool hostOnly) async {
    if (_currentRoom == null || !_isHost) return;
    final updated = _currentRoom!.copyWith(hostOnlyControl: hostOnly);
    _SharedRoomBus.instance.setRoom(updated);
  }

  @override
  Future<void> leaveRoom() async {
    if (_currentRoom != null) {
      if (_isHost) {
        _SharedRoomBus.instance.removeRoom(_currentRoom!.roomId);
      } else {
        final updated = _currentRoom!.copyWith(
          guestId: '',
          guestName: '',
        );
        _SharedRoomBus.instance.setRoom(updated);
      }
    }
    _busSubscription?.cancel();
    _currentRoom = null;
    _isConnected = false;
    _roomController.add(null);
  }

  @override
  void dispose() {
    _busSubscription?.cancel();
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
