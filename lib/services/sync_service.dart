import 'dart:async';
import '../models/party_room.dart';

abstract class SyncService {
  Stream<PartyRoom?> get roomStream;
  PartyRoom? get currentRoom;
  String get currentUserId;
  String get currentUserName;
  bool get isHost;
  bool get isConnected;
  String get backendType;

  Future<PartyRoom> createRoom({
    required String hostName,
    required String initialUrl,
    String? title,
  });

  Future<PartyRoom?> joinRoom({
    required String roomId,
    required String guestName,
  });

  Future<void> updatePlayback({
    required bool isPlaying,
    required double positionSeconds,
  });

  Future<void> changeReel({
    required String newUrl,
    required String title,
  });

  Future<void> sendReaction({
    required String emoji,
  });

  Future<void> sendChatMessage({
    required String text,
  });

  Future<void> toggleHostOnlyControl(bool hostOnly);

  Future<void> leaveRoom();

  void dispose();
}
