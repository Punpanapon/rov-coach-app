import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rov_coach/data/models/player.dart';
import 'package:rov_coach/data/repositories/player_repository.dart';
import 'package:rov_coach/data/mock_data.dart';
import 'package:rov_coach/providers/room_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton instance of [PlayerRepository].
final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return PlayerRepository();
});

final firebaseFirestoreProvider =
    Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);

const _migratedRosterFlagPrefix = 'hasMigratedRoster';

CollectionReference<Map<String, dynamic>> _rosterCollection(
  FirebaseFirestore firestore,
  String roomId,
) {
  return firestore.collection('rooms').doc(roomId).collection('roster');
}

/// One-time migration from local Hive roster to Firestore room roster.
/// This is safe and idempotent: it skips if already migrated.
Future<void> migrateLocalRosterToFirestore(
  String roomId,
  Ref readRef,
) async {
  if (roomId.trim().isEmpty) return;

  final prefs = await SharedPreferences.getInstance();
  final migratedKey = '${_migratedRosterFlagPrefix}_$roomId';
  final hasMigrated = prefs.getBool(migratedKey) ?? false;
  if (hasMigrated) return;

  final repo = readRef.read(playerRepositoryProvider);
  final firestore = readRef.read(firebaseFirestoreProvider);
  final localPlayers = await repo.getAll();

  final targetCollection = _rosterCollection(firestore, roomId);
  final cloudSnapshot = await targetCollection.limit(1).get();

  // If cloud already has data, trust cloud and just mark migrated.
  if (cloudSnapshot.docs.isNotEmpty) {
    await prefs.setBool(migratedKey, true);
    return;
  }

  // First run: seed local mock data if local storage is empty to preserve behavior.
  final playersToUpload = localPlayers.isEmpty ? MockData.players : localPlayers;

  final batch = firestore.batch();
  for (final player in playersToUpload) {
    final docRef = targetCollection.doc(player.id);
    batch.set(docRef, player.toJson(), SetOptions(merge: true));
  }
  await batch.commit();

  await repo.clearAll();
  await prefs.setBool(migratedKey, true);
}

/// Real-time roster stream for the active room.
final rosterProvider = StreamProvider<List<Player>>((ref) async* {
  final roomId = ref.watch(roomIdProvider);
  if (roomId == null || roomId.trim().isEmpty) {
    yield const <Player>[];
    return;
  }

  await migrateLocalRosterToFirestore(roomId, ref);

  final firestore = ref.watch(firebaseFirestoreProvider);
  yield* _rosterCollection(firestore, roomId)
      .orderBy('name')
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map(Player.fromFirestore).toList(growable: false));
});

final activeRosterProvider =
    NotifierProvider<ActiveRosterNotifier, List<String>>(
        ActiveRosterNotifier.new);

class ActiveRosterNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    final roster = ref.watch(rosterProvider).asData?.value ?? const <Player>[];
    return roster.where((p) => p.isActive).map((p) => p.id).toList(growable: false);
  }

  Future<void> setActiveRoster(List<String> playerIds) async {
    if (playerIds.length != 5) return;
    final roomId = ref.read(roomIdProvider);
    if (roomId == null || roomId.trim().isEmpty) return;

    final firestore = ref.read(firebaseFirestoreProvider);
    final rosterRef = _rosterCollection(firestore, roomId);
    final snapshot = await rosterRef.get();

    final batch = firestore.batch();
    for (final doc in snapshot.docs) {
      final shouldBeActive = playerIds.contains(doc.id);
      batch.update(doc.reference, {'isActive': shouldBeActive});
    }
    await batch.commit();
    state = List<String>.from(playerIds);
  }
}

final rosterActionsProvider = Provider<RosterActions>((ref) {
  return RosterActions(ref);
});

class RosterActions {
  final Ref ref;
  RosterActions(this.ref);

  Future<void> addPlayer(Player player) async {
    final roomId = ref.read(roomIdProvider);
    if (roomId == null || roomId.trim().isEmpty) return;
    final firestore = ref.read(firebaseFirestoreProvider);
    await _rosterCollection(firestore, roomId)
        .doc(player.id)
        .set(player.toJson(), SetOptions(merge: true));
  }

  Future<void> updatePlayer(Player player) async {
    final roomId = ref.read(roomIdProvider);
    if (roomId == null || roomId.trim().isEmpty) return;
    final firestore = ref.read(firebaseFirestoreProvider);
    await _rosterCollection(firestore, roomId)
        .doc(player.id)
        .set(player.toJson(), SetOptions(merge: true));
  }

  Future<void> removePlayer(String id) async {
    final roomId = ref.read(roomIdProvider);
    if (roomId == null || roomId.trim().isEmpty) return;
    final firestore = ref.read(firebaseFirestoreProvider);
    await _rosterCollection(firestore, roomId).doc(id).delete();
  }
}
