import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:rov_coach/data/models/game_result.dart';

/// Hive-backed repository for [GameResult] CRUD operations.
class GameResultRepository {
  static const _boxName = 'game_results';

  Future<Box<String>> get _box async => Hive.openBox<String>(_boxName);

  Future<List<GameResult>> getAll() async {
    final box = await _box;
    return box.values
        .map((json) =>
            GameResult.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> save(GameResult result) async {
    final box = await _box;
    await box.put(result.id, jsonEncode(result.toJson()));
  }

  Future<void> delete(String id) async {
    final box = await _box;
    await box.delete(id);
  }
}
