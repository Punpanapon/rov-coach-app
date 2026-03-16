import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rov_coach/data/models/vod_review.dart';

/// Firestore paths for a VOD review room:
///   rooms/{roomId}/vod_state   — single document
///
/// Document schema:
/// {
///   "strokes":   [ { points, color, width, toolType }, ... ],
///   "heroes":    [ { id, heroName, imagePath, dx, dy }, ... ],
///   "bookmarks": [ { id, url, topic, notes, colorValue }, ... ],
///   "updatedAt": Timestamp
/// }
///
/// **Free-tier protection:** All writes are debounced by 500 ms. Rapid
/// mutations (e.g. hero drag) coalesce into a single Firestore write.
class VodBoardRepository {
  late final FirebaseFirestore _db;

  VodBoardRepository({FirebaseFirestore? firestore}) {
    _db = firestore ?? FirebaseFirestore.instance;
  }

  // ── Debounce timers per room-per-field ───────────────────────────────
  final _timers = <String, Timer>{};
  static const _debounce = Duration(milliseconds: 500);

  void _debouncedWrite(String key, void Function() action) {
    _timers[key]?.cancel();
    _timers[key] = Timer(_debounce, action);
  }

  DocumentReference<Map<String, dynamic>> _stateDoc(String roomId) =>
      _db.collection('rooms').doc(roomId).collection('vod_state').doc('board');

  // ── One-shot read ───────────────────────────────────────────────────

  /// Fetch the current board state as a one-shot Future (used to hydrate
  /// local providers on cold start / browser refresh).
  Future<Map<String, dynamic>?> loadBoard(String roomId) async {
    final snap = await _stateDoc(roomId).get();
    return snap.data();
  }

  // ── Streams (read — real-time) ──────────────────────────────────────

  /// Full document stream — single listener, parsed client-side.
  Stream<Map<String, dynamic>?> _docStream(String roomId) =>
      _stateDoc(roomId).snapshots().map((s) => s.data());

  /// Stream of placed heroes for a room.
  Stream<List<PlacedHero>> heroesStream(String roomId) {
    return _docStream(roomId).map((data) {
      if (data == null || data['heroes'] == null) return <PlacedHero>[];
      return (data['heroes'] as List)
          .map((e) => PlacedHero.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    });
  }

  /// Stream of permanent strokes for a room.
  Stream<List<Stroke>> strokesStream(String roomId) {
    return _docStream(roomId).map((data) {
      if (data == null || data['strokes'] == null) return <Stroke>[];
      return (data['strokes'] as List)
          .map((e) => Stroke.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    });
  }

  /// Stream of bookmarks for a room.
  Stream<List<VodBookmark>> bookmarksStream(String roomId) {
    return _docStream(roomId).map((data) {
      if (data == null || data['bookmarks'] == null) return <VodBookmark>[];
      return (data['bookmarks'] as List)
          .map((e) => VodBookmark.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    });
  }

  // ── Writes (debounced) ──────────────────────────────────────────────

  /// Debounced overwrite of the full strokes array.
  void setStrokes(String roomId, List<Stroke> strokes) {
    _debouncedWrite('$roomId/strokes', () {
      _stateDoc(roomId).set({
        'strokes': strokes.map((s) => s.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Debounced overwrite of the full heroes array.
  void setHeroes(String roomId, List<PlacedHero> heroes) {
    _debouncedWrite('$roomId/heroes', () {
      _stateDoc(roomId).set({
        'heroes': heroes.map((h) => h.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Debounced overwrite of the full bookmarks array.
  void setBookmarks(String roomId, List<VodBookmark> bookmarks) {
    _debouncedWrite('$roomId/bookmarks', () {
      _stateDoc(roomId).set({
        'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  // ── Playbooks (separate sub-collection) ───────────────────────────────

  /// Save a playbook snapshot to Firestore.
  Future<void> savePlaybook(String roomId, SavedPlaybook playbook) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('playbooks')
        .doc(playbook.id)
        .set(playbook.toJson());
  }

  /// Stream of saved playbooks for a room, newest first.
  Stream<List<SavedPlaybook>> playbooksStream(String roomId) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('playbooks')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SavedPlaybook.fromJson(d.data()))
            .toList());
  }

  /// Delete a playbook by ID.
  Future<void> deletePlaybook(String roomId, String playbookId) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('playbooks')
        .doc(playbookId)
        .delete();
  }
}
