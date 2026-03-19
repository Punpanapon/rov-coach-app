import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rov_coach/providers/room_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _syncClientIdKey = 'vod_sync_client_id';
const _syncClientNameKey = 'vod_sync_client_name';
const _uuid = Uuid();
String? _fallbackClientId;
String? _fallbackClientName;

Future<SharedPreferences?> _safePrefs() async {
  try {
    return await SharedPreferences.getInstance();
  } on MissingPluginException {
    return null;
  } catch (_) {
    return null;
  }
}

class VodSyncState {
  final String videoUrl;
  final bool isPlaying;
  final double position;
  final String hostId;
  final String hostName;
  final int timestamp;
  final String updatedBy;
  final DateTime? updatedAt;

  const VodSyncState({
    required this.videoUrl,
    required this.isPlaying,
    required this.position,
    required this.hostId,
    required this.hostName,
    required this.timestamp,
    required this.updatedBy,
    required this.updatedAt,
  });

  bool get hasHost => hostId.trim().isNotEmpty;

  factory VodSyncState.fromJson(Map<String, dynamic> json) {
    final ts = json['updatedAt'];
    final rawTimestamp = json['timestamp'];
    return VodSyncState(
      videoUrl: (json['videoUrl'] as String?) ?? '',
      isPlaying: (json['isPlaying'] as bool?) ?? false,
      position: (json['position'] as num?)?.toDouble() ?? 0,
      hostId: (json['hostId'] as String?) ?? '',
      hostName: (json['hostName'] as String?) ?? '',
      timestamp: rawTimestamp is Timestamp
          ? rawTimestamp.millisecondsSinceEpoch
          : (rawTimestamp as num?)?.toInt() ?? 0,
      updatedBy: (json['updatedBy'] as String?) ?? '',
      updatedAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

class VodSyncRole {
  final bool isHost;
  final bool isClient;
  final String hostId;
  final String hostName;

  const VodSyncRole({
    required this.isHost,
    required this.isClient,
    required this.hostId,
    required this.hostName,
  });

  bool get hasHost => hostId.trim().isNotEmpty;
}

final vodSyncClientIdProvider = FutureProvider<String>((ref) async {
  final prefs = await _safePrefs();
  if (prefs != null) {
    final existing = prefs.getString(_syncClientIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = _uuid.v4();
    await prefs.setString(_syncClientIdKey, generated);
    return generated;
  }

  _fallbackClientId ??= _uuid.v4();
  return _fallbackClientId!;
});

final vodSyncClientNameProvider = FutureProvider<String>((ref) async {
  final prefs = await _safePrefs();
  if (prefs != null) {
    final existing = prefs.getString(_syncClientNameKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final clientId = await ref.watch(vodSyncClientIdProvider.future);
    final generated = 'Coach-${clientId.substring(0, 4)}';
    await prefs.setString(_syncClientNameKey, generated);
    return generated;
  }

  if (_fallbackClientName != null) return _fallbackClientName!;
  final clientId = await ref.watch(vodSyncClientIdProvider.future);
  _fallbackClientName = 'Coach-${clientId.substring(0, 4)}';
  return _fallbackClientName!;
});

final vodSyncRoleProvider = Provider<VodSyncRole>((ref) {
  final localId = ref.watch(vodSyncClientIdProvider).asData?.value;
  final sync = ref.watch(vodSyncProvider).asData?.value;

  final hostId = sync?.hostId ?? '';
  final hostName = sync?.hostName ?? '';
  final isHost = localId != null && hostId.isNotEmpty && hostId == localId;
  final isClient = localId != null && hostId.isNotEmpty && hostId != localId;

  return VodSyncRole(
    isHost: isHost,
    isClient: isClient,
    hostId: hostId,
    hostName: hostName,
  );
});

final vodSyncProvider = StreamProvider<VodSyncState?>((ref) {
  final roomId = ref.watch(roomIdProvider);
  if (roomId == null || roomId.isEmpty) return Stream.value(null);

  // Singleton sync document under rooms/{roomId}/vod_sync/state.
  return FirebaseFirestore.instance
      .collection('rooms')
      .doc(roomId)
      .collection('vod_sync')
      .doc('state')
      .snapshots()
      .map((snap) {
    final data = snap.data();
    if (data == null) return null;
    return VodSyncState.fromJson(data);
  });
});

final vodSyncControllerProvider =
    NotifierProvider<VodSyncController, void>(VodSyncController.new);

class VodSyncController extends Notifier<void> {
  @override
  void build() {}

  Future<String> _ensureClientId() async {
    final prefs = await _safePrefs();
    if (prefs != null) {
      final existing = prefs.getString(_syncClientIdKey);
      if (existing != null && existing.isNotEmpty) return existing;

      final generated = _uuid.v4();
      await prefs.setString(_syncClientIdKey, generated);
      return generated;
    }

    _fallbackClientId ??= _uuid.v4();
    return _fallbackClientId!;
  }

  DocumentReference<Map<String, dynamic>>? _syncDoc() {
    final roomId = ref.read(roomIdProvider);
    if (roomId == null || roomId.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('vod_sync')
        .doc('state');
  }

  Future<void> broadcastState({
    required String videoUrl,
    required bool isPlaying,
    required double position,
  }) async {
    final doc = _syncDoc();
    if (doc == null || videoUrl.trim().isEmpty) return;
    final clientId = await _ensureClientId();
    final snap = await doc.get();
    final data = snap.data();
    final hostId = (data?['hostId'] as String?) ?? '';
    if (hostId.isEmpty || hostId != clientId) return;

    await doc.set({
      'videoUrl': videoUrl.trim(),
      'isPlaying': isPlaying,
      'position': position,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'updatedBy': clientId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> startHosting({
    required String videoUrl,
    required bool isPlaying,
    required double position,
  }) async {
    final doc = _syncDoc();
    if (doc == null || videoUrl.trim().isEmpty) return;

    final clientId = await _ensureClientId();
    final clientName = await ref.read(vodSyncClientNameProvider.future);
    final snap = await doc.get();
    final data = snap.data();
    final currentHostId = (data?['hostId'] as String?) ?? '';

    if (currentHostId.isNotEmpty && currentHostId != clientId) {
      final currentHostName = (data?['hostName'] as String?) ?? 'another host';
      throw StateError('Hosting is already active by $currentHostName');
    }

    await doc.set({
      'hostId': clientId,
      'hostName': clientName,
      'videoUrl': videoUrl.trim(),
      'isPlaying': isPlaying,
      'position': position,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'updatedBy': clientId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> stopHosting() async {
    final doc = _syncDoc();
    if (doc == null) return;

    final clientId = await _ensureClientId();
    final snap = await doc.get();
    final data = snap.data();
    final currentHostId = (data?['hostId'] as String?) ?? '';
    if (currentHostId != clientId) {
      throw StateError('Only the active host can stop hosting');
    }

    await doc.set({
      'hostId': '',
      'hostName': '',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'updatedBy': clientId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
