import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rov_coach/core/enums/enums.dart';
import 'package:rov_coach/data/models/scrim_match.dart';
import 'package:rov_coach/data/repositories/scrim_match_repository.dart';
import 'package:rov_coach/data/mock_data.dart';

/// Singleton instance of [ScrimMatchRepository].
final scrimMatchRepositoryProvider = Provider<ScrimMatchRepository>((ref) {
  return ScrimMatchRepository();
});

/// Manages the list of all scrim match records.
final scrimListProvider =
    AsyncNotifierProvider<ScrimListNotifier, List<ScrimMatch>>(
        ScrimListNotifier.new);

class ScrimListNotifier extends AsyncNotifier<List<ScrimMatch>> {
  ScrimMatchRepository get _repo => ref.read(scrimMatchRepositoryProvider);

  @override
  Future<List<ScrimMatch>> build() async {
    final existing = await _repo.getAll();
    if (existing.isNotEmpty) return existing;

    // Seed mock scrims on first launch
    for (final match in MockData.scrimMatches) {
      await _repo.save(match);
    }
    return MockData.scrimMatches;
  }

  Future<void> addMatch(ScrimMatch match) async {
    await _repo.save(match);
    state = AsyncData(await _repo.getAll());
  }

  Future<void> updateMatch(ScrimMatch match) async {
    await _repo.save(match);
    state = AsyncData(await _repo.getAll());
  }

  Future<void> removeMatch(String id) async {
    await _repo.delete(id);
    state = AsyncData(await _repo.getAll());
  }
}

/// Computes the win rate for a given strategy from the current scrim list.
/// Returns null when there are no matches for that strategy.
final strategyWinRateProvider =
    Provider.family<double?, String>((ref, strategyId) {
  final scrimState = ref.watch(scrimListProvider);
  return scrimState.whenOrNull(data: (matches) {
    final forStrategy =
        matches.where((m) => m.strategyId == strategyId).toList();
    if (forStrategy.isEmpty) return null;
    final wins = forStrategy.where((m) => m.result == MatchResult.win).length;
    return wins / forStrategy.length;
  });
});
