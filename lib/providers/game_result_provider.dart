import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rov_coach/data/models/game_result.dart';
import 'package:rov_coach/data/services/migration_service.dart';
import 'package:rov_coach/providers/room_provider.dart';

// ---------------------------------------------------------------------------
// Firestore real-time stream — the single source of truth for ALL tabs
// ---------------------------------------------------------------------------
final firestoreMatchResultsProvider =
    StreamProvider<List<GameResult>>((ref) {
  final roomId = ref.watch(roomIdProvider);
  if (roomId == null) return Stream.value(const <GameResult>[]);

  // Kick off one-time migration in the background (fire-and-forget).
  // It's idempotent, so safe even if multiple widgets trigger it.
  MigrationService.migrateLocalResultsToFirestore(roomId);

  return FirebaseFirestore.instance
      .collection('rooms')
      .doc(roomId)
      .collection('match_results')
      .orderBy('date', descending: true)
      .snapshots()
      .map((snap) {
    return snap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return GameResult.fromJson(data);
    }).toList();
  });
});

// ---------------------------------------------------------------------------
// Hero selection state for Analytics deep-dive
// ---------------------------------------------------------------------------
final selectedAnalysisHeroesProvider =
    NotifierProvider<SelectedAnalysisHeroesNotifier, List<String>>(
        SelectedAnalysisHeroesNotifier.new);

class SelectedAnalysisHeroesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void toggleHero(String heroName) {
    if (state.contains(heroName)) {
      state = state.where((h) => h != heroName).toList();
      return;
    }
    state = [...state, heroName];
  }

  void clear() {
    state = const [];
  }
}

// ---------------------------------------------------------------------------
// Write-operation helper — Firestore-first (no more Hive writes)
// ---------------------------------------------------------------------------
final gameResultWriterProvider = Provider<GameResultWriter>((ref) {
  return GameResultWriter(ref);
});

class GameResultWriter {
  final Ref _ref;
  GameResultWriter(this._ref);

  CollectionReference<Map<String, dynamic>>? _col() {
    final roomId = _ref.read(roomIdProvider);
    if (roomId == null) return null;
    return FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('match_results');
  }

  Future<void> addResult(GameResult result) async {
    final col = _col();
    if (col != null) {
      await col.doc(result.id).set(result.toJson());
    }
  }

  Future<void> updateResult(GameResult result) async {
    final col = _col();
    if (col != null) {
      await col.doc(result.id).set(result.toJson(), SetOptions(merge: true));
    }
  }

  Future<void> removeResult(String id) async {
    final col = _col();
    if (col != null) {
      await col.doc(id).delete();
    }
  }
}
