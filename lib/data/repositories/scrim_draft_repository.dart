import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rov_coach/providers/scrim_draft_provider.dart';

/// Firestore path: rooms/{roomId}/scrim_state/active
///
/// Persists the full ScrimDraftState so the browser can be refreshed
/// without losing progress.  Writes are debounced (500 ms).
class ScrimDraftRepository {
  late final FirebaseFirestore _db;

  ScrimDraftRepository({FirebaseFirestore? firestore}) {
    _db = firestore ?? FirebaseFirestore.instance;
  }

  final _timers = <String, Timer>{};
  static const _debounce = Duration(milliseconds: 500);

  void _debouncedWrite(String key, void Function() action) {
    _timers[key]?.cancel();
    _timers[key] = Timer(_debounce, action);
  }

  DocumentReference<Map<String, dynamic>> _stateDoc(String roomId) =>
      _db.collection('rooms').doc(roomId).collection('scrim_state').doc('active');

  // ── Read (one-shot) ────────────────────────────────────────────────

  Future<ScrimDraftState?> load(String roomId) async {
    final snap = await _stateDoc(roomId).get();
    final data = snap.data();
    if (data == null) return null;
    return _fromJson(data);
  }

  // ── Stream ─────────────────────────────────────────────────────────

  Stream<ScrimDraftState?> stream(String roomId) {
    return _stateDoc(roomId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return _fromJson(data);
    });
  }

  // ── Write (debounced) ──────────────────────────────────────────────

  void save(String roomId, ScrimDraftState state) {
    _debouncedWrite('$roomId/scrim', () {
      _stateDoc(roomId).set(_toJson(state));
    });
  }

  Future<void> clear(String roomId) {
    _timers['$roomId/scrim']?.cancel();
    return _stateDoc(roomId).delete();
  }

  // ── JSON serialisation helpers ─────────────────────────────────────

  static Map<String, dynamic> _toJson(ScrimDraftState s) => {
        'totalGames': s.totalGames,
        'redraftGames': s.redraftGames.toList(),
        'matchNotes': s.matchNotes,
        'currentGame': s.currentGame,
        'phase': s.phase.name,
        'activeTool': s.activeTool.name,
        'draftMode': s.draftMode.name,
        'ourLockedPicks': s.ourLockedPicks.toList(),
        'enemyLockedPicks': s.enemyLockedPicks.toList(),
        'ourCurrentPicks': s.ourCurrentPicks.toList(),
        'enemyCurrentPicks': s.enemyCurrentPicks.toList(),
        'ourCurrentBans': s.ourCurrentBans.toList(),
        'enemyCurrentBans': s.enemyCurrentBans.toList(),
        'draftHistory': s.draftHistory.map(_gameRecordToJson).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static ScrimDraftState _fromJson(Map<String, dynamic> j) => ScrimDraftState(
        totalGames: (j['totalGames'] as num?)?.toInt() ?? 5,
        redraftGames: _setOfInt(j['redraftGames']),
        matchNotes: (j['matchNotes'] as String?) ?? '',
        currentGame: (j['currentGame'] as num?)?.toInt() ?? 1,
        phase: _parsePhase(j['phase']),
        activeTool: _parseTool(j['activeTool']),
        draftMode: _parseDraftMode(j['draftMode']),
        ourLockedPicks: _setOfString(j['ourLockedPicks']),
        enemyLockedPicks: _setOfString(j['enemyLockedPicks']),
        ourCurrentPicks: _setOfString(j['ourCurrentPicks']),
        enemyCurrentPicks: _setOfString(j['enemyCurrentPicks']),
        ourCurrentBans: _setOfString(j['ourCurrentBans']),
        enemyCurrentBans: _setOfString(j['enemyCurrentBans']),
        draftHistory: _parseHistory(j['draftHistory']),
      );

  static Map<String, dynamic> _gameRecordToJson(GameRecord r) => {
        'gameNumber': r.gameNumber,
        'ourBans': r.ourBans.toList(),
        'enemyBans': r.enemyBans.toList(),
        'ourPicks': r.ourPicks.toList(),
        'enemyPicks': r.enemyPicks.toList(),
      };

  static GameRecord _gameRecordFromJson(Map<String, dynamic> j) => GameRecord(
        gameNumber: (j['gameNumber'] as num).toInt(),
        ourBans: _setOfString(j['ourBans']),
        enemyBans: _setOfString(j['enemyBans']),
        ourPicks: _setOfString(j['ourPicks']),
        enemyPicks: _setOfString(j['enemyPicks']),
      );

  static Set<String> _setOfString(dynamic v) =>
      v is List ? v.cast<String>().toSet() : {};

  static Set<int> _setOfInt(dynamic v) =>
      v is List ? v.map((e) => (e as num).toInt()).toSet() : {};

  static ScrimPhase _parsePhase(dynamic v) {
    if (v is String) {
      for (final p in ScrimPhase.values) {
        if (p.name == v) return p;
      }
    }
    return ScrimPhase.setup;
  }

  static DraftTool _parseTool(dynamic v) {
    if (v is String) {
      for (final t in DraftTool.values) {
        if (t.name == v) return t;
      }
    }
    return DraftTool.ban;
  }

  static DraftMode _parseDraftMode(dynamic v) {
    if (v is String) {
      for (final m in DraftMode.values) {
        if (m.name == v) return m;
      }
    }
    return DraftMode.global;
  }

  static List<GameRecord> _parseHistory(dynamic v) {
    if (v is! List) return [];
    return v
        .map((e) => _gameRecordFromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
