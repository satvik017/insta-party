import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../firebase_options.dart';
import '../models/party_room.dart';
import 'sync_service.dart';
import 'firebase_sync_service.dart';
import 'firestore_sync_service.dart';
import 'simulated_sync_service.dart';

enum SyncEngineType {
  firebaseFirestore,
  firebaseRtdb,
  localRelay,
}

class SyncManager extends ChangeNotifier {
  static final SyncManager instance = SyncManager._internal();
  SyncManager._internal();

  late SyncService _service;
  bool _isFirebaseAvailable = false;
  SyncEngineType _engineType = SyncEngineType.firebaseFirestore;
  String _userId = '';
  String _userName = 'Party Guest';

  SyncService get service => _service;
  bool get isFirebaseAvailable => _isFirebaseAvailable;
  SyncEngineType get engineType => _engineType;
  String get userId => _userId;
  String get userName => _userName;
  PartyRoom? get currentRoom => _service.currentRoom;
  Stream<PartyRoom?> get roomStream => _service.roomStream;
  bool get isHost => _service.isHost;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id') ?? const Uuid().v4().substring(0, 8);
    _userName = prefs.getString('user_name') ?? 'ReelFan_${_userId.substring(0, 4)}';
    await prefs.setString('user_id', _userId);
    await prefs.setString('user_name', _userName);

    // Try initializing Firebase. On Android, FirebaseInitProvider may have
    // already initialized it — catch duplicate-app and treat it as success.
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _isFirebaseAvailable = true;
      debugPrint('[SyncManager] Firebase initialized successfully.');
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') {
        // Firebase was already initialized by Android's FirebaseInitProvider
        // This is NOT an error — Firebase IS available.
        _isFirebaseAvailable = true;
        debugPrint('[SyncManager] Firebase already initialized (duplicate-app) — using existing instance.');
      } else {
        debugPrint('[SyncManager] Firebase init failed: ${e.code} — ${e.message}');
        _isFirebaseAvailable = false;
      }
    } catch (e) {
      debugPrint('[SyncManager] Firebase init error: $e');
      _isFirebaseAvailable = false;
    }

    if (_isFirebaseAvailable) {
      // Default to RTDB — its URL is pre-configured in firebase_options.dart
      // and RTDB is typically created when a Firebase project is initialized.
      // Firestore requires manual database creation in the console.
      _engineType = SyncEngineType.firebaseRtdb;
      _service = FirebaseSyncService(userId: _userId, userName: _userName);
    } else {
      _engineType = SyncEngineType.localRelay;
      _service = SimulatedSyncService(userId: _userId, userName: _userName);
    }

    notifyListeners();
  }

  Future<void> updateProfile({required String newName}) async {
    _userName = newName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', newName);

    if (_service is FirestoreSyncService) {
      (_service as FirestoreSyncService).setProfile(_userId, newName);
    } else if (_service is FirebaseSyncService) {
      (_service as FirebaseSyncService).setProfile(_userId, newName);
    } else if (_service is SimulatedSyncService) {
      (_service as SimulatedSyncService).setProfile(_userId, newName);
    }
    notifyListeners();
  }

  void switchEngine(SyncEngineType newType) {
    if ((newType == SyncEngineType.firebaseFirestore ||
            newType == SyncEngineType.firebaseRtdb) &&
        !_isFirebaseAvailable) {
      return;
    }

    _engineType = newType;
    _service.dispose();

    switch (newType) {
      case SyncEngineType.firebaseFirestore:
        _service = FirestoreSyncService(userId: _userId, userName: _userName);
        break;
      case SyncEngineType.firebaseRtdb:
        _service = FirebaseSyncService(userId: _userId, userName: _userName);
        break;
      case SyncEngineType.localRelay:
        _service = SimulatedSyncService(userId: _userId, userName: _userName);
        break;
    }

    notifyListeners();
  }

  Future<PartyRoom> createParty({
    required String initialUrl,
    String? title,
  }) async {
    // Directly call the service — errors (e.g. permission denied) bubble up to UI
    final room = await _service.createRoom(
      hostName: _userName,
      initialUrl: initialUrl,
      title: title,
    );
    notifyListeners();
    return room;
  }

  Future<PartyRoom?> joinParty({required String roomId}) async {
    PartyRoom? room;

    // 1. Try current service
    try {
      room = await _service.joinRoom(roomId: roomId, guestName: _userName);
    } catch (e) {
      debugPrint('Join error on ${_service.backendType}: $e');
    }

    if (room != null) {
      notifyListeners();
      return room;
    }

    // 2. If not found on current service, auto-try other Firebase service
    if (_isFirebaseAvailable) {
      if (_service is! FirestoreSyncService) {
        try {
          debugPrint('Trying Firestore as fallback for joining...');
          final firestoreService =
              FirestoreSyncService(userId: _userId, userName: _userName);
          room = await firestoreService.joinRoom(
              roomId: roomId, guestName: _userName);
          if (room != null) {
            _service.dispose();
            _engineType = SyncEngineType.firebaseFirestore;
            _service = firestoreService;
            notifyListeners();
            return room;
          }
        } catch (e) {
          debugPrint('Firestore fallback error: $e');
        }
      }

      if (_service is! FirebaseSyncService) {
        try {
          debugPrint('Trying Realtime Database as fallback for joining...');
          final rtdbService =
              FirebaseSyncService(userId: _userId, userName: _userName);
          room = await rtdbService.joinRoom(
              roomId: roomId, guestName: _userName);
          if (room != null) {
            _service.dispose();
            _engineType = SyncEngineType.firebaseRtdb;
            _service = rtdbService;
            notifyListeners();
            return room;
          }
        } catch (e) {
          debugPrint('RTDB fallback error: $e');
        }
      }
    }

    // 3. Try Local Relay (for demo on same device/split screen)
    if (_service is! SimulatedSyncService) {
      try {
        final simService =
            SimulatedSyncService(userId: _userId, userName: _userName);
        room = await simService.joinRoom(roomId: roomId, guestName: _userName);
        if (room != null) {
          _service.dispose();
          _engineType = SyncEngineType.localRelay;
          _service = simService;
          notifyListeners();
          return room;
        }
      } catch (_) {}
    }

    notifyListeners();
    return null;
  }

  Future<void> leaveParty() async {
    await _service.leaveRoom();
    notifyListeners();
  }
}
