import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rov_coach/providers/room_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _syncClientIdKey = 'vod_sync_client_id';
const _uuid = Uuid();

class VodSyncState {
  final String videoUrl;
  final bool isPlaying;
  final double position;
  final String updatedBy;
  final DateTime? updatedAt;

  const VodSyncState({
    required this.videoUrl,
    required this.isPlaying,
    required this.position,
    required this.updatedBy,
    required this.updatedAt,
  });

  factory VodSyncState.fromJson(Map<String, dynamic> json) {
    final ts = json['updatedAt'];
    return VodSyncState(
      videoUrl: (json['videoUrl'] as String?) ?? '',
      isPlaying: (json['isPlaying'] as bool?) ?? false,
      position: (json['position'] as num?)?.toDouble() ?? 0,
      updatedBy: (json['updatedBy'] as String?) ?? '',
      updatedAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

final vodSyncClientIdProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(_syncClientIdKey);
  if (existing != null && existing.isNotEmpty) return existing;

  final generated = _uuid.v4();
  await prefs.setString(_syncClientIdKey, generated);
  return generated;
});

final vodPlaybackSyncEnabledProvider =
    NotifierProvider<VodPlaybackSyncEnabledNotifier, bool>(
        VodPlaybackSyncEnabledNotifier.new);

class VodPlaybackSyncEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
  void set(bool enabled) => state = enabled;
}

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
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_syncClientIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = _uuid.v4();
    await prefs.setString(_syncClientIdKey, generated);
    return generated;
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

    await doc.set({
      'videoUrl': videoUrl.trim(),
      'isPlaying': isPlaying,
      'position': position,
      'updatedBy': clientId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
