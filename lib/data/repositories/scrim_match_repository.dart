import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:rov_coach/core/enums/enums.dart';
import 'package:rov_coach/data/models/scrim_match.dart';

/// Hive-backed repository for [ScrimMatch] CRUD operations.
class ScrimMatchRepository {
  static const _boxName = 'scrimMatches';

  Future<Box<String>> get _box async => Hive.openBox<String>(_boxName);

  Future<List<ScrimMatch>> getAll() async {
    final box = await _box;
    return box.values
        .map((json) =>
            ScrimMatch.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList();
  }

  Future<ScrimMatch?> getById(String id) async {
    final box = await _box;
    final raw = box.get(id);
    if (raw == null) return null;
    return ScrimMatch.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Returns all scrim records for a given strategy.
  Future<List<ScrimMatch>> getByStrategyId(String strategyId) async {
    final all = await getAll();
    return all.where((m) => m.strategyId == strategyId).toList();
  }

  /// Calculates the win rate (0.0–1.0) for a given strategy.
  /// Returns `null` if there are no scrim records for the strategy.
  Future<double?> winRateForStrategy(String strategyId) async {
    final matches = await getByStrategyId(strategyId);
    if (matches.isEmpty) return null;
    final wins = matches.where((m) => m.result == MatchResult.win).length;
    return wins / matches.length;
  }

  Future<void> save(ScrimMatch match) async {
    final box = await _box;
    await box.put(match.id, jsonEncode(match.toJson()));
  }

  Future<void> delete(String id) async {
    final box = await _box;
    await box.delete(id);
  }
}
