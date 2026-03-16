import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rov_coach/data/models/player.dart';
import 'package:rov_coach/presentation/roster/player_form_screen.dart';
import 'package:rov_coach/presentation/widgets/hero_avatar.dart';
import 'package:rov_coach/providers/room_provider.dart';
import 'package:rov_coach/providers/roster_provider.dart';

class RosterScreen extends ConsumerStatefulWidget {
  final String roomId;

  const RosterScreen({super.key, required this.roomId});

  @override
  ConsumerState<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends ConsumerState<RosterScreen> {
  String? _expandedPlayerId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(roomIdProvider.notifier).set(widget.roomId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final rosterAsync = ref.watch(rosterProvider);
    final activeRoster = ref.watch(activeRosterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Roster'),
        actions: [
          IconButton(
            icon: const Icon(Icons.groups_2_outlined),
            tooltip: 'Set Active Roster',
            onPressed: () {
              final players = rosterAsync.asData?.value;
              if (players == null || players.isEmpty) return;
              _openActiveRosterDialog(context, players, activeRoster);
            },
          ),
        ],
      ),
      body: rosterAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (players) {
          if (players.isEmpty) {
            return const Center(child: Text('No players yet. Tap + to add one.'));
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.verified_user),
                  title: const Text('Starting 5'),
                  subtitle: Text(
                    activeRoster.length == 5
                        ? players
                            .where((p) => activeRoster.contains(p.id))
                            .map((p) => p.displayName)
                            .join(', ')
                        : 'Select exactly 5 players for the active lineup',
                  ),
                  trailing: FilledButton(
                    onPressed: () =>
                        _openActiveRosterDialog(context, players, activeRoster),
                    child: const Text('Set Active Roster'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final player in players)
                _PlayerAnalyticsCard(
                  player: player,
                  isActive: activeRoster.contains(player.id),
                  expanded: _expandedPlayerId == player.id,
                  onToggleExpand: () {
                    setState(() {
                      _expandedPlayerId =
                          _expandedPlayerId == player.id ? null : player.id;
                    });
                  },
                  onEdit: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlayerFormScreen(player: player),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const PlayerFormScreen(),
          ),
        ),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _openActiveRosterDialog(
    BuildContext context,
    List<Player> players,
    List<String> currentActive,
  ) {
    final selected = <String>[...currentActive];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Set Active Roster (5 Players)'),
              content: SizedBox(
                width: 420,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Text(
                      'Selected: ${selected.length}/5',
                      style: TextStyle(
                        color: selected.length == 5
                            ? Colors.green
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final player in players)
                      CheckboxListTile(
                        dense: true,
                        value: selected.contains(player.id),
                        title: Text(player.displayName),
                        subtitle: Text(player.displayRole),
                        onChanged: (checked) {
                          setLocalState(() {
                            if (checked == true) {
                              if (!selected.contains(player.id) &&
                                  selected.length < 5) {
                                selected.add(player.id);
                              }
                            } else {
                              selected.remove(player.id);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selected.length == 5
                      ? () {
                          ref
                              .read(activeRosterProvider.notifier)
                              .setActiveRoster(selected);
                          Navigator.pop(ctx);
                        }
                      : null,
                  child: const Text('Save Starting 5'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PlayerAnalyticsCard extends StatelessWidget {
  final Player player;
  final bool isActive;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onEdit;

  const _PlayerAnalyticsCard({
    required this.player,
    required this.isActive,
    required this.expanded,
    required this.onToggleExpand,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (player.status) {
      'On Fire' => Colors.orange,
      'Benched' => Colors.grey,
      _ => Colors.green,
    };

    final signatures = _mockSignatureHeroes(player);

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              child: Text(player.displayName[0].toUpperCase()),
            ),
            title: Row(
              children: [
                Expanded(child: Text(player.displayName)),
                if (isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(30),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('Starting 5',
                        style: TextStyle(fontSize: 11)),
                  ),
              ],
            ),
            subtitle: Text(player.displayRole),
            trailing: Wrap(
              spacing: 4,
              children: [
                Chip(
                  label: Text(player.status, style: const TextStyle(fontSize: 11)),
                  backgroundColor: statusColor.withAlpha(30),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Icon(expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down),
                  onPressed: onToggleExpand,
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                ),
              ],
            ),
            onTap: onToggleExpand,
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const Text(
                    'Signature Heroes',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (signatures.isEmpty)
                    const Text('No hero pool data yet.')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: signatures
                          .map((s) => Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    HeroAvatar.fromName(s.hero, size: 28),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(s.hero,
                                            style:
                                                const TextStyle(fontSize: 12)),
                                        Text('${s.winRate.toStringAsFixed(0)}% WR',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: s.winRate >= 55
                                                  ? Colors.green
                                                  : Colors.orange,
                                            )),
                                      ],
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<_HeroSignature> _mockSignatureHeroes(Player p) {
    final pool = p.comfortPicks.take(3).toList();
    if (pool.isEmpty) return const [];

    return pool.map((h) {
      final seed = (p.id.hashCode ^ h.hashCode).abs() % 21;
      final wr = 45 + seed.toDouble(); // 45%..65% mocked WR
      return _HeroSignature(hero: h, winRate: wr);
    }).toList();
  }
}

class _HeroSignature {
  final String hero;
  final double winRate;

  const _HeroSignature({required this.hero, required this.winRate});
}
