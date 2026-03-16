import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rov_coach/data/models/game_result.dart';
import 'package:rov_coach/data/repositories/game_result_repository.dart';
import 'package:rov_coach/providers/room_provider.dart';

final gameResultRepositoryProvider = Provider<GameResultRepository>((ref) {
  return GameResultRepository();
});

final gameResultsProvider =
    AsyncNotifierProvider<GameResultsNotifier, List<GameResult>>(
        GameResultsNotifier.new);

final firestoreMatchResultsProvider =
    StreamProvider<List<GameResult>>((ref) {
  final roomId = ref.watch(roomIdProvider);
  if (roomId == null) return Stream.value(const <GameResult>[]);

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

class GameResultsNotifier extends AsyncNotifier<List<GameResult>> {
  GameResultRepository get _repo => ref.read(gameResultRepositoryProvider);

  CollectionReference<Map<String, dynamic>>? _matchResultsCollection() {
    final roomId = ref.read(roomIdProvider);
    if (roomId == null) return null;
    return FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('match_results');
  }

  @override
  Future<List<GameResult>> build() async {
    return _repo.getAll();
  }

  Future<void> addResult(GameResult result) async {
    await _repo.save(result);

    final col = _matchResultsCollection();
    if (col != null) {
      await col.doc(result.id).set(result.toJson());
    }

    state = AsyncData(await _repo.getAll());
  }

  Future<void> updateResult(GameResult result) async {
    await _repo.save(result);

    final col = _matchResultsCollection();
    if (col != null) {
      await col.doc(result.id).set(result.toJson(), SetOptions(merge: true));
    }

    state = AsyncData(await _repo.getAll());
  }

  Future<void> removeResult(String id) async {
    await _repo.delete(id);

    final col = _matchResultsCollection();
    if (col != null) {
      await col.doc(id).delete();
    }

    state = AsyncData(await _repo.getAll());
  }
}
