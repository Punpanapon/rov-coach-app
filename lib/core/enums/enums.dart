/// Roles available in RoV (Arena of Valor) competitive play.
enum PlayerRole {
  slayerLane('Slayer Lane'),
  jungle('Jungle'),
  midLane('Mid Lane'),
  abyssalDragonLane('Abyssal Dragon Lane'),
  support('Support');

  const PlayerRole(this.label);
  final String label;
}

/// The two sides in a draft.
enum DraftSide {
  blue('Blue Side'),
  red('Red Side');

  const DraftSide(this.label);
  final String label;
}

/// Granular phases of an RoV tournament draft.
enum DraftPhase {
  phase1Ban('Phase 1 — Bans'),
  phase1Pick('Phase 1 — Picks'),
  phase2Ban('Phase 2 — Bans'),
  phase2Pick('Phase 2 — Picks'),
  completed('Draft Complete');

  const DraftPhase(this.label);
  final String label;
}

/// The action type for each step in the draft sequence.
enum DraftActionType { ban, pick }

/// Win / Loss result for a scrim match.
enum MatchResult {
  win('Win'),
  loss('Loss');

  const MatchResult(this.label);
  final String label;
}
