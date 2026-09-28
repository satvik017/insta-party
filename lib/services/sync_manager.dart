import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../firebase_options.dart';
import '../models/party_room.dart';
import 'sync_service.dart';
import 'firebase_sync_service.dart';
import 'simulated_sync_service.dart';

class SyncManager extends ChangeNotifier {
  static final SyncManager instance = SyncManager._internal();
  SyncManager._internal();

  late SyncService _service;
  bool _isFirebaseAvailable = false;
  bool _useFirebase = true;
  String _userId = '';
  String _userName = 'Party Guest';

  SyncService get service => _service;
  bool get isFirebaseAvailable => _isFirebaseAvailable;
  bool get useFirebase => _useFirebase;
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

    // Try detecting Firebase with project options
    try {
      if (Firebase.apps.isNotEmpty) {
        _isFirebaseAvailable = true;
      } else {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        _isFirebaseAvailable = true;
      }
    } catch (e) {
      debugPrint('Firebase initialization note: $e');
      _isFirebaseAvailable = false;
    }

    if (_isFirebaseAvailable && _useFirebase) {
      _service = FirebaseSyncService(userId: _userId, userName: _userName);
    } else {
      _service = SimulatedSyncService(userId: _userId, userName: _userName);
    }

    notifyListeners();
  }

  Future<void> updateProfile({required String newName}) async {
    _userName = newName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', newName);

    if (_service is FirebaseSyncService) {
      (_service as FirebaseSyncService).setProfile(_userId, newName);
    } else if (_service is SimulatedSyncService) {
      (_service as SimulatedSyncService).setProfile(_userId, newName);
    }
    notifyListeners();
  }

  void switchBackend({required bool useFirebase}) {
    if (useFirebase && !_isFirebaseAvailable) {
      return; // Cannot switch if Firebase not initialized
    }
    _useFirebase = useFirebase;
    _service.dispose();

    if (_useFirebase && _isFirebaseAvailable) {
      _service = FirebaseSyncService(userId: _userId, userName: _userName);
    } else {
      _service = SimulatedSyncService(userId: _userId, userName: _userName);
    }
    notifyListeners();
  }

  Future<PartyRoom> createParty({
    required String initialUrl,
    String? title,
  }) async {
    final room = await _service.createRoom(
      hostName: _userName,
      initialUrl: initialUrl,
      title: title,
    );
    notifyListeners();
    return room;
  }

  Future<PartyRoom?> joinParty({required String roomId}) async {
    final room = await _service.joinRoom(
      roomId: roomId,
      guestName: _userName,
    );
    notifyListeners();
    return room;
  }

  Future<void> leaveParty() async {
    await _service.leaveRoom();
    notifyListeners();
  }
}
