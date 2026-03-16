import 'package:equatable/equatable.dart';
import 'package:rov_coach/core/enums/enums.dart';

/// A single action (ban or pick) in the draft sequence.
class DraftAction extends Equatable {
  final int order; // 0-indexed position in the full sequence
  final DraftSide side;
  final DraftActionType actionType;
  final String? heroName; // null until a hero is selected

  const DraftAction({
    required this.order,
    required this.side,
    required this.actionType,
    this.heroName,
  });

  DraftAction copyWith({
    int? order,
    DraftSide? side,
    DraftActionType? actionType,
    String? heroName,
  }) {
    return DraftAction(
      order: order ?? this.order,
      side: side ?? this.side,
      actionType: actionType ?? this.actionType,
      heroName: heroName ?? this.heroName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order': order,
      'side': side.name,
      'actionType': actionType.name,
      'heroName': heroName,
    };
  }

  factory DraftAction.fromJson(Map<String, dynamic> json) {
    return DraftAction(
      order: json['order'] as int,
      side: DraftSide.values.byName(json['side'] as String),
      actionType: DraftActionType.values.byName(json['actionType'] as String),
      heroName: json['heroName'] as String?,
    );
  }

  @override
  List<Object?> get props => [order, side, actionType, heroName];
}

/// A complete draft session between Blue Side and Red Side.
///
/// The RoV tournament draft sequence (20 total actions):
///
/// **Phase 1 Bans** (6 actions — alternating, Blue starts):
///   0: Blue Ban, 1: Red Ban, 2: Blue Ban, 3: Red Ban, 4: Blue Ban, 5: Red Ban
///
/// **Phase 1 Picks** (6 actions):
///   6: Blue Pick, 7: Red Pick, 8: Red Pick, 9: Blue Pick, 10: Blue Pick, 11: Red Pick
///
/// **Phase 2 Bans** (4 actions — alternating, Blue starts):
///   12: Blue Ban, 13: Red Ban, 14: Blue Ban, 15: Red Ban
///
/// **Phase 2 Picks** (4 actions):
///   16: Red Pick, 17: Blue Pick, 18: Blue Pick, 19: Red Pick
class DraftSession extends Equatable {
  final String id;
  final DateTime createdAt;
  final String? blueTeamName;
  final String? redTeamName;
  final List<DraftAction> actions;
  final int currentActionIndex; // Which step we're on (0..19)

  const DraftSession({
    required this.id,
    required this.createdAt,
    this.blueTeamName,
    this.redTeamName,
    required this.actions,
    this.currentActionIndex = 0,
  });

  // ── Derived getters ────────────────────────────────────────────────

  /// The current [DraftPhase] based on [currentActionIndex].
  DraftPhase get currentPhase {
    if (currentActionIndex < 6) return DraftPhase.phase1Ban;
    if (currentActionIndex < 12) return DraftPhase.phase1Pick;
    if (currentActionIndex < 16) return DraftPhase.phase2Ban;
    if (currentActionIndex < 20) return DraftPhase.phase2Pick;
    return DraftPhase.completed;
  }

  bool get isCompleted => currentActionIndex >= actions.length;

  /// All hero names that have been banned so far.
  List<String> get bannedHeroes => actions
      .where((a) => a.actionType == DraftActionType.ban && a.heroName != null)
      .map((a) => a.heroName!)
      .toList();

  /// All hero names that have been picked so far.
  List<String> get pickedHeroes => actions
      .where((a) => a.actionType == DraftActionType.pick && a.heroName != null)
      .map((a) => a.heroName!)
      .toList();

  /// Heroes no longer available (banned + picked).
  Set<String> get unavailableHeroes =>
      {...bannedHeroes, ...pickedHeroes};

  /// Picks for a specific side.
  List<String> picksForSide(DraftSide side) => actions
      .where((a) =>
          a.side == side &&
          a.actionType == DraftActionType.pick &&
          a.heroName != null)
      .map((a) => a.heroName!)
      .toList();

  /// Bans for a specific side.
  List<String> bansForSide(DraftSide side) => actions
      .where((a) =>
          a.side == side &&
          a.actionType == DraftActionType.ban &&
          a.heroName != null)
      .map((a) => a.heroName!)
      .toList();

  // ── Factory: generate the standard 20-step draft template ───────

  /// Creates a new empty draft session with the correct 20-step sequence.
  factory DraftSession.create({
    required String id,
    String? blueTeamName,
    String? redTeamName,
  }) {
    final actions = <DraftAction>[
      // Phase 1 Bans (indices 0-5)
      const DraftAction(order: 0, side: DraftSide.blue, actionType: DraftActionType.ban),
      const DraftAction(order: 1, side: DraftSide.red, actionType: DraftActionType.ban),
      const DraftAction(order: 2, side: DraftSide.blue, actionType: DraftActionType.ban),
      const DraftAction(order: 3, side: DraftSide.red, actionType: DraftActionType.ban),
      const DraftAction(order: 4, side: DraftSide.blue, actionType: DraftActionType.ban),
      const DraftAction(order: 5, side: DraftSide.red, actionType: DraftActionType.ban),
      // Phase 1 Picks (indices 6-11): Blue 1, Red 2, Blue 2, Red 1
      const DraftAction(order: 6, side: DraftSide.blue, actionType: DraftActionType.pick),
      const DraftAction(order: 7, side: DraftSide.red, actionType: DraftActionType.pick),
      const DraftAction(order: 8, side: DraftSide.red, actionType: DraftActionType.pick),
      const DraftAction(order: 9, side: DraftSide.blue, actionType: DraftActionType.pick),
      const DraftAction(order: 10, side: DraftSide.blue, actionType: DraftActionType.pick),
      const DraftAction(order: 11, side: DraftSide.red, actionType: DraftActionType.pick),
      // Phase 2 Bans (indices 12-15)
      const DraftAction(order: 12, side: DraftSide.blue, actionType: DraftActionType.ban),
      const DraftAction(order: 13, side: DraftSide.red, actionType: DraftActionType.ban),
      const DraftAction(order: 14, side: DraftSide.blue, actionType: DraftActionType.ban),
      const DraftAction(order: 15, side: DraftSide.red, actionType: DraftActionType.ban),
      // Phase 2 Picks (indices 16-19): Red 1, Blue 2, Red 1
      const DraftAction(order: 16, side: DraftSide.red, actionType: DraftActionType.pick),
      const DraftAction(order: 17, side: DraftSide.blue, actionType: DraftActionType.pick),
      const DraftAction(order: 18, side: DraftSide.blue, actionType: DraftActionType.pick),
      const DraftAction(order: 19, side: DraftSide.red, actionType: DraftActionType.pick),
    ];

    return DraftSession(
      id: id,
      createdAt: DateTime.now(),
      blueTeamName: blueTeamName,
      redTeamName: redTeamName,
      actions: actions,
      currentActionIndex: 0,
    );
  }

  // ── Copy / Serialization ───────────────────────────────────────────

  DraftSession copyWith({
    String? id,
    DateTime? createdAt,
    String? blueTeamName,
    String? redTeamName,
    List<DraftAction>? actions,
    int? currentActionIndex,
  }) {
    return DraftSession(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      blueTeamName: blueTeamName ?? this.blueTeamName,
      redTeamName: redTeamName ?? this.redTeamName,
      actions: actions ?? this.actions,
      currentActionIndex: currentActionIndex ?? this.currentActionIndex,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'blueTeamName': blueTeamName,
      'redTeamName': redTeamName,
      'actions': actions.map((a) => a.toJson()).toList(),
      'currentActionIndex': currentActionIndex,
    };
  }

  factory DraftSession.fromJson(Map<String, dynamic> json) {
    return DraftSession(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      blueTeamName: json['blueTeamName'] as String?,
      redTeamName: json['redTeamName'] as String?,
      actions: (json['actions'] as List)
          .map((a) => DraftAction.fromJson(a as Map<String, dynamic>))
          .toList(),
      currentActionIndex: json['currentActionIndex'] as int,
    );
  }

  @override
  List<Object?> get props => [
        id,
        createdAt,
        blueTeamName,
        redTeamName,
        actions,
        currentActionIndex,
      ];

  @override
  String toString() =>
      'DraftSession(id: $id, phase: ${currentPhase.label}, step: $currentActionIndex/20)';
}
