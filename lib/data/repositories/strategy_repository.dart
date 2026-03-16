import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:rov_coach/data/models/strategy.dart';

/// Hive-backed repository for [Strategy] CRUD operations.
class StrategyRepository {
  static const _boxName = 'strategies';

  Future<Box<String>> get _box async => Hive.openBox<String>(_boxName);

  Future<List<Strategy>> getAll() async {
    final box = await _box;
    return box.values
        .map((json) =>
            Strategy.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList();
  }

  Future<Strategy?> getById(String id) async {
    final box = await _box;
    final raw = box.get(id);
    if (raw == null) return null;
    return Strategy.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(Strategy strategy) async {
    final box = await _box;
    await box.put(strategy.id, jsonEncode(strategy.toJson()));
  }

  Future<void> delete(String id) async {
    final box = await _box;
    await box.delete(id);
  }
}
