import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rov_coach/data/models/draft_session.dart';

/// Firestore path: rooms/{roomId}/draft_state/session
///
/// Document schema: Same as [DraftSession.toJson] — the full draft document
/// including actions[], currentActionIndex, team names, etc.
///
/// Draft picks are discrete events (not continuous drags), so writes here
/// are immediate — no debouncing needed.
class DraftFirestoreRepository {
  late final FirebaseFirestore _db;

  DraftFirestoreRepository({FirebaseFirestore? firestore}) {
    _db = firestore ?? FirebaseFirestore.instance;
  }

  DocumentReference<Map<String, dynamic>> _stateDoc(String roomId) =>
      _db.collection('rooms').doc(roomId).collection('draft_state').doc('session');

  // ── Stream ─────────────────────────────────────────────────────────

  /// Real-time stream of the draft session for a room.
  /// Emits `null` when no draft has been started yet.
  Stream<DraftSession?> draftStream(String roomId) {
    return _stateDoc(roomId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return DraftSession.fromJson(data);
    });
  }

  // ── Write ──────────────────────────────────────────────────────────

  /// Persist the full draft state (immediate — no debounce).
  Future<void> setDraft(String roomId, DraftSession draft) {
    return _stateDoc(roomId).set(draft.toJson());
  }

  /// Delete the draft document (when clearing / leaving).
  Future<void> clearDraft(String roomId) {
    return _stateDoc(roomId).delete();
  }
}
