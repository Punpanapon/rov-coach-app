import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rov_coach/data/models/hall_of_fame.dart';
import 'package:rov_coach/providers/room_provider.dart';

// ---------------------------------------------------------------------------
// Firestore repository for Hall of Fame/Shame
// ---------------------------------------------------------------------------

final hallOfFameRepositoryProvider =
    Provider<HallOfFameRepository>((_) => HallOfFameRepository());

class HallOfFameRepository {
  late final FirebaseFirestore _db;
  final _timers = <String, Timer>{};
  static const _debounce = Duration(milliseconds: 500);

  HallOfFameRepository({FirebaseFirestore? firestore}) {
    _db = firestore ?? FirebaseFirestore.instance;
  }

  CollectionReference<Map<String, dynamic>> _col(String roomId) =>
      _db.collection('rooms').doc(roomId).collection('hall_of_fame');

  Stream<List<HallEntry>> entriesStream(String roomId) {
    return _col(roomId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => HallEntry.fromJson(d.data()))
            .toList());
  }

  void addEntry(String roomId, HallEntry entry) {
    _col(roomId).doc(entry.id).set(entry.toJson());
  }

  void updateEntry(String roomId, HallEntry entry) {
    _debouncedWrite('$roomId-${entry.id}', () {
      _col(roomId).doc(entry.id).set(entry.toJson());
    });
  }

  void removeEntry(String roomId, String entryId) {
    _col(roomId).doc(entryId).delete();
  }

  void _debouncedWrite(String key, void Function() action) {
    _timers[key]?.cancel();
    _timers[key] = Timer(_debounce, action);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Streams Hall of Fame entries from Firestore for the current room.
final firestoreHallOfFameProvider =
    StreamProvider.autoDispose<List<HallEntry>>((ref) {
  final roomId = ref.watch(roomIdProvider);
  if (roomId == null) return const Stream.empty();
  return ref.watch(hallOfFameRepositoryProvider).entriesStream(roomId);
});
