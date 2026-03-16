import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rov_coach/data/models/strategy.dart';
import 'package:rov_coach/data/repositories/strategy_repository.dart';
import 'package:rov_coach/data/mock_data.dart';

/// Singleton instance of [StrategyRepository].
final strategyRepositoryProvider = Provider<StrategyRepository>((ref) {
  return StrategyRepository();
});

/// Manages the list of team strategies.
final strategyListProvider =
    AsyncNotifierProvider<StrategyListNotifier, List<Strategy>>(
        StrategyListNotifier.new);

class StrategyListNotifier extends AsyncNotifier<List<Strategy>> {
  StrategyRepository get _repo => ref.read(strategyRepositoryProvider);

  @override
  Future<List<Strategy>> build() async {
    final existing = await _repo.getAll();
    if (existing.isNotEmpty) return existing;

    // Seed mock strategies on first launch
    for (final strategy in MockData.strategies) {
      await _repo.save(strategy);
    }
    return MockData.strategies;
  }

  Future<void> addStrategy(Strategy strategy) async {
    await _repo.save(strategy);
    state = AsyncData(await _repo.getAll());
  }

  Future<void> updateStrategy(Strategy strategy) async {
    await _repo.save(strategy);
    state = AsyncData(await _repo.getAll());
  }

  Future<void> removeStrategy(String id) async {
    await _repo.delete(id);
    state = AsyncData(await _repo.getAll());
  }
}
