import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rov_coach/data/models/draft_session.dart';
import 'package:rov_coach/data/repositories/draft_firestore_repository.dart';
import 'package:rov_coach/data/repositories/draft_session_repository.dart';
import 'package:rov_coach/providers/room_provider.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

// ---------------------------------------------------------------------------
// Repositories
// ---------------------------------------------------------------------------

/// Local Hive-backed repository (for saving completed drafts).
final draftSessionRepositoryProvider =
    Provider<DraftSessionRepository>((ref) => DraftSessionRepository());

/// Firestore-backed repository (for real-time collaboration).
final draftFirestoreRepositoryProvider =
    Provider<DraftFirestoreRepository>((_) => DraftFirestoreRepository());

// ---------------------------------------------------------------------------
// Firestore stream — primary source of truth for remote changes
// ---------------------------------------------------------------------------

/// Streams the draft session for the current room from Firestore.
/// Emits `null` when no draft has been started yet.
final firestoreDraftProvider = StreamProvider.autoDispose<DraftSession?>((ref) {
  final roomId = ref.watch(roomIdProvider);
  if (roomId == null) return const Stream.empty();
  return ref.watch(draftFirestoreRepositoryProvider).draftStream(roomId);
});

// ---------------------------------------------------------------------------
// Active draft notifier — local state + Firestore sync
// ---------------------------------------------------------------------------

final activeDraftProvider =
    NotifierProvider<ActiveDraftNotifier, DraftSession?>(
        ActiveDraftNotifier.new);

class ActiveDraftNotifier extends Notifier<DraftSession?> {
  @override
  DraftSession? build() => null;

  void _syncToFirestore() {
    final roomId = ref.read(roomIdProvider);
    if (roomId == null || state == null) return;
    ref.read(draftFirestoreRepositoryProvider).setDraft(roomId, state!);
  }

  /// Start a brand-new draft session.
  void startNewDraft({String? blueTeamName, String? redTeamName}) {
    state = DraftSession.create(
      id: _uuid.v4(),
      blueTeamName: blueTeamName,
      redTeamName: redTeamName,
    );
    _syncToFirestore();
  }

  /// Select a hero for the current draft step and advance to the next step.
  /// Returns `false` if the draft is already complete or hero is unavailable.
  bool pickHero(String heroName) {
    final draft = state;
    if (draft == null || draft.isCompleted) return false;
    if (draft.unavailableHeroes.contains(heroName)) return false;

    final index = draft.currentActionIndex;
    final updatedActions = List<DraftAction>.from(draft.actions);
    updatedActions[index] = updatedActions[index].copyWith(heroName: heroName);

    state = draft.copyWith(
      actions: updatedActions,
      currentActionIndex: index + 1,
    );
    _syncToFirestore();
    return true;
  }

  /// Undo the last action (go back one step).
  void undo() {
    final draft = state;
    if (draft == null || draft.currentActionIndex == 0) return;

    final prevIndex = draft.currentActionIndex - 1;
    final updatedActions = List<DraftAction>.from(draft.actions);
    updatedActions[prevIndex] = DraftAction(
      order: updatedActions[prevIndex].order,
      side: updatedActions[prevIndex].side,
      actionType: updatedActions[prevIndex].actionType,
      heroName: null,
    );

    state = draft.copyWith(
      actions: updatedActions,
      currentActionIndex: prevIndex,
    );
    _syncToFirestore();
  }

  /// Reset the entire draft to start over.
  void resetDraft() {
    final draft = state;
    if (draft == null) return;
    state = DraftSession.create(
      id: _uuid.v4(),
      blueTeamName: draft.blueTeamName,
      redTeamName: draft.redTeamName,
    );
    _syncToFirestore();
  }

  /// Called when a Firestore snapshot arrives from another client.
  void applyRemoteDraft(DraftSession? draft) {
    state = draft;
  }

  /// Save the current draft to persistent storage and clear active state.
  Future<void> saveAndClose() async {
    final draft = state;
    if (draft == null) return;
    await ref.read(draftSessionRepositoryProvider).save(draft);
    // Clear Firestore document for this room.
    final roomId = ref.read(roomIdProvider);
    if (roomId != null) {
      await ref.read(draftFirestoreRepositoryProvider).clearDraft(roomId);
    }
    state = null;
  }
}
