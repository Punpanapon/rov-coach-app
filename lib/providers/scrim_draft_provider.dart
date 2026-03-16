import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rov_coach/providers/room_provider.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum ScrimPhase { setup, drafting, summary }

enum DraftTool { ban, pick }

enum DraftSide { our, enemy }

enum DraftMode { global, normal }

// ---------------------------------------------------------------------------
// Game record — stored after each game ends
// ---------------------------------------------------------------------------

class GameRecord {
  final int gameNumber;
  final Set<String> ourBans;
  final Set<String> enemyBans;
  final Set<String> ourPicks;
  final Set<String> enemyPicks;

  const GameRecord({
    required this.gameNumber,
    required this.ourBans,
    required this.enemyBans,
    required this.ourPicks,
    required this.enemyPicks,
  });

  Map<String, dynamic> toMap() => {
        'gameNumber': gameNumber,
        'ourBans': ourBans.toList(),
        'enemyBans': enemyBans.toList(),
        'ourPicks': ourPicks.toList(),
        'enemyPicks': enemyPicks.toList(),
      };

  static GameRecord fromMap(Map<String, dynamic> j) => GameRecord(
        gameNumber: (j['gameNumber'] as num).toInt(),
        ourBans: _setOfString(j['ourBans']),
        enemyBans: _setOfString(j['enemyBans']),
        ourPicks: _setOfString(j['ourPicks']),
        enemyPicks: _setOfString(j['enemyPicks']),
      );
}

// ---------------------------------------------------------------------------
// Scrim Draft State
// ---------------------------------------------------------------------------

class ScrimDraftState {
  final int totalGames;
  final Set<int> redraftGames;
  final String matchNotes;
  final int currentGame;
  final ScrimPhase phase;
  final DraftTool activeTool;
  final DraftMode draftMode;

  /// Heroes picked in PREVIOUS games (locked — cannot be toggled).
  final Set<String> ourLockedPicks;
  final Set<String> enemyLockedPicks;

  /// Heroes picked in the CURRENT game (undoable).
  final Set<String> ourCurrentPicks;
  final Set<String> enemyCurrentPicks;

  /// Heroes banned in the CURRENT game.
  final Set<String> ourCurrentBans;
  final Set<String> enemyCurrentBans;

  final List<GameRecord> draftHistory;

  /// Custom hero role overrides (heroName → role).
  final Map<String, String> customRoles;

  /// Current zoom level for the hero grid.
  final double zoom;

  const ScrimDraftState({
    this.totalGames = 5,
    this.redraftGames = const {},
    this.matchNotes = '',
    this.currentGame = 1,
    this.phase = ScrimPhase.setup,
    this.activeTool = DraftTool.ban,
    this.draftMode = DraftMode.global,
    this.ourLockedPicks = const {},
    this.enemyLockedPicks = const {},
    this.ourCurrentPicks = const {},
    this.enemyCurrentPicks = const {},
    this.ourCurrentBans = const {},
    this.enemyCurrentBans = const {},
    this.draftHistory = const [],
    this.customRoles = const {},
    this.zoom = 1.0,
  });

  ScrimDraftState copyWith({
    int? totalGames,
    Set<int>? redraftGames,
    String? matchNotes,
    int? currentGame,
    ScrimPhase? phase,
    DraftTool? activeTool,
    DraftMode? draftMode,
    Set<String>? ourLockedPicks,
    Set<String>? enemyLockedPicks,
    Set<String>? ourCurrentPicks,
    Set<String>? enemyCurrentPicks,
    Set<String>? ourCurrentBans,
    Set<String>? enemyCurrentBans,
    List<GameRecord>? draftHistory,
    Map<String, String>? customRoles,
    double? zoom,
  }) {
    return ScrimDraftState(
      totalGames: totalGames ?? this.totalGames,
      redraftGames: redraftGames ?? this.redraftGames,
      matchNotes: matchNotes ?? this.matchNotes,
      currentGame: currentGame ?? this.currentGame,
      phase: phase ?? this.phase,
      activeTool: activeTool ?? this.activeTool,
      draftMode: draftMode ?? this.draftMode,
      ourLockedPicks: ourLockedPicks ?? this.ourLockedPicks,
      enemyLockedPicks: enemyLockedPicks ?? this.enemyLockedPicks,
      ourCurrentPicks: ourCurrentPicks ?? this.ourCurrentPicks,
      enemyCurrentPicks: enemyCurrentPicks ?? this.enemyCurrentPicks,
      ourCurrentBans: ourCurrentBans ?? this.ourCurrentBans,
      enemyCurrentBans: enemyCurrentBans ?? this.enemyCurrentBans,
      draftHistory: draftHistory ?? this.draftHistory,
      customRoles: customRoles ?? this.customRoles,
      zoom: zoom ?? this.zoom,
    );
  }

  // ── Firestore serialization ──────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'totalGames': totalGames,
        'redraftGames': redraftGames.toList(),
        'matchNotes': matchNotes,
        'currentGame': currentGame,
        'phase': phase.name,
        'activeTool': activeTool.name,
        'draftMode': draftMode.name,
        'ourLockedPicks': ourLockedPicks.toList(),
        'enemyLockedPicks': enemyLockedPicks.toList(),
        'ourCurrentPicks': ourCurrentPicks.toList(),
        'enemyCurrentPicks': enemyCurrentPicks.toList(),
        'ourCurrentBans': ourCurrentBans.toList(),
        'enemyCurrentBans': enemyCurrentBans.toList(),
        'draftHistory': draftHistory.map((r) => r.toMap()).toList(),
        'customRoles': customRoles,
        'zoom': zoom,
      };

  static ScrimDraftState fromMap(Map<String, dynamic> j) => ScrimDraftState(
        totalGames: (j['totalGames'] as num?)?.toInt() ?? 5,
        redraftGames: _setOfInt(j['redraftGames']),
        matchNotes: (j['matchNotes'] as String?) ?? '',
        currentGame: (j['currentGame'] as num?)?.toInt() ?? 1,
        phase: _parseEnum(ScrimPhase.values, j['phase'], ScrimPhase.setup),
        activeTool:
            _parseEnum(DraftTool.values, j['activeTool'], DraftTool.ban),
        draftMode:
            _parseEnum(DraftMode.values, j['draftMode'], DraftMode.global),
        ourLockedPicks: _setOfString(j['ourLockedPicks']),
        enemyLockedPicks: _setOfString(j['enemyLockedPicks']),
        ourCurrentPicks: _setOfString(j['ourCurrentPicks']),
        enemyCurrentPicks: _setOfString(j['enemyCurrentPicks']),
        ourCurrentBans: _setOfString(j['ourCurrentBans']),
        enemyCurrentBans: _setOfString(j['enemyCurrentBans']),
        draftHistory: _parseHistory(j['draftHistory']),
        customRoles:
            Map<String, String>.from(j['customRoles'] as Map? ?? {}),
        zoom: (j['zoom'] as num?)?.toDouble() ?? 1.0,
      );
}

// ── Shared parsing helpers ──────────────────────────────────────────

Set<String> _setOfString(dynamic v) =>
    v is List ? v.cast<String>().toSet() : {};

Set<int> _setOfInt(dynamic v) =>
    v is List ? v.map((e) => (e as num).toInt()).toSet() : {};

T _parseEnum<T extends Enum>(List<T> values, dynamic v, T fallback) {
  if (v is String) {
    for (final e in values) {
      if (e.name == v) return e;
    }
  }
  return fallback;
}

List<GameRecord> _parseHistory(dynamic v) {
  if (v is! List) return [];
  return v
      .map((e) => GameRecord.fromMap(Map<String, dynamic>.from(e as Map)))
      .toList();
}

// ---------------------------------------------------------------------------
// Firestore document reference for the draft state
// ---------------------------------------------------------------------------

DocumentReference<Map<String, dynamic>> _draftDoc(String roomId) =>
    FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('scrim_state')
        .doc('active');

// ---------------------------------------------------------------------------
// Notifier — real-time synced via Firestore snapshots
// ---------------------------------------------------------------------------

class ScrimDraftNotifier extends Notifier<ScrimDraftState> {
  @override
  ScrimDraftState build() {
    final roomId = ref.watch(roomIdProvider);

    if (roomId != null) {
      final sub = _draftDoc(roomId).snapshots().listen((snap) {
        final data = snap.data();
        if (data != null) {
          state = ScrimDraftState.fromMap(data);
        }
      });
      ref.onDispose(sub.cancel);
    }

    return const ScrimDraftState();
  }

  /// Write the current state to Firestore immediately.
  void _write() {
    final roomId = ref.read(roomIdProvider);
    if (roomId == null) return;
    _draftDoc(roomId).set(
      {...state.toMap(), 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  void startScrim({
    required int totalGames,
    required Set<int> redraftGames,
    required String matchNotes,
    required DraftMode draftMode,
  }) {
    state = ScrimDraftState(
      totalGames: totalGames,
      redraftGames: redraftGames,
      matchNotes: matchNotes,
      draftMode: draftMode,
      currentGame: 1,
      phase: ScrimPhase.drafting,
    );
    _write();
  }

  void setTool(DraftTool tool) {
    state = state.copyWith(activeTool: tool);
    _write();
  }

  /// Tap a hero on a specific team's grid.
  void toggleHero(String heroName, DraftSide side) {
    if (side == DraftSide.our) {
      _toggleOurHero(heroName);
    } else {
      _toggleEnemyHero(heroName);
    }
  }

  void _toggleOurHero(String heroName) {
    if (state.ourLockedPicks.contains(heroName)) return;
    if (state.enemyCurrentPicks.contains(heroName)) return;
    if (state.enemyCurrentBans.contains(heroName)) return;

    if (state.activeTool == DraftTool.ban) {
      final bans = Set<String>.from(state.ourCurrentBans);
      if (bans.contains(heroName)) {
        bans.remove(heroName);
      } else {
        if (state.ourCurrentPicks.contains(heroName)) return;
        bans.add(heroName);
      }
      state = state.copyWith(ourCurrentBans: bans);
    } else {
      final picks = Set<String>.from(state.ourCurrentPicks);
      if (picks.contains(heroName)) {
        picks.remove(heroName);
      } else {
        if (state.ourCurrentBans.contains(heroName)) return;
        picks.add(heroName);
      }
      state = state.copyWith(ourCurrentPicks: picks);
    }
    _write();
  }

  void _toggleEnemyHero(String heroName) {
    if (state.enemyLockedPicks.contains(heroName)) return;
    if (state.ourCurrentPicks.contains(heroName)) return;
    if (state.ourCurrentBans.contains(heroName)) return;

    if (state.activeTool == DraftTool.ban) {
      final bans = Set<String>.from(state.enemyCurrentBans);
      if (bans.contains(heroName)) {
        bans.remove(heroName);
      } else {
        if (state.enemyCurrentPicks.contains(heroName)) return;
        bans.add(heroName);
      }
      state = state.copyWith(enemyCurrentBans: bans);
    } else {
      final picks = Set<String>.from(state.enemyCurrentPicks);
      if (picks.contains(heroName)) {
        picks.remove(heroName);
      } else {
        if (state.enemyCurrentBans.contains(heroName)) return;
        picks.add(heroName);
      }
      state = state.copyWith(enemyCurrentPicks: picks);
    }
    _write();
  }

  /// End the current game: save history, lock picks, advance.
  void endCurrentGame() {
    final record = GameRecord(
      gameNumber: state.currentGame,
      ourBans: Set.unmodifiable(state.ourCurrentBans),
      enemyBans: Set.unmodifiable(state.enemyCurrentBans),
      ourPicks: Set.unmodifiable(state.ourCurrentPicks),
      enemyPicks: Set.unmodifiable(state.enemyCurrentPicks),
    );

    final history = [...state.draftHistory, record];
    final nextGame = state.currentGame + 1;

    var nextOurLocked = state.draftMode == DraftMode.global
        ? {...state.ourLockedPicks, ...state.ourCurrentPicks}
        : const <String>{};
    var nextEnemyLocked = state.draftMode == DraftMode.global
        ? {...state.enemyLockedPicks, ...state.enemyCurrentPicks}
        : const <String>{};

    if (nextGame > state.totalGames) {
      state = state.copyWith(
        draftHistory: history,
        ourLockedPicks: nextOurLocked,
        enemyLockedPicks: nextEnemyLocked,
        ourCurrentPicks: {},
        enemyCurrentPicks: {},
        ourCurrentBans: {},
        enemyCurrentBans: {},
        phase: ScrimPhase.summary,
      );
      _write();
      return;
    }

    if (state.redraftGames.contains(nextGame)) {
      nextOurLocked = {};
      nextEnemyLocked = {};
    }

    state = state.copyWith(
      draftHistory: history,
      currentGame: nextGame,
      ourLockedPicks: nextOurLocked,
      enemyLockedPicks: nextEnemyLocked,
      ourCurrentPicks: {},
      enemyCurrentPicks: {},
      ourCurrentBans: {},
      enemyCurrentBans: {},
    );
    _write();
  }

  void resetToSetup() {
    state = const ScrimDraftState();
    final roomId = ref.read(roomIdProvider);
    if (roomId != null) {
      _draftDoc(roomId).delete();
    }
  }

  // ── Zoom ──

  void zoomIn() {
    state = state.copyWith(zoom: (state.zoom + 0.1).clamp(0.5, 1.5));
    _write();
  }

  void zoomOut() {
    state = state.copyWith(zoom: (state.zoom - 0.1).clamp(0.5, 1.5));
    _write();
  }

  // ── Custom roles ──

  void setCustomRole(String heroName, String role) {
    state = state.copyWith(customRoles: {...state.customRoles, heroName: role});
    _write();
  }

  void resetCustomRole(String heroName) {
    state = state.copyWith(
        customRoles: Map.from(state.customRoles)..remove(heroName));
    _write();
  }

  void resetAllCustomRoles() {
    state = state.copyWith(customRoles: {});
    _write();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final scrimDraftProvider =
    NotifierProvider<ScrimDraftNotifier, ScrimDraftState>(
        ScrimDraftNotifier.new);

// ---------------------------------------------------------------------------
// Derived providers — backward-compatible reads for UI
// ---------------------------------------------------------------------------

final customRolesProvider = Provider<Map<String, String>>((ref) {
  return ref.watch(scrimDraftProvider).customRoles;
});

final draftZoomProvider = Provider<double>((ref) {
  return ref.watch(scrimDraftProvider).zoom;
});

// ---------------------------------------------------------------------------
// Draft board layout providers
// ---------------------------------------------------------------------------

enum DraftBoardPosition { top, bottom, left, right }

final isDraftBoardVisibleProvider =
    NotifierProvider<_DraftBoardVisibleNotifier, bool>(
        _DraftBoardVisibleNotifier.new);

class _DraftBoardVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle() => state = !state;
  void set(bool v) => state = v;
}

final draftBoardPositionProvider =
    NotifierProvider<_DraftBoardPositionNotifier, DraftBoardPosition>(
        _DraftBoardPositionNotifier.new);

class _DraftBoardPositionNotifier extends Notifier<DraftBoardPosition> {
  @override
  DraftBoardPosition build() => DraftBoardPosition.top;
  void set(DraftBoardPosition v) => state = v;
}

// ---------------------------------------------------------------------------
// Picks & Bans panel position provider
// ---------------------------------------------------------------------------

enum PanelPosition { top, bottom, left, right }

final draftPanelPositionProvider =
    NotifierProvider<_DraftPanelPositionNotifier, PanelPosition>(
        _DraftPanelPositionNotifier.new);

class _DraftPanelPositionNotifier extends Notifier<PanelPosition> {
  @override
  PanelPosition build() => PanelPosition.top;
  void set(PanelPosition v) => state = v;
}

// ---------------------------------------------------------------------------
// Duo scroll toggle provider
// ---------------------------------------------------------------------------

final isDuoScrollEnabledProvider =
    NotifierProvider<_DuoScrollNotifier, bool>(_DuoScrollNotifier.new);

class _DuoScrollNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle() => state = !state;
  void set(bool v) => state = v;
}

// ---------------------------------------------------------------------------
// Grouped view toggle provider
// ---------------------------------------------------------------------------

final isGroupedViewProvider =
    NotifierProvider<_GroupedViewNotifier, bool>(_GroupedViewNotifier.new);

class _GroupedViewNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
  void set(bool v) => state = v;
}
