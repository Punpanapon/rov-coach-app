import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rov_coach/core/enums/enums.dart';
import 'package:rov_coach/data/models/draft_session.dart';
import 'package:rov_coach/providers/draft_provider.dart';
import 'package:rov_coach/providers/room_provider.dart';
import 'package:rov_coach/providers/roster_provider.dart';
import 'package:rov_coach/providers/strategy_provider.dart';
import 'package:rov_coach/presentation/widgets/hero_selection_modal.dart';
import 'package:rov_coach/presentation/widgets/hero_avatar.dart';

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
    final draft = ref.watch(activeDraftProvider);

    // Listen to Firestore stream and push remote changes into local notifier.
    ref.listen(firestoreDraftProvider, (_, next) {
      next.whenData((remoteDraft) {
        ref.read(activeDraftProvider.notifier).applyRemoteDraft(remoteDraft);
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Draft Simulator'),
            const SizedBox(width: 8),
            _RoomIdChip(roomId: widget.roomId),
          ],
        ),
        actions: [
          if (draft != null) ...[
            IconButton(
              tooltip: 'Undo',
              icon: const Icon(Icons.undo),
              onPressed: draft.currentActionIndex > 0
                  ? () => ref.read(activeDraftProvider.notifier).undo()
                  : null,
            ),
            IconButton(
              tooltip: 'Reset',
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  ref.read(activeDraftProvider.notifier).resetDraft(),
            ),
          ],
        ],
      ),
      body: draft == null
          ? _NoDraftView()
          : _DraftBoardView(draft: draft),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// No draft — start screen
// ─────────────────────────────────────────────────────────────────────────────
class _NoDraftView extends ConsumerStatefulWidget {
  @override
  ConsumerState<_NoDraftView> createState() => _NoDraftViewState();
}

class _NoDraftViewState extends ConsumerState<_NoDraftView> {
  final _blueCtrl = TextEditingController(text: 'Our Team');
  final _redCtrl = TextEditingController(text: 'Opponent');

  @override
  void dispose() {
    _blueCtrl.dispose();
    _redCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_esports,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text('Start a New Draft',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              controller: _blueCtrl,
              decoration: const InputDecoration(
                labelText: 'Blue Side Team',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.circle, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _redCtrl,
              decoration: const InputDecoration(
                labelText: 'Red Side Team',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.circle, color: Colors.red),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                ref.read(activeDraftProvider.notifier).startNewDraft(
                      blueTeamName: _blueCtrl.text.trim().isNotEmpty
                          ? _blueCtrl.text.trim()
                          : 'Blue',
                      redTeamName: _redCtrl.text.trim().isNotEmpty
                          ? _redCtrl.text.trim()
                          : 'Red',
                    );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Draft'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main draft board
// ─────────────────────────────────────────────────────────────────────────────
class _DraftBoardView extends ConsumerWidget {
  final DraftSession draft;
  const _DraftBoardView({required this.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Phase indicator ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: cs.primaryContainer,
          child: Column(
            children: [
              Text(
                draft.isCompleted
                    ? 'Draft Complete!'
                    : draft.currentPhase.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (!draft.isCompleted)
                Text(
                  '${draft.actions[draft.currentActionIndex].side.label} — '
                  '${draft.actions[draft.currentActionIndex].actionType.name.toUpperCase()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),

        // ── Draft board ──
        Expanded(
          child: Row(
            children: [
              // Blue Side
              Expanded(
                child: _SideColumn(
                  draft: draft,
                  side: DraftSide.blue,
                  teamName: draft.blueTeamName ?? 'Blue',
                  color: Colors.blue,
                ),
              ),
              // Divider
              VerticalDivider(width: 1, color: cs.outlineVariant),
              // Red Side
              Expanded(
                child: _SideColumn(
                  draft: draft,
                  side: DraftSide.red,
                  teamName: draft.redTeamName ?? 'Red',
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),

        // ── Bottom bar ──
        if (draft.isCompleted)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(activeDraftProvider.notifier).resetDraft(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('New Draft'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await ref
                          .read(activeDraftProvider.notifier)
                          .saveAndClose();
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save & Close'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// One side column: bans at top, picks below
// ─────────────────────────────────────────────────────────────────────────────
class _SideColumn extends ConsumerWidget {
  final DraftSession draft;
  final DraftSide side;
  final String teamName;
  final Color color;

  const _SideColumn({
    required this.draft,
    required this.side,
    required this.teamName,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bans = draft.actions
        .where((a) => a.side == side && a.actionType == DraftActionType.ban)
        .toList();
    final picks = draft.actions
        .where((a) => a.side == side && a.actionType == DraftActionType.pick)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        // ── Team header ──
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            teamName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ── Bans ──
        Text('BANS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                )),
        const SizedBox(height: 4),
        ...bans.map((a) => _DraftSlot(
              action: a,
              draft: draft,
              isBan: true,
              sideColor: color,
            )),
        const SizedBox(height: 12),

        // ── Picks ──
        Text('PICKS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                )),
        const SizedBox(height: 4),
        ...picks.map((a) => _DraftSlot(
              action: a,
              draft: draft,
              isBan: false,
              sideColor: color,
            )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual ban / pick slot
// ─────────────────────────────────────────────────────────────────────────────
class _DraftSlot extends ConsumerWidget {
  final DraftAction action;
  final DraftSession draft;
  final bool isBan;
  final Color sideColor;

  const _DraftSlot({
    required this.action,
    required this.draft,
    required this.isBan,
    required this.sideColor,
  });

  bool get _isActive =>
      !draft.isCompleted && draft.currentActionIndex == action.order;

  bool get _isFilled => action.heroName != null;
  bool get _isFuture =>
      !_isFilled && draft.currentActionIndex < action.order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    Color bgColor;
    if (_isActive) {
      bgColor = sideColor.withAlpha(50);
    } else if (_isFilled && isBan) {
      bgColor = cs.errorContainer.withAlpha(100);
    } else if (_isFilled) {
      bgColor = cs.primaryContainer;
    } else {
      bgColor = cs.surfaceContainerHighest.withAlpha(80);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _isActive
              ? () => _openHeroSelection(context, ref)
              : null,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                if (_isFilled)
                  Stack(
                    children: [
                      HeroAvatar.fromName(
                        action.heroName!,
                        size: 36,
                      ),
                      if (isBan)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.error.withAlpha(100),
                            ),
                            child: Icon(Icons.block, size: 20, color: cs.error),
                          ),
                        ),
                    ],
                  )
                else if (_isActive)
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: sideColor.withAlpha(30),
                    child: Icon(Icons.touch_app, size: 18, color: sideColor),
                  )
                else
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: cs.surfaceContainerHighest.withAlpha(80),
                    child: Icon(Icons.lock_outline, size: 16,
                        color: cs.onSurfaceVariant.withAlpha(80)),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isFilled
                        ? action.heroName!
                        : _isActive
                            ? 'Tap to select...'
                            : '—',
                    style: TextStyle(
                      fontWeight:
                          _isActive ? FontWeight.bold : FontWeight.normal,
                      color: _isFuture
                          ? cs.onSurfaceVariant.withAlpha(100)
                          : null,
                      decoration: isBan && _isFilled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                if (_isActive)
                  Icon(Icons.chevron_right, size: 18, color: sideColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openHeroSelection(BuildContext context, WidgetRef ref) async {
    // Build smart-suggestion highlights
    final highlights = _buildHighlights(ref);

    final hero = await showHeroSelectionModal(
      context,
      unavailableHeroes: draft.unavailableHeroes,
      highlightedHeroes: highlights,
    );
    if (hero != null) {
      ref.read(activeDraftProvider.notifier).pickHero(hero.name);
    }
  }

  /// Collect comfort picks from all roster players + heroes from all saved
  /// strategies to form the smart suggestion set.
  Set<String> _buildHighlights(WidgetRef ref) {
    // Only highlight during pick phases, not bans
    if (isBan) return {};

    final highlights = <String>{};

    // Comfort picks from roster
    final rosterState = ref.read(rosterProvider);
    rosterState.whenData((players) {
      for (final player in players) {
        highlights.addAll(player.comfortPicks);
      }
    });

    // Heroes from saved strategies
    final strategyState = ref.read(strategyListProvider);
    strategyState.whenData((strategies) {
      for (final s in strategies) {
        highlights.addAll(s.composition.allHeroes);
      }
    });

    return highlights;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Room ID chip
// ─────────────────────────────────────────────────────────────────────────────
class _RoomIdChip extends StatelessWidget {
  final String roomId;
  const _RoomIdChip({required this.roomId});

  @override
  Widget build(BuildContext context) {
    final short = roomId.length > 8 ? roomId.substring(0, 8) : roomId;
    return Tooltip(
      message: 'Room: $roomId\nShare this URL to collaborate',
      child: Chip(
        avatar: Icon(Icons.group, size: 14,
            color: Theme.of(context).colorScheme.primary),
        label: Text(short, style: const TextStyle(fontSize: 11)),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
