import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:rov_coach/data/models/draft_session.dart';

/// Hive-backed repository for [DraftSession] persistence.
class DraftSessionRepository {
  static const _boxName = 'draftSessions';

  Future<Box<String>> get _box async => Hive.openBox<String>(_boxName);

  Future<List<DraftSession>> getAll() async {
    final box = await _box;
    return box.values
        .map((json) =>
            DraftSession.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList();
  }

  Future<DraftSession?> getById(String id) async {
    final box = await _box;
    final raw = box.get(id);
    if (raw == null) return null;
    return DraftSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(DraftSession session) async {
    final box = await _box;
    await box.put(session.id, jsonEncode(session.toJson()));
  }

  Future<void> delete(String id) async {
    final box = await _box;
    await box.delete(id);
  }
}
