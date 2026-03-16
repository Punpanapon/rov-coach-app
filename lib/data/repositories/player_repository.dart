import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:rov_coach/data/models/player.dart';

/// Hive-backed repository for [Player] CRUD operations.
class PlayerRepository {
  static const _boxName = 'players';

  Future<Box<String>> get _box async => Hive.openBox<String>(_boxName);

  Future<List<Player>> getAll() async {
    final box = await _box;
    return box.values
        .map((json) => Player.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList();
  }

  Future<Player?> getById(String id) async {
    final box = await _box;
    final raw = box.get(id);
    if (raw == null) return null;
    return Player.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(Player player) async {
    final box = await _box;
    await box.put(player.id, jsonEncode(player.toJson()));
  }

  Future<void> delete(String id) async {
    final box = await _box;
    await box.delete(id);
  }
}
