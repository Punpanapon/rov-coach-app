import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:uuid/uuid.dart';
import 'package:rov_coach/data/hero_database.dart';
import 'package:rov_coach/data/models/game_result.dart';
import 'package:rov_coach/presentation/widgets/hero_avatar.dart';
import 'package:rov_coach/providers/game_result_provider.dart';
import 'package:rov_coach/providers/roster_provider.dart';
import 'package:rov_coach/providers/room_provider.dart';
import 'package:rov_coach/providers/scrim_draft_provider.dart';
import 'package:rov_coach/providers/strategy_provider.dart';

class DraftScreen extends ConsumerStatefulWidget {
  final String roomId;
  const DraftScreen({super.key, required this.roomId});

  @override
  ConsumerState<DraftScreen> createState() => _DraftScreenState();
}

class _DraftScreenState extends ConsumerState<DraftScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(roomIdProvider.notifier).set(widget.roomId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scrimDraftProvider);

    return switch (state.phase) {
      ScrimPhase.setup => const _SetupPhase(),
      ScrimPhase.drafting => const _DraftingPhase(),
      ScrimPhase.summary => const _SummaryPhase(),
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PHASE 1 — SETUP
// ═══════════════════════════════════════════════════════════════════════════════

class _SetupPhase extends ConsumerStatefulWidget {
  const _SetupPhase();

  @override
  ConsumerState<_SetupPhase> createState() => _SetupPhaseState();
}

class _SetupPhaseState extends ConsumerState<_SetupPhase> {
  final _gamesCtrl = TextEditingController(text: '5');
  final _redraftCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DraftMode _draftMode = DraftMode.global;
  AutoDraftMode _autoDraftMode = AutoDraftMode.custom;

  @override
  void dispose() {
    _gamesCtrl.dispose();
    _redraftCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Smart Draft Coach')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_esports, size: 64, color: cs.primary),
                const SizedBox(height: 8),
                Text('Scrim Setup',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Configure your series before drafting',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 32),

                // Number of Games
                TextField(
                  controller: _gamesCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Number of Games',
                    hintText: 'e.g. 5',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.pin),
                  ),
                ),
                const SizedBox(height: 16),

                // Redraft games
                TextField(
                  controller: _redraftCtrl,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: 'Redraft Game Numbers',
                    hintText: 'e.g. 5,7 (resets global picks)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.refresh),
                  ),
                ),
                const SizedBox(height: 16),

                // Match notes
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Match Notes',
                    hintText: 'e.g. Opponent Team Name / Tournament',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                  ),
                ),
                const SizedBox(height: 24),

                // Auto-draft mode toggle
                Text('Draft Sequence',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<AutoDraftMode>(
                  segments: const [
                    ButtonSegment(
                      value: AutoDraftMode.firstPick,
                      label: Text('1st Pick'),
                      icon: Icon(Icons.looks_one, size: 16),
                    ),
                    ButtonSegment(
                      value: AutoDraftMode.secondPick,
                      label: Text('2nd Pick'),
                      icon: Icon(Icons.looks_two, size: 16),
                    ),
                    ButtonSegment(
                      value: AutoDraftMode.custom,
                      label: Text('Custom'),
                      icon: Icon(Icons.tune, size: 16),
                    ),
                  ],
                  selected: {_autoDraftMode},
                  onSelectionChanged: (v) =>
                      setState(() => _autoDraftMode = v.first),
                ),
                const SizedBox(height: 4),
                Text(
                  _autoDraftMode == AutoDraftMode.custom
                      ? 'Manual mode — freely select bans and picks on either side.'
                      : _autoDraftMode == AutoDraftMode.firstPick
                          ? 'Auto-sequence: your team has first pick. Follows standard RoV B/P order.'
                          : 'Auto-sequence: enemy team has first pick. Follows standard RoV B/P order.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Hero lock mode toggle
                Text('Hero Lock Mode',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<DraftMode>(
                  segments: const [
                    ButtonSegment(
                      value: DraftMode.global,
                      label: Text('Global Ban-Pick'),
                      icon: Icon(Icons.lock, size: 16),
                    ),
                    ButtonSegment(
                      value: DraftMode.normal,
                      label: Text('Normal Ban-Pick'),
                      icon: Icon(Icons.refresh, size: 16),
                    ),
                  ],
                  selected: {_draftMode},
                  onSelectionChanged: (v) =>
                      setState(() => _draftMode = v.first),
                ),
                const SizedBox(height: 4),
                Text(
                  _draftMode == DraftMode.global
                      ? 'Heroes picked in a game are locked for the rest of the series.'
                      : 'Heroes can be reused in every game. Only in-game bans apply.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _startScrim,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Scrim'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startScrim() {
    final totalGames = int.tryParse(_gamesCtrl.text.trim()) ?? 5;
    if (totalGames < 1) return;

    final redraftSet = <int>{};
    for (final part in _redraftCtrl.text.split(RegExp(r'[,\s]+'))) {
      final n = int.tryParse(part.trim());
      if (n != null && n >= 1 && n <= totalGames) redraftSet.add(n);
    }

    ref.read(scrimDraftProvider.notifier).startScrim(
          totalGames: totalGames,
          redraftGames: redraftSet,
          matchNotes: _notesCtrl.text.trim(),
          draftMode: _draftMode,
          autoDraftMode: _autoDraftMode,
        );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PHASE 2 — INTERACTIVE DRAFT BOARD (Side-by-Side)
// ═══════════════════════════════════════════════════════════════════════════════

class _DraftingPhase extends ConsumerStatefulWidget {
  const _DraftingPhase();

  @override
  ConsumerState<_DraftingPhase> createState() => _DraftingPhaseState();
}

class _DraftingPhaseState extends ConsumerState<_DraftingPhase> {
  String _searchQuery = '';
  String? _selectedRole; // null = "All"

  // ── Duo Scroll controllers ──
  final ScrollController _leftScrollCtrl = ScrollController();
  final ScrollController _rightScrollCtrl = ScrollController();
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _leftScrollCtrl.addListener(_onLeftScroll);
    _rightScrollCtrl.addListener(_onRightScroll);
  }

  void _onLeftScroll() {
    if (_isSyncing) return;
    final duoEnabled = ref.read(isDuoScrollEnabledProvider);
    if (!duoEnabled) return;
    if (!_rightScrollCtrl.hasClients) return;
    _isSyncing = true;
    _rightScrollCtrl.jumpTo(_leftScrollCtrl.offset.clamp(
      _rightScrollCtrl.position.minScrollExtent,
      _rightScrollCtrl.position.maxScrollExtent,
    ));
    _isSyncing = false;
  }

  void _onRightScroll() {
    if (_isSyncing) return;
    final duoEnabled = ref.read(isDuoScrollEnabledProvider);
    if (!duoEnabled) return;
    if (!_leftScrollCtrl.hasClients) return;
    _isSyncing = true;
    _leftScrollCtrl.jumpTo(_rightScrollCtrl.offset.clamp(
      _leftScrollCtrl.position.minScrollExtent,
      _leftScrollCtrl.position.maxScrollExtent,
    ));
    _isSyncing = false;
  }

  @override
  void dispose() {
    _leftScrollCtrl.removeListener(_onLeftScroll);
    _rightScrollCtrl.removeListener(_onRightScroll);
    _leftScrollCtrl.dispose();
    _rightScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scrimDraftProvider);
    final cs = Theme.of(context).colorScheme;
    final isRedraft = state.redraftGames.contains(state.currentGame);
    final panelPos = ref.watch(draftPanelPositionProvider);
    final duoEnabled = ref.watch(isDuoScrollEnabledProvider);
    final isGrouped = ref.watch(isGroupedViewProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Game ${state.currentGame} of ${state.totalGames}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            if (state.matchNotes.isNotEmpty)
              Text(state.matchNotes,
                  style:
                      TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
        actions: [
          if (isRedraft)
            Tooltip(
              message: 'This game is a redraft — global picks will reset',
              child: Chip(
                avatar: Icon(Icons.refresh, size: 14, color: cs.tertiary),
                label: Text('Redraft',
                    style: TextStyle(fontSize: 11, color: cs.tertiary)),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ),
          const SizedBox(width: 4),
          // ── Mid-draft mode switcher ──
          SegmentedButton<AutoDraftMode>(
            segments: const [
              ButtonSegment(
                value: AutoDraftMode.firstPick,
                label: Text('1st', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.looks_one, size: 14),
              ),
              ButtonSegment(
                value: AutoDraftMode.secondPick,
                label: Text('2nd', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.looks_two, size: 14),
              ),
              ButtonSegment(
                value: AutoDraftMode.custom,
                label: Text('Free', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.tune, size: 14),
              ),
            ],
            selected: {state.autoDraftMode},
            onSelectionChanged: (v) => ref
                .read(scrimDraftProvider.notifier)
                .switchAutoDraftMode(v.first),
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: () => _confirmEndGame(context),
            child: Text(state.currentGame >= state.totalGames
                ? 'Finish Series'
                : 'End Game ${state.currentGame}'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Auto-draft turn indicator ──
          if (state.isAutoMode) _buildAutoTurnBanner(state, cs),

          // ── Toolbar: tool toggle + legend ──
          _buildToolbar(context, state, cs, duoEnabled, isGrouped),

          // ── Search bar + role chips + settings ──
          if (!isGrouped) _buildSearchAndRoleTabs(cs),

          // ── Main area: Picks & Bans panel + hero grids ──
          Expanded(child: _buildMainArea(state, cs, panelPos, isGrouped)),
        ],
      ),
    );
  }

  /// Builds the main layout with movable Picks & Bans panel
  Widget _buildMainArea(
      ScrimDraftState state, ColorScheme cs, PanelPosition panelPos,
      bool isGrouped) {
    final panel = _PicksAndBansPanel(state: state);
    final heroGrids = _buildHeroGrids(cs, isGrouped);

    final isHorizontalPanel =
        panelPos == PanelPosition.top || panelPos == PanelPosition.bottom;

    if (isHorizontalPanel) {
      final children = panelPos == PanelPosition.top
          ? [panel, Expanded(child: heroGrids)]
          : [Expanded(child: heroGrids), panel];
      return Column(children: children);
    } else {
      final children = panelPos == PanelPosition.left
          ? [panel, Expanded(child: heroGrids)]
          : [Expanded(child: heroGrids), panel];
      return Row(children: children);
    }
  }

  /// Side-by-side hero grids with duo scroll
  Widget _buildHeroGrids(ColorScheme cs, bool isGrouped) {
    return Row(
      children: [
        Expanded(
          child: _TeamGrid(
            side: DraftSide.our,
            searchQuery: _searchQuery,
            roleFilter: isGrouped ? null : _selectedRole,
            scrollController: _leftScrollCtrl,
            isGroupedView: isGrouped,
          ),
        ),
        VerticalDivider(width: 1, thickness: 1, color: cs.outlineVariant),
        Expanded(
          child: _TeamGrid(
            side: DraftSide.enemy,
            searchQuery: _searchQuery,
            roleFilter: isGrouped ? null : _selectedRole,
            scrollController: _rightScrollCtrl,
            isGroupedView: isGrouped,
          ),
        ),
      ],
    );
  }

  /// Horizontal search bar + role filter chips + buttons
  Widget _buildSearchAndRoleTabs(ColorScheme cs) {
    final roles = RoVDatabase.roles;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Search field
          SizedBox(
            width: 180,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (v) =>
                  setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),
          const SizedBox(width: 8),

          // Role chips (horizontal scrollable)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _RoleChip(
                    label: 'All',
                    icon: Icons.grid_view,
                    color: cs.primary,
                    selected: _selectedRole == null,
                    onTap: () => setState(() => _selectedRole = null),
                  ),
                  ...roles.map((role) => Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: _RoleChip(
                          label: role,
                          icon: _RoleSection._roleIcons[role] ?? Icons.person,
                          color: _RoleSection._roleColors[role] ?? Colors.grey,
                          selected: _selectedRole == role,
                          onTap: () => setState(() => _selectedRole = role),
                        ),
                      )),
                ],
              ),
            ),
          ),

          const SizedBox(width: 4),
          // Settings button
          IconButton(
            icon: const Icon(Icons.view_quilt, size: 20),
            tooltip: 'Draft Layout Settings',
            visualDensity: VisualDensity.compact,
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const _DraftSettingsDialog(),
            ),
          ),
        ],
      ),
    );
  }

  /// Auto-draft turn indicator banner.
  Widget _buildAutoTurnBanner(ScrimDraftState state, ColorScheme cs) {
    final turn = state.currentAutoTurn;
    final isComplete = state.isSequenceComplete;
    final isOurTurn = state.currentAutoSide == DraftSide.our;
    final isBan = turn == AutoDraftTurn.ourBan || turn == AutoDraftTurn.enemyBan;

    final bgColor = isComplete
        ? Colors.green.withAlpha(30)
        : isBan
            ? cs.error.withAlpha(25)
            : (isOurTurn ? Colors.blue.withAlpha(25) : Colors.red.withAlpha(25));
    final textColor = isComplete
        ? Colors.green
        : isBan
            ? cs.error
            : (isOurTurn ? Colors.blue : Colors.red);
    final icon = isComplete
        ? Icons.check_circle
        : isBan
            ? Icons.block
            : Icons.check_circle_outline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bgColor,
      child: Row(
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.currentTurnLabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: textColor,
              ),
            ),
          ),
          Text(
            state.autoDraftMode == AutoDraftMode.firstPick ? '1st Pick' : '2nd Pick',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
          if (state.sequenceIndex > 0) ...[
            const SizedBox(width: 8),
            SizedBox(
              height: 28,
              child: OutlinedButton.icon(
                onPressed: () => ref.read(scrimDraftProvider.notifier).undoLastAutoPick(),
                icon: const Icon(Icons.undo, size: 14),
                label: const Text('Undo', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolbar(
      BuildContext context, ScrimDraftState state, ColorScheme cs,
      bool duoEnabled, bool isGrouped) {
    final totalBans =
        state.ourCurrentBans.length + state.enemyCurrentBans.length;
    final totalCurrentPicks =
        state.ourCurrentPicks.length + state.enemyCurrentPicks.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: cs.surfaceContainerHighest.withAlpha(80),
      child: Row(
        children: [
          // In auto mode, show counts only (no toggle). In custom mode, show tool buttons.
          if (!state.isAutoMode) ...[
            _ToolButton(
              icon: Icons.block,
              label: 'Ban',
              color: cs.error,
              selected: state.activeTool == DraftTool.ban,
              count: totalBans,
              onTap: () => ref
                  .read(scrimDraftProvider.notifier)
                  .setTool(DraftTool.ban),
            ),
            const SizedBox(width: 8),
            _ToolButton(
              icon: Icons.check_circle_outline,
              label: 'Pick',
              color: cs.primary,
              selected: state.activeTool == DraftTool.pick,
              count: totalCurrentPicks,
              onTap: () => ref
                  .read(scrimDraftProvider.notifier)
                  .setTool(DraftTool.pick),
            ),
          ] else ...[
            Icon(Icons.block, size: 16, color: cs.error),
            const SizedBox(width: 4),
            Text('$totalBans', style: TextStyle(fontSize: 12, color: cs.error, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Icon(Icons.check_circle_outline, size: 16, color: cs.primary),
            const SizedBox(width: 4),
            Text('$totalCurrentPicks', style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.bold)),
          ],
          const SizedBox(width: 12),
          // Duo Scroll toggle
          Tooltip(
            message: duoEnabled
                ? 'Duo Scroll ON — both grids scroll together'
                : 'Duo Scroll OFF — grids scroll independently',
            child: Material(
              color: duoEnabled
                  ? cs.tertiary.withAlpha(30)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () =>
                    ref.read(isDuoScrollEnabledProvider.notifier).toggle(),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sync,
                          size: 18,
                          color: duoEnabled ? cs.tertiary : Colors.grey),
                      const SizedBox(width: 4),
                      Text('Duo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: duoEnabled
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: duoEnabled ? cs.tertiary : Colors.grey,
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          _LegendDot(color: Colors.grey, label: 'Locked'),
          const SizedBox(width: 10),
          _LegendDot(color: cs.error, label: 'Banned'),
          const SizedBox(width: 10),
          _LegendDot(color: cs.primary.withAlpha(80), label: 'Picked'),
          const SizedBox(width: 10),
          _LegendDot(color: Colors.grey.shade600, label: 'Unavail'),
          if (state.draftMode == DraftMode.normal) ...[
            const SizedBox(width: 10),
            Chip(
              avatar: const Icon(Icons.refresh, size: 12),
              label: const Text('Normal', style: TextStyle(fontSize: 10)),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
          const SizedBox(width: 8),
          // View mode toggle
          Tooltip(
            message: isGrouped
                ? 'Grouped List Mode — switch to Grid'
                : 'Grid Mode — switch to Grouped List',
            child: IconButton(
              icon: Icon(
                isGrouped ? Icons.view_agenda : Icons.grid_view,
                size: 20,
                color: cs.primary,
              ),
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  ref.read(isGroupedViewProvider.notifier).toggle(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out, size: 20),
            tooltip: 'Zoom Out',
            visualDensity: VisualDensity.compact,
            onPressed: () => ref.read(scrimDraftProvider.notifier).zoomOut(),
          ),
          Text('${(ref.watch(draftZoomProvider) * 100).round()}%',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          IconButton(
            icon: const Icon(Icons.zoom_in, size: 20),
            tooltip: 'Zoom In',
            visualDensity: VisualDensity.compact,
            onPressed: () => ref.read(scrimDraftProvider.notifier).zoomIn(),
          ),
          IconButton(
            icon: const Icon(Icons.edit_attributes, size: 20),
            tooltip: 'Edit Hero Roles',
            visualDensity: VisualDensity.compact,
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const _RoleEditorDialog(),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmEndGame(BuildContext context) {
    final state = ref.read(scrimDraftProvider);
    final isLast = state.currentGame >= state.totalGames;

    // Step 1: Intermediate dialog — ask whether to log results
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isLast
            ? 'Finish Series?'
            : 'End Game ${state.currentGame}?'),
        content: const Text(
            'Do you want to log the results of this draft to Analytics?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Skip logging — just end the game
              ref.read(scrimDraftProvider.notifier).endCurrentGame();
            },
            child: const Text('Skip & Clear Board'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              // Step 2: Open full match result form
              showDialog(
                context: context,
                builder: (_) => _MatchResultDialog(
                  isLast: isLast,
                  currentGame: state.currentGame,
                  ourPicks: state.ourCurrentPicks.toList(),
                  enemyPicks: state.enemyCurrentPicks.toList(),
                  ourBans: state.ourCurrentBans.toList(),
                  enemyBans: state.enemyCurrentBans.toList(),
                  nextIsRedraft:
                      state.redraftGames.contains(state.currentGame + 1),
                  onConfirm: () {
                    ref.read(scrimDraftProvider.notifier).endCurrentGame();
                  },
                ),
              );
            },
            icon: const Icon(Icons.analytics, size: 18),
            label: const Text('Log Result'),
          ),
        ],
      ),
    );
  }
}

// ── Match Result Logger Dialog ──
const _dialogUuid = Uuid();

class _MatchResultDialog extends ConsumerStatefulWidget {
  final bool isLast;
  final int currentGame;
  final List<String> ourPicks;
  final List<String> enemyPicks;
  final List<String> ourBans;
  final List<String> enemyBans;
  final bool nextIsRedraft;
  final VoidCallback onConfirm;

  const _MatchResultDialog({
    required this.isLast,
    required this.currentGame,
    required this.ourPicks,
    required this.enemyPicks,
    required this.ourBans,
    required this.enemyBans,
    required this.nextIsRedraft,
    required this.onConfirm,
  });

  @override
  ConsumerState<_MatchResultDialog> createState() =>
      _MatchResultDialogState();
}

class _MatchResultDialogState extends ConsumerState<_MatchResultDialog> {
  GameOutcome _outcome = GameOutcome.victory;
  final _teamScoreCtrl = TextEditingController(text: '0');
  final _enemyScoreCtrl = TextEditingController(text: '0');
  final _noteCtrl = TextEditingController();
  String? _strategyUsed;
  bool _saving = false;

  @override
  void dispose() {
    _teamScoreCtrl.dispose();
    _enemyScoreCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndEnd() async {
    setState(() => _saving = true);

    final result = GameResult(
      id: _dialogUuid.v4(),
      outcome: _outcome,
      teamScore: int.tryParse(_teamScoreCtrl.text) ?? 0,
      enemyScore: int.tryParse(_enemyScoreCtrl.text) ?? 0,
      strategyUsed: _strategyUsed,
      date: DateTime.now(),
      ourPicks: widget.ourPicks,
      enemyPicks: widget.enemyPicks,
      ourBans: widget.ourBans,
      enemyBans: widget.enemyBans,
      gameNumber: widget.currentGame,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );

    await ref.read(gameResultWriterProvider).addResult(result);

    if (mounted) {
      Navigator.pop(context);
      widget.onConfirm();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final strategies = ref.watch(strategyListProvider);

    return AlertDialog(
      title: Text(widget.isLast
          ? 'Finish Series — Log Result'
          : 'End Game ${widget.currentGame} — Log Result'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.isLast && widget.nextIsRedraft)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withAlpha(80)),
                    ),
                    child: Text(
                      'Game ${widget.currentGame + 1} is a REDRAFT — locked picks will reset.',
                      style: TextStyle(
                          color: Colors.orange.shade700, fontSize: 12),
                    ),
                  ),
                ),

              // ── Draft Summary ──
              _DraftSummaryRow(
                label: 'Our Picks',
                heroes: widget.ourPicks,
                color: Colors.blue,
              ),
              const SizedBox(height: 4),
              _DraftSummaryRow(
                label: 'Enemy Picks',
                heroes: widget.enemyPicks,
                color: Colors.red,
              ),
              if (widget.ourBans.isNotEmpty || widget.enemyBans.isNotEmpty) ...[
                const SizedBox(height: 4),
                _DraftSummaryRow(
                  label: 'Bans',
                  heroes: [...widget.ourBans, ...widget.enemyBans],
                  color: Colors.grey,
                  isBan: true,
                ),
              ],
              const Divider(height: 24),

              // ── Outcome toggle ──
              Row(
                children: [
                  Expanded(
                    child: _OutcomeButton(
                      label: 'Victory',
                      icon: Icons.emoji_events,
                      color: Colors.green,
                      selected: _outcome == GameOutcome.victory,
                      onTap: () =>
                          setState(() => _outcome = GameOutcome.victory),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OutcomeButton(
                      label: 'Defeat',
                      icon: Icons.cancel,
                      color: Colors.red,
                      selected: _outcome == GameOutcome.defeat,
                      onTap: () =>
                          setState(() => _outcome = GameOutcome.defeat),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Scores ──
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _teamScoreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Team Score',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('—',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _enemyScoreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Enemy Score',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Strategy ──
              strategies.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (list) => DropdownButtonFormField<String?>(
                  initialValue: _strategyUsed,
                  decoration: const InputDecoration(
                    labelText: 'Strategy Used',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...list.map((s) =>
                        DropdownMenuItem(value: s.name, child: Text(s.name))),
                  ],
                  onChanged: (v) => setState(() => _strategyUsed = v),
                ),
              ),
              const SizedBox(height: 16),

              // ── Coach's Note ──
              TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: "Coach's Note (optional)",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 3,
                minLines: 1,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _saveAndEnd,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save, size: 18),
          label: Text(widget.isLast ? 'Save & Finish' : 'Save & End Game'),
        ),
      ],
    );
  }
}

class _OutcomeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _OutcomeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withAlpha(30) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : Colors.grey.withAlpha(80),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : Colors.grey, size: 28),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? color : Colors.grey,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftSummaryRow extends StatelessWidget {
  final String label;
  final List<String> heroes;
  final Color color;
  final bool isBan;

  const _DraftSummaryRow({
    required this.label,
    required this.heroes,
    required this.color,
    this.isBan = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: heroes.map((h) {
              return Opacity(
                opacity: isBan ? 0.5 : 1.0,
                child: Tooltip(
                  message: h,
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: HeroAvatar.fromName(h, size: 28),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Role filter chip ──
class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withAlpha(30) : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : Colors.grey.withAlpha(80),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: selected ? color : Colors.grey),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? color : Colors.grey,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tool toggle button ──
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withAlpha(30) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: selected ? color : Colors.grey),
              const SizedBox(width: 4),
              Text('$label ($count)',
                  style: TextStyle(
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? color : Colors.grey,
                    fontSize: 13,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEAM GRID — one per side (Our / Enemy)
// ═══════════════════════════════════════════════════════════════════════════════

class _TeamGrid extends ConsumerWidget {
  final DraftSide side;
  final String searchQuery;
  final String? roleFilter;
  final ScrollController? scrollController;
  final bool isGroupedView;

  const _TeamGrid({
    required this.side,
    required this.searchQuery,
    this.roleFilter,
    this.scrollController,
    this.isGroupedView = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scrimDraftProvider);
    final cs = Theme.of(context).colorScheme;
    final isOur = side == DraftSide.our;
    final customRoles = ref.watch(customRolesProvider);
    final zoom = ref.watch(draftZoomProvider);
    final activeRosterIds = ref.watch(activeRosterProvider);
    final rosterState = ref.watch(rosterProvider);

    final lockedPicks =
        isOur ? state.ourLockedPicks : state.enemyLockedPicks;
    final currentPicks =
        isOur ? state.ourCurrentPicks : state.enemyCurrentPicks;
    final currentBans =
        isOur ? state.ourCurrentBans : state.enemyCurrentBans;
    final crossTeamPicks =
        isOur ? state.enemyCurrentPicks : state.ourCurrentPicks;
    final crossTeamBans =
        isOur ? state.enemyCurrentBans : state.ourCurrentBans;

    final teamColor = isOur ? Colors.blue : Colors.red;
    final tileSize = (64 * zoom).roundToDouble();
    final spacing = 6 * (tileSize / 64);

    // Determine if this team's header should glow (active turn)
    final isActiveTeam = state.isAutoMode &&
        !state.isSequenceComplete &&
        state.currentAutoSide == side;
    final isInactiveTeam = state.isAutoMode &&
        !state.isSequenceComplete &&
        state.currentAutoSide != null &&
        state.currentAutoSide != side;

    return Column(
      children: [
        // ── Team header with glow ──
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          decoration: BoxDecoration(
            color: isActiveTeam
                ? teamColor.withAlpha(40)
                : teamColor.withAlpha(isInactiveTeam ? 8 : 20),
            boxShadow: isActiveTeam
                ? [
                    BoxShadow(
                      color: teamColor.withOpacity(0.6),
                      blurRadius: 12,
                      spreadRadius: 4,
                    ),
                  ]
                : [],
          ),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isInactiveTeam ? 0.45 : 1.0,
            child: Row(
              children: [
                if (isActiveTeam)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.play_arrow,
                        size: 16, color: teamColor),
                  ),
                Icon(isOur ? Icons.shield : Icons.flag,
                    size: 14, color: teamColor),
                const SizedBox(width: 6),
                Text(isOur ? 'Our Team' : 'Enemy Team',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: teamColor,
                    )),
                const Spacer(),
                if (lockedPicks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '\u{1F512}${lockedPicks.length}',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ),
                Text(
                  'B:${currentBans.length}  P:${currentPicks.length}',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),

        if (isOur)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: rosterState.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (players) {
                final activePlayers = <dynamic>[];
                for (final id in activeRosterIds) {
                  for (final p in players) {
                    if (p.id == id) {
                      activePlayers.add(p);
                      break;
                    }
                  }
                }

                if (activePlayers.length != 5) {
                  return const Text(
                    'Set Active Roster (5 players) in Roster tab to map picks to players.',
                    style: TextStyle(fontSize: 11, color: Colors.orange),
                  );
                }

                final picked = [...currentPicks]..sort();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Selected Heroes / Players',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(5, (i) {
                        final hero = i < picked.length ? picked[i] : null;
                        final player = activePlayers[i];
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.black.withAlpha(18),
                            ),
                            child: Column(
                              children: [
                                if (hero != null)
                                  HeroAvatar.fromName(hero, size: 24)
                                else
                                  const Icon(Icons.person, size: 24, color: Colors.grey),
                                const SizedBox(height: 2),
                                Text(
                                  player.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),

        // ── Hero content ──
        Expanded(
          child: isGroupedView
              ? _buildGroupedView(
                  context, customRoles, currentPicks,
                  currentBans,
                  tileSize, spacing, cs)
              : _buildFlatGrid(
                  customRoles, currentPicks, currentBans,
                  tileSize, spacing),
        ),
      ],
    );
  }

  /// Flat grid mode (current dense grid)
  Widget _buildFlatGrid(
    Map<String, String> customRoles,
    Set<String> currentPicks,
    Set<String> currentBans,
    double tileSize,
    double spacing,
  ) {
    List<HeroModel> heroes;
    if (roleFilter != null) {
      heroes = RoVDatabase.allHeroes.where((h) {
        final effectiveRole = customRoles[h.name] ?? h.mainRole;
        return effectiveRole == roleFilter;
      }).toList();
    } else {
      heroes = RoVDatabase.allHeroes;
    }

    if (searchQuery.isNotEmpty) {
      heroes = heroes
          .where((h) => h.name.toLowerCase().contains(searchQuery))
          .toList();
    }

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: heroes
            .map((h) => _HeroTile(
                  hero: h,
                  side: side,
                  isCurrentPick: currentPicks.contains(h.name),
                  isBanned: currentBans.contains(h.name),
                  tileSize: tileSize,
                ))
            .toList(),
      ),
    );
  }

  /// Grouped list mode — role headers + hero wraps
  Widget _buildGroupedView(
    BuildContext context,
    Map<String, String> customRoles,
    Set<String> currentPicks,
    Set<String> currentBans,
    double tileSize,
    double spacing,
    ColorScheme cs,
  ) {
    final roles = RoVDatabase.roles;

    // Group heroes by effective role
    Map<String, List<HeroModel>> heroesByRole = {
      for (final r in roles) r: [],
    };
    for (final h in RoVDatabase.allHeroes) {
      final effectiveRole = customRoles[h.name] ?? h.mainRole;
      if (heroesByRole.containsKey(effectiveRole)) {
        heroesByRole[effectiveRole]!.add(h);
      }
    }

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      for (final role in roles) {
        heroesByRole[role] = heroesByRole[role]!
            .where((h) => h.name.toLowerCase().contains(searchQuery))
            .toList();
      }
    }

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        for (final role in roles) ...[
          if ((heroesByRole[role] ?? []).isNotEmpty) ...[
            // Stylish role header
            SliverToBoxAdapter(
              child: _EpicRoleHeader(role: role),
            ),
            // Hero wrap for this role
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              sliver: SliverToBoxAdapter(
                child: Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: heroesByRole[role]!
                      .map((h) => _HeroTile(
                            hero: h,
                            side: side,
                            isCurrentPick: currentPicks.contains(h.name),
                            isBanned: currentBans.contains(h.name),
                            tileSize: tileSize,
                          ))
                      .toList(),
                ),
              ),
            ),
          ],
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 60)),
      ],
    );
  }
}

// ── Role section (header + hero tiles) ──
class _RoleSection extends StatelessWidget {
  final String role;
  final List<HeroModel> heroes;
  final DraftSide side;
  final Set<String> currentPicks;
  final Set<String> currentBans;
  final double tileSize;

  const _RoleSection({
    required this.role,
    required this.heroes,
    required this.side,
    required this.currentPicks,
    required this.currentBans,
    required this.tileSize,
  });

  static const _roleIcons = {
    'Slayer': Icons.local_fire_department,
    'Jungle': Icons.park,
    'Mid': Icons.auto_awesome,
    'Dragon': Icons.whatshot,
    'Support': Icons.shield,
  };

  static const _roleColors = {
    'Slayer': Colors.red,
    'Jungle': Colors.green,
    'Mid': Colors.purple,
    'Dragon': Colors.orange,
    'Support': Colors.blue,
  };

  @override
  Widget build(BuildContext context) {
    final color = _roleColors[role] ?? Colors.grey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Icon(_roleIcons[role] ?? Icons.person,
                  size: 16, color: color),
              const SizedBox(width: 6),
              Text(role.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 1.2,
                  )),
              const SizedBox(width: 8),
              Text('(${heroes.length})',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Wrap(
            spacing: 6 * (tileSize / 64),
            runSpacing: 6 * (tileSize / 64),
            children: heroes
                .map((h) => _HeroTile(
                      hero: h,
                      side: side,
                      isCurrentPick: currentPicks.contains(h.name),
                      isBanned: currentBans.contains(h.name),
                      tileSize: tileSize,
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

// ── Individual hero tile with contextual disabled / picked / banned states ──
class _HeroTile extends ConsumerStatefulWidget {
  final HeroModel hero;
  final DraftSide side;
  final bool isCurrentPick;
  final bool isBanned;
  final double tileSize;

  const _HeroTile({
    required this.hero,
    required this.side,
    required this.isCurrentPick,
    required this.isBanned,
    required this.tileSize,
  });

  @override
  ConsumerState<_HeroTile> createState() => _HeroTileState();
}

class _HeroTileState extends ConsumerState<_HeroTile>
    with SingleTickerProviderStateMixin {
  double get _tileSize => widget.tileSize;

  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.1), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _onTap() {
    final state = ref.read(scrimDraftProvider);

    bool isBanPhase;
    bool isOurTurn;
    if (state.isAutoMode) {
      final turn = state.currentAutoTurn;
      if (turn == null) return;
      isBanPhase =
          turn == AutoDraftTurn.ourBan || turn == AutoDraftTurn.enemyBan;
      isOurTurn =
          turn == AutoDraftTurn.ourBan || turn == AutoDraftTurn.ourPick;
    } else {
      isBanPhase = state.activeTool == DraftTool.ban;
      isOurTurn = widget.side == DraftSide.our;
    }

    final disabled = ref.read(scrimDraftProvider.notifier).isHeroDisabled(
          widget.hero.name,
          isBanPhase: isBanPhase,
          isOurTurn: isOurTurn,
          isGlobalBanPickMode: state.draftMode == DraftMode.global,
        );
    if (disabled) return;

    // Auto-draft mode: route through auto handler
    if (state.isAutoMode) {
      // Only accept taps on the correct side for the current turn
      if (state.currentAutoSide != widget.side) return;
      // Sequence complete — no more taps
      if (state.isSequenceComplete) return;
      _animCtrl.forward(from: 0);
      ref.read(scrimDraftProvider.notifier).handleAutoHeroSelected(widget.hero.name);
      return;
    }

    // Custom (manual) mode: old behavior
    _animCtrl.forward(from: 0);
    ref
        .read(scrimDraftProvider.notifier)
        .toggleHero(widget.hero.name, widget.side);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(scrimDraftProvider);
    final hero = widget.hero;
    final isCurrentPick = widget.isCurrentPick;
    final isBanned = widget.isBanned;

    bool isBanPhase;
    bool isOurTurn;
    if (state.isAutoMode) {
      final turn = state.currentAutoTurn;
      if (turn == null) {
        isBanPhase = true;
        isOurTurn = widget.side == DraftSide.our;
      } else {
        isBanPhase =
            turn == AutoDraftTurn.ourBan || turn == AutoDraftTurn.enemyBan;
        isOurTurn =
            turn == AutoDraftTurn.ourBan || turn == AutoDraftTurn.ourPick;
      }
    } else {
      isBanPhase = state.activeTool == DraftTool.ban;
      isOurTurn = widget.side == DraftSide.our;
    }

    final isDisabled = ref.watch(scrimDraftProvider.notifier).isHeroDisabled(
          hero.name,
          isBanPhase: isBanPhase,
          isOurTurn: isOurTurn,
          isGlobalBanPickMode: state.draftMode == DraftMode.global,
        );

    Widget portrait = _buildPortrait(hero, cs, _tileSize);

    // Contextual disabled state: greyscale + faded + non-interactive.
    if (isDisabled) {
      return IgnorePointer(
        child: SizedBox(
          width: _tileSize,
          height: _tileSize + 18,
          child: Column(
            children: [
              SizedBox(
                width: _tileSize,
                height: _tileSize,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                      Colors.grey, BlendMode.saturation),
                  child: Opacity(
                    opacity: 0.35,
                    child: Stack(
                      children: [
                        portrait,
                        Positioned(
                          right: 2,
                          top: 2,
                          child: Icon(Icons.block,
                              size: 14,
                              color: Colors.white.withAlpha(180)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              _nameLabel(hero, cs, dimmed: true, tileSize: _tileSize),
            ],
          ),
        ),
      );
    }

    // ── AVAILABLE / CURRENT PICK / BANNED — all tappable with pop animation ──
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _onTap,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _tileSize + 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: Colors.amberAccent.withAlpha(140),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: SizedBox(
                width: _tileSize,
                height: _tileSize + 18,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _tileSize,
                      height: _tileSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: _isHovered
                            ? Border.all(
                                color: Colors.amberAccent.withAlpha(200),
                                width: 2)
                            : null,
                      ),
                      child: Stack(
                        children: [
                          // Base image — fade if current pick or banned
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                                _isHovered ? 6 : 8),
                            child: Opacity(
                              opacity:
                                  (isCurrentPick || isBanned) ? 0.3 : 1.0,
                              child: portrait,
                            ),
                          ),

                          // Pick overlay
                          if (isCurrentPick)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.black38,
                                ),
                                child: Icon(Icons.check,
                                    color: cs.primary, size: 28),
                              ),
                            ),

                          // Ban overlay
                          if (isBanned)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: cs.error.withAlpha(100),
                                ),
                                child: Icon(Icons.close,
                                    color: cs.error, size: 32),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    _nameLabel(hero, cs,
                        dimmed: isBanned || isCurrentPick,
                        tileSize: _tileSize),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildPortrait(HeroModel hero, ColorScheme cs, double tileSize) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        hero.imagePath,
        width: tileSize,
        height: tileSize,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: tileSize,
          height: tileSize,
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            hero.name.isNotEmpty ? hero.name[0] : '?',
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  static Widget _nameLabel(HeroModel hero, ColorScheme cs,
      {required bool dimmed, double tileSize = 64}) {
    return SizedBox(
      width: tileSize,
      child: Text(
        hero.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 9 * (tileSize / 64),
          color: dimmed ? cs.onSurfaceVariant.withAlpha(120) : cs.onSurface,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PHASE 3 — SUMMARY (per-team breakdown)
// ═══════════════════════════════════════════════════════════════════════════════

class _SummaryPhase extends ConsumerWidget {
  const _SummaryPhase();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scrimDraftProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Series Summary'),
        actions: [
          TextButton.icon(
            onPressed: () =>
                ref.read(scrimDraftProvider.notifier).resetToSetup(),
            icon: const Icon(Icons.replay),
            label: const Text('New Series'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Match info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.emoji_events, color: cs.primary),
                      const SizedBox(width: 8),
                      Text('Series Complete',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (state.matchNotes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(state.matchNotes,
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 4),
                  Text('${state.totalGames} games played',
                      style: TextStyle(
                          fontSize: 13, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Per-game records
          ...state.draftHistory.map((record) => _GameRecordCard(
                record: record,
                isRedraft: state.redraftGames.contains(record.gameNumber),
              )),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () =>
                  ref.read(scrimDraftProvider.notifier).resetToSetup(),
              icon: const Icon(Icons.replay),
              label: const Text('Start New Series'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameRecordCard extends StatelessWidget {
  final GameRecord record;
  final bool isRedraft;

  const _GameRecordCard({required this.record, required this.isRedraft});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: cs.primaryContainer,
                  child: Text('${record.gameNumber}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer)),
                ),
                const SizedBox(width: 8),
                Text('Game ${record.gameNumber}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                if (isRedraft) ...[
                  const SizedBox(width: 8),
                  Chip(
                    avatar: const Icon(Icons.refresh, size: 12),
                    label: const Text('Redraft',
                        style: TextStyle(fontSize: 10)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Side-by-side team breakdown
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Our Team column
                  Expanded(
                    child: _TeamSummaryColumn(
                      title: 'Our Team',
                      color: Colors.blue,
                      bans: record.ourBans,
                      picks: record.ourPicks,
                    ),
                  ),
                  VerticalDivider(
                    width: 24,
                    thickness: 1,
                    color: cs.outlineVariant,
                  ),
                  // Enemy Team column
                  Expanded(
                    child: _TeamSummaryColumn(
                      title: 'Enemy Team',
                      color: Colors.red,
                      bans: record.enemyBans,
                      picks: record.enemyPicks,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamSummaryColumn extends StatelessWidget {
  final String title;
  final Color color;
  final Set<String> bans;
  final Set<String> picks;

  const _TeamSummaryColumn({
    required this.title,
    required this.color,
    required this.bans,
    required this.picks,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            )),
        const SizedBox(height: 8),

        // Bans
        Text('BANS (${bans.length})',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: cs.error,
                letterSpacing: 1)),
        const SizedBox(height: 4),
        bans.isEmpty
            ? Text('No bans',
                style:
                    TextStyle(fontSize: 11, color: cs.onSurfaceVariant))
            : Wrap(
                spacing: 4,
                runSpacing: 4,
                children: bans
                    .map((name) =>
                        _MiniHeroChip(name: name, color: cs.error))
                    .toList(),
              ),
        const SizedBox(height: 10),

        // Picks
        Text('PICKS (${picks.length})',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: cs.primary,
                letterSpacing: 1)),
        const SizedBox(height: 4),
        picks.isEmpty
            ? Text('No picks',
                style:
                    TextStyle(fontSize: 11, color: cs.onSurfaceVariant))
            : Wrap(
                spacing: 4,
                runSpacing: 4,
                children: picks
                    .map((name) =>
                        _MiniHeroChip(name: name, color: cs.primary))
                    .toList(),
              ),
      ],
    );
  }
}

class _MiniHeroChip extends StatelessWidget {
  final String name;
  final Color color;
  const _MiniHeroChip({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    final hero = RoVDatabase.findByName(name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: hero != null
                ? Image.asset(
                    hero.imagePath,
                    width: 20,
                    height: 20,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _letterFallback(name),
                  )
                : _letterFallback(name),
          ),
          const SizedBox(width: 4),
          Text(name, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  static Widget _letterFallback(String name) {
    return Container(
      width: 20,
      height: 20,
      color: Colors.grey.shade700,
      alignment: Alignment.center,
      child: Text(name.isNotEmpty ? name[0] : '?',
          style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PICKS & BANS PANEL — movable to Top/Bottom/Left/Right
// ═══════════════════════════════════════════════════════════════════════════════

class _PicksAndBansPanel extends ConsumerWidget {
  final ScrimDraftState state;
  const _PicksAndBansPanel({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final panelPos = ref.watch(draftPanelPositionProvider);
    final isVertical =
        panelPos == PanelPosition.left || panelPos == PanelPosition.right;

    final ourPicks = state.ourCurrentPicks.toList();
    final enemyPicks = state.enemyCurrentPicks.toList();
    final ourBans = state.ourCurrentBans.toList();
    final enemyBans = state.enemyCurrentBans.toList();

    // Determine turn label
    final isBanPhase = state.activeTool == DraftTool.ban;
    final turnLabel = isBanPhase ? 'BAN PHASE' : 'PICK PHASE';
    final turnColor = isBanPhase ? cs.error : cs.primary;

    final border = isVertical
        ? Border(
            left: panelPos == PanelPosition.right
                ? BorderSide(color: cs.outlineVariant.withAlpha(80))
                : BorderSide.none,
            right: panelPos == PanelPosition.left
                ? BorderSide(color: cs.outlineVariant.withAlpha(80))
                : BorderSide.none,
          )
        : Border(
            top: panelPos == PanelPosition.bottom
                ? BorderSide(color: cs.outlineVariant.withAlpha(80))
                : BorderSide.none,
            bottom: panelPos == PanelPosition.top
                ? BorderSide(color: cs.outlineVariant.withAlpha(80))
                : BorderSide.none,
          );

    final content = isVertical
        ? _buildVerticalPanel(
            cs, ourPicks, enemyPicks, ourBans, enemyBans,
            turnLabel, turnColor)
        : _buildHorizontalPanel(
            cs, ourPicks, enemyPicks, ourBans, enemyBans,
            turnLabel, turnColor);

    return Container(
      width: isVertical ? 110 : null,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(60),
        border: border,
      ),
      child: content,
    );
  }

  /// Horizontal layout (Top / Bottom) — full-width row
  Widget _buildHorizontalPanel(
    ColorScheme cs,
    List<String> ourPicks,
    List<String> enemyPicks,
    List<String> ourBans,
    List<String> enemyBans,
    String turnLabel,
    Color turnColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          // ── Our Team ──
          Expanded(
            child: Row(
              children: [
                _TeamLabel(
                    label: 'OUR', icon: Icons.shield, color: Colors.blueAccent),
                const SizedBox(width: 4),
                // Bans
                ...ourBans.map((name) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child:
                          _MiniSlot(heroName: name, color: cs.error, size: 36),
                    )),
                if (ourBans.isNotEmpty && ourPicks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                        width: 1, height: 36, color: cs.outlineVariant),
                  ),
                // Picks
                ...List.generate(5, (i) {
                  final name = i < ourPicks.length ? ourPicks[i] : null;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _GlowHeroSlot(
                        heroName: name, glowColor: Colors.blueAccent, size: 44),
                  );
                }),
              ],
            ),
          ),

          // ── Turn Indicator ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _PulsingTurnBadge(
              label: turnLabel,
              color: turnColor,
            ),
          ),

          // ── Enemy Team ──
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Picks
                ...List.generate(5, (i) {
                  final name = i < enemyPicks.length ? enemyPicks[i] : null;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _GlowHeroSlot(
                        heroName: name, glowColor: Colors.redAccent, size: 44),
                  );
                }),
                if (enemyBans.isNotEmpty && enemyPicks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                        width: 1, height: 36, color: cs.outlineVariant),
                  ),
                // Bans
                ...enemyBans.map((name) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child:
                          _MiniSlot(heroName: name, color: cs.error, size: 36),
                    )),
                const SizedBox(width: 4),
                _TeamLabel(
                    label: 'ENEMY', icon: Icons.flag, color: Colors.redAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Vertical layout (Left / Right) — narrow sidebar
  Widget _buildVerticalPanel(
    ColorScheme cs,
    List<String> ourPicks,
    List<String> enemyPicks,
    List<String> ourBans,
    List<String> enemyBans,
    String turnLabel,
    Color turnColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Our Team ──
          _TeamLabel(
              label: 'OUR', icon: Icons.shield, color: Colors.blueAccent),
          const SizedBox(height: 4),
          Text('PICKS',
              style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                  letterSpacing: 1)),
          const SizedBox(height: 2),
          ...List.generate(5, (i) {
            final name = i < ourPicks.length ? ourPicks[i] : null;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: _GlowHeroSlot(
                  heroName: name, glowColor: Colors.blueAccent, size: 44),
            );
          }),
          if (ourBans.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('BANS',
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: cs.error,
                    letterSpacing: 1)),
            const SizedBox(height: 2),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: ourBans
                  .map((name) =>
                      _MiniSlot(heroName: name, color: cs.error, size: 30))
                  .toList(),
            ),
          ],

          // ── Turn indicator ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _PulsingTurnBadge(
              label: turnLabel,
              color: turnColor,
              compact: true,
            ),
          ),

          // ── Enemy Team ──
          _TeamLabel(
              label: 'ENEMY', icon: Icons.flag, color: Colors.redAccent),
          const SizedBox(height: 4),
          Text('PICKS',
              style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                  letterSpacing: 1)),
          const SizedBox(height: 2),
          ...List.generate(5, (i) {
            final name = i < enemyPicks.length ? enemyPicks[i] : null;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: _GlowHeroSlot(
                  heroName: name, glowColor: Colors.redAccent, size: 44),
            );
          }),
          if (enemyBans.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('BANS',
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: cs.error,
                    letterSpacing: 1)),
            const SizedBox(height: 2),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: enemyBans
                  .map((name) =>
                      _MiniSlot(heroName: name, color: cs.error, size: 30))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small team label (icon + text)
class _TeamLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _TeamLabel(
      {required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        Text(label,
            style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 1)),
      ],
    );
  }
}

/// Mini slot for banned heroes (smaller, red-tinted) with lock-in animation
class _MiniSlot extends StatelessWidget {
  final String heroName;
  final Color color;
  final double size;
  const _MiniSlot(
      {required this.heroName, required this.color, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('ban_$heroName'),
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withAlpha(100), width: 1),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: HeroAvatar.fromName(
                heroName,
                size: size,
                shape: BoxShape.rectangle,
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: color.withAlpha(80),
                ),
                child: Icon(Icons.close, color: color, size: size * 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PULSING TURN BADGE — epic broadcast-style phase indicator
// ═══════════════════════════════════════════════════════════════════════════════

class _PulsingTurnBadge extends StatefulWidget {
  final String label;
  final Color color;
  final bool compact;

  const _PulsingTurnBadge({
    required this.label,
    required this.color,
    this.compact = false,
  });

  @override
  State<_PulsingTurnBadge> createState() => _PulsingTurnBadgeState();
}

class _PulsingTurnBadgeState extends State<_PulsingTurnBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        return Container(
          padding: widget.compact
              ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: widget.color.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.color.withAlpha(
                  (100 + 100 * _pulseAnim.value).round()),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color
                    .withAlpha((60 * _pulseAnim.value).round()),
                blurRadius: 12 * _pulseAnim.value,
                spreadRadius: 2 * _pulseAnim.value,
              ),
            ],
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: widget.compact ? 9 : 12,
              fontWeight: FontWeight.w900,
              color: widget.color,
              letterSpacing: 1.5,
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EPIC ROLE HEADER — stylish role divider for grouped list mode
// ═══════════════════════════════════════════════════════════════════════════════

class _EpicRoleHeader extends StatelessWidget {
  final String role;
  const _EpicRoleHeader({required this.role});

  static const _roleEmojis = {
    'Slayer': '\u2694\uFE0F',
    'Jungle': '\uD83C\uDF3F',
    'Mid': '\u2728',
    'Dragon': '\uD83D\uDD25',
    'Support': '\uD83D\uDEE1\uFE0F',
  };

  @override
  Widget build(BuildContext context) {
    final color = _RoleSection._roleColors[role] ?? Colors.grey;
    final icon = _RoleSection._roleIcons[role] ?? Icons.person;
    final emoji = _roleEmojis[role] ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withAlpha(40),
            color.withAlpha(10),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: color, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text('$emoji ${role.toUpperCase()}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: 2,
              )),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withAlpha(80), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowHeroSlot extends StatelessWidget {
  final String? heroName;
  final Color glowColor;
  final double size;
  const _GlowHeroSlot(
      {required this.heroName, required this.glowColor, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (heroName == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: glowColor.withAlpha(40), width: 1.5),
        ),
        child: Icon(Icons.person_outline,
            size: size * 0.45, color: glowColor.withAlpha(60)),
      );
    }

    // Lock-in animation: scale from 0.5 → 1.0 with easeOutBack
    return TweenAnimationBuilder<double>(
      key: ValueKey('slot_$heroName'),
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: glowColor.withAlpha(130),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: HeroAvatar.fromName(
            heroName!,
            size: size,
            shape: BoxShape.rectangle,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DRAFT SETTINGS DIALOG — controls panel position + duo scroll
// ═══════════════════════════════════════════════════════════════════════════════

class _DraftSettingsDialog extends ConsumerWidget {
  const _DraftSettingsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final panelPos = ref.watch(draftPanelPositionProvider);
    final duoEnabled = ref.watch(isDuoScrollEnabledProvider);
    final draftState = ref.watch(scrimDraftProvider);

    return PointerInterceptor(
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.view_quilt, color: cs.primary),
            const SizedBox(width: 8),
            const Text('Draft Layout Settings'),
          ],
        ),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Panel Position ──
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Picks & Bans Panel Position',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      )),
                ),
              ),
              ...PanelPosition.values.map((p) =>
                  RadioListTile<PanelPosition>(
                    title: Text(_posLabel(p)),
                    secondary: Icon(_posIcon(p), size: 20),
                    value: p,
                    groupValue: panelPos,
                    dense: true,
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(draftPanelPositionProvider.notifier).set(v);
                      }
                    },
                  )),
              const Divider(),
              // ── Draft sequence mode ──
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Draft Sequence Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      )),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SegmentedButton<AutoDraftMode>(
                  segments: const [
                    ButtonSegment(
                      value: AutoDraftMode.firstPick,
                      label: Text('1st Pick'),
                      icon: Icon(Icons.looks_one, size: 14),
                    ),
                    ButtonSegment(
                      value: AutoDraftMode.secondPick,
                      label: Text('2nd Pick'),
                      icon: Icon(Icons.looks_two, size: 14),
                    ),
                    ButtonSegment(
                      value: AutoDraftMode.custom,
                      label: Text('Custom'),
                      icon: Icon(Icons.tune, size: 14),
                    ),
                  ],
                  selected: {draftState.autoDraftMode},
                  onSelectionChanged: (value) {
                    ref
                        .read(scrimDraftProvider.notifier)
                        .switchAutoDraftMode(value.first);
                  },
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  draftState.autoDraftMode == AutoDraftMode.custom
                      ? 'Manual mode: pick/ban can be selected freely.'
                      : draftState.autoDraftMode == AutoDraftMode.firstPick
                          ? 'Auto mode: your team takes the first pick sequence.'
                          : 'Auto mode: enemy team takes the first pick sequence.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
              const Divider(),
              // ── Duo Scroll ──
              SwitchListTile(
                title: const Text('Duo Scroll'),
                subtitle: Text(duoEnabled
                    ? 'Both team grids scroll together'
                    : 'Grids scroll independently'),
                secondary: Icon(
                  Icons.sync,
                  color: duoEnabled ? cs.tertiary : cs.onSurfaceVariant,
                ),
                value: duoEnabled,
                onChanged: (v) =>
                    ref.read(isDuoScrollEnabledProvider.notifier).set(v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              ref
                  .read(draftPanelPositionProvider.notifier)
                  .set(PanelPosition.top);
              ref.read(isDuoScrollEnabledProvider.notifier).set(true);
            },
            icon: const Icon(Icons.restore, size: 18),
            label: const Text('Reset to Default'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  static String _posLabel(PanelPosition p) => switch (p) {
        PanelPosition.top => 'Top',
        PanelPosition.bottom => 'Bottom',
        PanelPosition.left => 'Left',
        PanelPosition.right => 'Right',
      };

  static IconData _posIcon(PanelPosition p) => switch (p) {
        PanelPosition.top => Icons.vertical_align_top,
        PanelPosition.bottom => Icons.vertical_align_bottom,
        PanelPosition.left => Icons.align_horizontal_left,
        PanelPosition.right => Icons.align_horizontal_right,
      };
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROLE EDITOR DIALOG — override hero roles for custom meta
// ═══════════════════════════════════════════════════════════════════════════════

class _RoleEditorDialog extends ConsumerStatefulWidget {
  const _RoleEditorDialog();

  @override
  ConsumerState<_RoleEditorDialog> createState() => _RoleEditorDialogState();
}

class _RoleEditorDialogState extends ConsumerState<_RoleEditorDialog> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final customRoles = ref.watch(customRolesProvider);
    final roles = RoVDatabase.roles;

    var heroes = RoVDatabase.allHeroes;
    if (_filter.isNotEmpty) {
      heroes = heroes
          .where((h) => h.name.toLowerCase().contains(_filter))
          .toList();
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit_attributes, color: cs.primary),
          const SizedBox(width: 8),
          const Expanded(child: Text('Edit Hero Roles')),
          if (customRoles.isNotEmpty)
            TextButton(
              onPressed: () =>
                  ref.read(scrimDraftProvider.notifier).resetAllCustomRoles(),
              child: Text('Reset All (${customRoles.length})'),
            ),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: 500,
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Search heroes...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
              onChanged: (v) => setState(() => _filter = v.toLowerCase()),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: heroes.length,
                itemBuilder: (context, index) {
                  final hero = heroes[index];
                  final effectiveRole =
                      customRoles[hero.name] ?? hero.mainRole;
                  final isCustom = customRoles.containsKey(hero.name);

                  return ListTile(
                    dense: true,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        hero.imagePath,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 32,
                          height: 32,
                          color: Colors.grey.shade800,
                          alignment: Alignment.center,
                          child: Text(
                            hero.name.isNotEmpty ? hero.name[0] : '?',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                    title: Text(hero.name,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: isCustom
                        ? Text('Default: ${hero.mainRole}',
                            style: TextStyle(
                                fontSize: 10, color: cs.onSurfaceVariant))
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButton<String>(
                          value: effectiveRole,
                          underline: const SizedBox.shrink(),
                          isDense: true,
                          style: TextStyle(
                            fontSize: 12,
                            color: isCustom ? cs.primary : cs.onSurface,
                            fontWeight: isCustom
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          items: roles
                              .map((r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r),
                                  ))
                              .toList(),
                          onChanged: (newRole) {
                            if (newRole == null) return;
                            if (newRole == hero.mainRole) {
                              ref
                                  .read(scrimDraftProvider.notifier)
                                  .resetCustomRole(hero.name);
                            } else {
                              ref
                                  .read(scrimDraftProvider.notifier)
                                  .setCustomRole(hero.name, newRole);
                            }
                          },
                        ),
                        if (isCustom)
                          IconButton(
                            icon: Icon(Icons.undo,
                                size: 16, color: cs.onSurfaceVariant),
                            tooltip: 'Reset to ${hero.mainRole}',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => ref
                                .read(scrimDraftProvider.notifier)
                                .resetCustomRole(hero.name),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
