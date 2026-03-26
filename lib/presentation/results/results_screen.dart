import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:rov_coach/data/models/game_result.dart';
import 'package:rov_coach/presentation/widgets/hero_avatar.dart';
import 'package:rov_coach/providers/game_result_provider.dart';
import 'package:rov_coach/providers/room_provider.dart';
import 'package:rov_coach/providers/strategy_provider.dart';

const _uuid = Uuid();

// ─────────────────────────────────────────────────────────────────────────────
// Hero stat model for analytics
// ─────────────────────────────────────────────────────────────────────────────
class _HeroStat {
  final String name;
  int picks = 0;
  int wins = 0;
  int bans = 0;
  int enemyPicks = 0;
  int enemyWins = 0;
  final Map<String, int> _pairWins = {};
  final Map<String, int> _pairTotal = {};
  final Map<String, int> _vsWins = {};
  final Map<String, int> _vsTotal = {};

  _HeroStat(this.name);

  double get winRate => picks > 0 ? wins / picks * 100 : 0;
  double get pickRate => 0; // set externally
  int get totalAppearances => picks + enemyPicks;

  void addPairWith(String ally, bool won) {
    _pairTotal[ally] = (_pairTotal[ally] ?? 0) + 1;
    if (won) _pairWins[ally] = (_pairWins[ally] ?? 0) + 1;
  }

  void addVs(String enemy, bool won) {
    _vsTotal[enemy] = (_vsTotal[enemy] ?? 0) + 1;
    if (won) _vsWins[enemy] = (_vsWins[enemy] ?? 0) + 1;
  }

  List<MapEntry<String, double>> get bestAllies {
    return _pairTotal.entries
        .where((e) => e.value >= 2)
        .map((e) => MapEntry(
            e.key, (_pairWins[e.key] ?? 0) / e.value * 100))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  List<MapEntry<String, double>> get strongAgainst {
    return _vsTotal.entries
        .where((e) => e.value >= 2)
        .map((e) =>
            MapEntry(e.key, (_vsWins[e.key] ?? 0) / e.value * 100))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  List<MapEntry<String, double>> get weakAgainst {
    return _vsTotal.entries
        .where((e) => e.value >= 2)
        .map((e) =>
            MapEntry(e.key, (_vsWins[e.key] ?? 0) / e.value * 100))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
  }
}

Map<String, _HeroStat> _computeStats(List<GameResult> results) {
  final stats = <String, _HeroStat>{};

  _HeroStat stat(String name) => stats.putIfAbsent(name, () => _HeroStat(name));

  for (final r in results) {
    final won = r.outcome == GameOutcome.victory;

    for (final h in r.ourPicks) {
      final s = stat(h);
      s.picks++;
      if (won) s.wins++;
      // pair synergy
      for (final ally in r.ourPicks) {
        if (ally != h) s.addPairWith(ally, won);
      }
      // matchup vs enemies
      for (final enemy in r.enemyPicks) {
        s.addVs(enemy, won);
      }
    }

    for (final h in r.enemyPicks) {
      final s = stat(h);
      s.enemyPicks++;
      if (!won) s.enemyWins++;
    }

    for (final h in r.ourBans) {
      stat(h).bans++;
    }
    for (final h in r.enemyBans) {
      stat(h).bans++;
    }
  }

  return stats;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Results Screen with tabs
// ─────────────────────────────────────────────────────────────────────────────
class ResultsScreen extends ConsumerStatefulWidget {
  final String roomId;

  const ResultsScreen({super.key, required this.roomId});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(roomIdProvider.notifier).set(widget.roomId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Game Results'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.list_alt), text: 'History'),
              Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _HistoryTab(),
            _AnalyticsTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const _AddResultScreen()),
          ),
          child: const Icon(Icons.add_a_photo),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// History Tab — game results list
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(firestoreMatchResultsProvider);

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (results) => results.isEmpty
          ? const Center(child: Text('No results yet. Tap + to add one.'))
          : _ResultsList(results: results),
    );
  }
}

class _ResultsList extends ConsumerWidget {
  final List<GameResult> results;
  const _ResultsList({required this.results});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final r = results[index];
        final isWin = r.outcome == GameOutcome.victory;

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main row
              SizedBox(
                height: 80,
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: r.imageBytes != null
                          ? Image.memory(r.imageBytes!,
                              fit: BoxFit.cover, height: 80, width: 100)
                          : Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: const Center(
                                  child:
                                      Icon(Icons.sports_esports, size: 28)),
                            ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isWin
                                        ? Colors.green.withAlpha(40)
                                        : Colors.red.withAlpha(40),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    r.outcome.label,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color:
                                          isWin ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ),
                                if (r.gameNumber != null) ...[
                                  const SizedBox(width: 8),
                                  Text('Game ${r.gameNumber}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${r.teamScore} — ${r.enemyScore}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (r.strategyUsed != null)
                              Text(r.strategyUsed!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall),
                          ],
                        ),
                      ),
                    ),
                    // ── Action buttons ──
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          tooltip: 'Edit',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => _EditResultDialog(result: r),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, size: 18,
                              color: Theme.of(context).colorScheme.error),
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _confirmDelete(context, ref, r),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${r.date.day}/${r.date.month}/${r.date.year}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              ),
              // Note row
              if (r.note != null && r.note!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withAlpha(120),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sticky_note_2,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(r.note!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontStyle: FontStyle.italic)),
                      ),
                    ],
                  ),
                ),
              // Draft picks row
              if (r.ourPicks.isNotEmpty)
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      ...r.ourPicks.map((h) => Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: HeroAvatar.fromName(h, size: 24),
                          )),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('vs',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                      ...r.enemyPicks.map((h) => Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: Opacity(
                              opacity: 0.7,
                              child: HeroAvatar.fromName(h, size: 24),
                            ),
                          )),
                      if (r.ourBans.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.block,
                            size: 12,
                            color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 2),
                        ...[...r.ourBans, ...r.enemyBans]
                            .map((h) => Padding(
                                  padding: const EdgeInsets.only(right: 2),
                                  child: Opacity(
                                    opacity: 0.4,
                                    child: HeroAvatar.fromName(h, size: 20),
                                  ),
                                )),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, GameResult r) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Result'),
        content: const Text('Remove this game result permanently?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(gameResultWriterProvider).removeResult(r.id);
              },
              child: const Text('Delete')),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Analytics Tab
// ─────────────────────────────────────────────────────────────────────────────
enum _SortColumn { hero, picks, winRate, bans }

class _AnalyticsTab extends ConsumerStatefulWidget {
  const _AnalyticsTab();

  @override
  ConsumerState<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends ConsumerState<_AnalyticsTab> {
  _SortColumn _sortCol = _SortColumn.picks;
  bool _sortAsc = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<GameResult>>>(
      firestoreMatchResultsProvider,
      (_, next) {
        next.whenData((results) {
          if (results.isEmpty) {
            ref.read(selectedAnalysisHeroesProvider.notifier).clear();
          }
        });
      },
    );

    final resultsAsync = ref.watch(firestoreMatchResultsProvider);

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (results) {
        final withDraft =
            results.where((r) => r.ourPicks.isNotEmpty).toList();
        if (withDraft.isEmpty) {
          if (ref.read(selectedAnalysisHeroesProvider).isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ref.read(selectedAnalysisHeroesProvider.notifier).clear();
            });
          }
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No draft data yet.\nEnd games from the Draft tab to populate analytics.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        final stats = _computeStats(withDraft);
        final totalGames = withDraft.length;
        final totalWins =
            withDraft.where((r) => r.outcome == GameOutcome.victory).length;

        return _buildOverview(context, stats, totalGames, totalWins, withDraft);
      },
    );
  }

  Widget _buildOverview(BuildContext context, Map<String, _HeroStat> stats,
      int totalGames, int totalWins, List<GameResult> results) {
    final cs = Theme.of(context).colorScheme;
    final selectedHeroes = ref.watch(selectedAnalysisHeroesProvider);

    var heroList = stats.values.where((s) => s.picks > 0).toList();

    heroList.sort((a, b) {
      int cmp;
      switch (_sortCol) {
        case _SortColumn.hero:
          cmp = a.name.compareTo(b.name);
        case _SortColumn.picks:
          cmp = a.picks.compareTo(b.picks);
        case _SortColumn.winRate:
          cmp = a.winRate.compareTo(b.winRate);
        case _SortColumn.bans:
          cmp = a.bans.compareTo(b.bans);
      }
      return _sortAsc ? cmp : -cmp;
    });

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            _StatCard(
                label: 'Games', value: '$totalGames', icon: Icons.sports_esports),
            _StatCard(
                label: 'Wins',
                value: '$totalWins',
                icon: Icons.emoji_events,
                color: Colors.green),
            _StatCard(
                label: 'Win Rate',
                value:
                    '${totalGames > 0 ? (totalWins / totalGames * 100).toStringAsFixed(0) : 0}%',
                icon: Icons.percent,
                color: Colors.blue),
            _StatCard(
                label: 'Heroes Used',
                value: '${heroList.length}',
                icon: Icons.people,
                color: Colors.purple),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'Most Banned'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 70,
                    child: Builder(builder: (context) {
                      final banned = stats.values
                          .where((s) => s.bans > 0)
                          .toList()
                        ..sort((a, b) => b.bans.compareTo(a.bans));
                      final top = banned.take(10).toList();
                      if (top.isEmpty) {
                        return const Center(child: Text('No bans recorded'));
                      }
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemCount: top.length,
                        itemBuilder: (_, i) => _BanChip(stat: top[i]),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: _SectionHeader(title: 'Hero Statistics'),
                      ),
                      if (selectedHeroes.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => ref
                              .read(selectedAnalysisHeroesProvider.notifier)
                              .clear(),
                          icon: const Icon(Icons.clear_all, size: 16),
                          label: const Text('Clear Selection'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        sortColumnIndex: _sortCol.index + 1,
                        sortAscending: _sortAsc,
                        columnSpacing: 16,
                        columns: [
                          const DataColumn(label: Text('Pick')),
                          DataColumn(
                            label: const Text('Hero'),
                            onSort: (_, asc) => setState(() {
                              _sortCol = _SortColumn.hero;
                              _sortAsc = asc;
                            }),
                          ),
                          DataColumn(
                            label: const Text('Picks'),
                            numeric: true,
                            onSort: (_, asc) => setState(() {
                              _sortCol = _SortColumn.picks;
                              _sortAsc = asc;
                            }),
                          ),
                          DataColumn(
                            label: const Text('Win %'),
                            numeric: true,
                            onSort: (_, asc) => setState(() {
                              _sortCol = _SortColumn.winRate;
                              _sortAsc = asc;
                            }),
                          ),
                          DataColumn(
                            label: const Text('Bans'),
                            numeric: true,
                            onSort: (_, asc) => setState(() {
                              _sortCol = _SortColumn.bans;
                              _sortAsc = asc;
                            }),
                          ),
                          const DataColumn(label: Text('W-L')),
                        ],
                        rows: heroList.map((s) {
                          final wr = s.winRate;
                          final selected = selectedHeroes.contains(s.name);
                          return DataRow(
                            selected: selected,
                            onSelectChanged: (_) => ref
                                .read(selectedAnalysisHeroesProvider.notifier)
                                .toggleHero(s.name),
                            cells: [
                              DataCell(Checkbox(
                                value: selected,
                                onChanged: (_) => ref
                                    .read(selectedAnalysisHeroesProvider.notifier)
                                    .toggleHero(s.name),
                              )),
                              DataCell(Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  HeroAvatar.fromName(s.name, size: 28),
                                  const SizedBox(width: 8),
                                  Text(s.name,
                                      style: const TextStyle(fontSize: 13)),
                                ],
                              )),
                              DataCell(Text('${s.picks}')),
                              DataCell(Text(
                                '${wr.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: wr >= 60
                                      ? Colors.green
                                      : wr <= 40
                                          ? Colors.red
                                          : null,
                                ),
                              )),
                              DataCell(Text('${s.bans}')),
                              DataCell(Text('${s.wins}-${s.picks - s.wins}')),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withAlpha(90),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: selectedHeroes.isNotEmpty
                    ? _HeroInspectorPanel(
                        selectedHeroes: selectedHeroes,
                        results: results,
                      )
                    : _TeamSynergyPanel(results: results),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroInspectorPanel extends StatelessWidget {
  final List<String> selectedHeroes;
  final List<GameResult> results;

  const _HeroInspectorPanel({
    required this.selectedHeroes,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    final bestTeammates = _topBestTeammates(selectedHeroes, results);
    final worstMatchups = _topWorstMatchups(selectedHeroes, results);
    final recentMatches = _recentHeroMatches(selectedHeroes, results);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Deep Dive Analysis',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: selectedHeroes
              .map((h) => Chip(
                    avatar: HeroAvatar.fromName(h, size: 24),
                    label: Text(h),
                  ))
              .toList(),
        ),
        const SizedBox(height: 20),
        const _SectionHeader(title: 'Best Teammates'),
        const SizedBox(height: 8),
        _AvatarStatRow(entries: bestTeammates, emptyText: 'Not enough winning data'),
        const SizedBox(height: 20),
        const _SectionHeader(title: 'Worst Matchups'),
        const SizedBox(height: 8),
        _AvatarStatRow(entries: worstMatchups, emptyText: 'No recurring losing matchups'),
        const SizedBox(height: 20),
        const _SectionHeader(title: 'Recent Matches'),
        const SizedBox(height: 8),
        if (recentMatches.isEmpty)
          const Text('No recent matches for the selected hero set.')
        else
          ...recentMatches.map((match) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  match.outcome == GameOutcome.victory
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: match.outcome == GameOutcome.victory
                      ? Colors.green
                      : Colors.red,
                ),
                title: Text(
                    '${match.outcome == GameOutcome.victory ? 'Win' : 'Loss'} · ${match.teamScore}-${match.enemyScore}'),
                subtitle: Text(
                    '${match.date.day}/${match.date.month}/${match.date.year}'),
              )),
      ],
    );
  }
}

class _TeamSynergyPanel extends StatelessWidget {
  final List<GameResult> results;

  const _TeamSynergyPanel({required this.results});

  @override
  Widget build(BuildContext context) {
    final topDuos = _topDuoSynergies(results);
    final recentMomentum = results.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Top Performing Combos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        if (topDuos.isEmpty)
          const Text('Not enough duo data yet.')
        else
          ...topDuos.map((duo) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    HeroAvatar.fromName(duo.heroes[0], size: 34),
                    const SizedBox(width: 6),
                    HeroAvatar.fromName(duo.heroes[1], size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${duo.heroes[0]} + ${duo.heroes[1]}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${(duo.winRate * 100).toStringAsFixed(0)}% WR',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${duo.games} games',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              )),
        const SizedBox(height: 12),
        const _SectionHeader(title: 'Recent Momentum'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: recentMomentum
              .map((match) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: match.outcome == GameOutcome.victory
                          ? Colors.green.withAlpha(30)
                          : Colors.red.withAlpha(30),
                    ),
                    child: Text(
                      match.outcome == GameOutcome.victory ? 'W' : 'L',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: match.outcome == GameOutcome.victory
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _AvatarStatRow extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  final String emptyText;

  const _AvatarStatRow({required this.entries, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return Text(emptyText);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: entries
          .take(3)
          .map((e) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HeroAvatar.fromName(e.key, size: 40),
                  const SizedBox(height: 4),
                  Text(e.key,
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                  Text('${e.value}x',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
                ],
              ))
          .toList(),
    );
  }
}

class _DuoStat {
  final List<String> heroes;
  final int games;
  final int wins;

  const _DuoStat({required this.heroes, required this.games, required this.wins});

  double get winRate => games == 0 ? 0 : wins / games;
}

List<MapEntry<String, int>> _topBestTeammates(
    List<String> selectedHeroes, List<GameResult> results) {
  final counts = <String, int>{};
  for (final result in results) {
    if (result.outcome != GameOutcome.victory) continue;
    if (!result.ourPicks.any(selectedHeroes.contains)) continue;
    for (final hero in result.ourPicks) {
      if (selectedHeroes.contains(hero)) continue;
      counts[hero] = (counts[hero] ?? 0) + 1;
    }
  }
  final entries = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries.take(3).toList();
}

List<MapEntry<String, int>> _topWorstMatchups(
    List<String> selectedHeroes, List<GameResult> results) {
  final counts = <String, int>{};
  for (final result in results) {
    if (result.outcome != GameOutcome.defeat) continue;
    if (!result.ourPicks.any(selectedHeroes.contains)) continue;
    for (final hero in result.enemyPicks) {
      counts[hero] = (counts[hero] ?? 0) + 1;
    }
  }
  final entries = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries.take(3).toList();
}

List<GameResult> _recentHeroMatches(
    List<String> selectedHeroes, List<GameResult> results) {
  return results
      .where((result) => result.ourPicks.any(selectedHeroes.contains))
      .take(3)
      .toList();
}

List<_DuoStat> _topDuoSynergies(List<GameResult> results) {
  final stats = <String, List<int>>{};
  for (final result in results) {
    final picks = [...result.ourPicks]..sort();
    for (var i = 0; i < picks.length - 1; i++) {
      for (var j = i + 1; j < picks.length; j++) {
        final key = '${picks[i]}|${picks[j]}';
        final row = stats.putIfAbsent(key, () => [0, 0]);
        row[0] += 1;
        if (result.outcome == GameOutcome.victory) row[1] += 1;
      }
    }
  }

  final duos = <_DuoStat>[];
  stats.forEach((key, value) {
    if (value[0] < 2) return;
    duos.add(_DuoStat(
      heroes: key.split('|'),
      games: value[0],
      wins: value[1],
    ));
  });
  duos.sort((a, b) {
    final wr = b.winRate.compareTo(a.winRate);
    if (wr != 0) return wr;
    return b.games.compareTo(a.games);
  });
  return duos.take(3).toList();
}

// ── Hero detail view ──
class _HeroDetailView extends StatelessWidget {
  final _HeroStat stat;
  final int totalGames;
  final VoidCallback onBack;

  const _HeroDetailView({
    required this.stat,
    required this.totalGames,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final wr = stat.winRate;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Back button
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back to Overview'),
          ),
        ),
        const SizedBox(height: 8),

        // Hero header
        Row(
          children: [
            HeroAvatar.fromName(stat.name, size: 56),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stat.name,
                      style: Theme.of(context).textTheme.headlineSmall),
                  Text(
                    '${stat.picks} picks · ${stat.bans} bans · '
                    '${totalGames > 0 ? (stat.picks / totalGames * 100).toStringAsFixed(0) : 0}% pick rate',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            // Win rate circle
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: wr / 100,
                    strokeWidth: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                        wr >= 60 ? Colors.green : wr <= 40 ? Colors.red : cs.primary),
                  ),
                  Text('${wr.toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Record
        Row(
          children: [
            _StatCard(
                label: 'Wins', value: '${stat.wins}', color: Colors.green,
                icon: Icons.check_circle),
            _StatCard(
                label: 'Losses', value: '${stat.picks - stat.wins}',
                color: Colors.red, icon: Icons.cancel),
            _StatCard(
                label: 'Bans', value: '${stat.bans}',
                color: Colors.orange, icon: Icons.block),
          ],
        ),
        const SizedBox(height: 24),

        // Best allies
        if (stat.bestAllies.isNotEmpty) ...[
          _SectionHeader(title: 'Best Allies (duo win rate)'),
          const SizedBox(height: 8),
          _MatchupList(entries: stat.bestAllies.take(5).toList(), isPositive: true),
          const SizedBox(height: 24),
        ],

        // Strong against
        if (stat.strongAgainst.isNotEmpty) ...[
          _SectionHeader(title: 'Strong Against'),
          const SizedBox(height: 8),
          _MatchupList(entries: stat.strongAgainst.take(5).toList(), isPositive: true),
          const SizedBox(height: 24),
        ],

        // Weak against
        if (stat.weakAgainst.isNotEmpty) ...[
          _SectionHeader(title: 'Weak Against'),
          const SizedBox(height: 8),
          _MatchupList(entries: stat.weakAgainst.take(5).toList(), isPositive: false),
        ],
      ],
    );
  }
}

class _MatchupList extends StatelessWidget {
  final List<MapEntry<String, double>> entries;
  final bool isPositive;

  const _MatchupList({required this.entries, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: entries.map((e) {
        final wr = e.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              HeroAvatar.fromName(e.key, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.key, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: wr / 100,
                        minHeight: 6,
                        backgroundColor: Colors.grey.withAlpha(40),
                        valueColor: AlwaysStoppedAnimation(
                          isPositive
                              ? (wr >= 60 ? Colors.green : Colors.orange)
                              : (wr <= 40 ? Colors.red : Colors.orange),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text('${wr.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: wr >= 60
                        ? Colors.green
                        : wr <= 40
                            ? Colors.red
                            : null,
                  )),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Reusable widgets ──
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color ?? Theme.of(context).colorScheme.primary, size: 22),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text(label,
                  style:
                      Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold));
  }
}

class _BanChip extends StatelessWidget {
  final _HeroStat stat;
  const _BanChip({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            HeroAvatar.fromName(stat.name, size: 40),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${stat.bans}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 48,
          child: Text(stat.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Result Dialog — pre-filled with existing data
// ─────────────────────────────────────────────────────────────────────────────
class _EditResultDialog extends ConsumerStatefulWidget {
  final GameResult result;
  const _EditResultDialog({required this.result});

  @override
  ConsumerState<_EditResultDialog> createState() => _EditResultDialogState();
}

class _EditResultDialogState extends ConsumerState<_EditResultDialog> {
  late GameOutcome _outcome;
  late final TextEditingController _teamScoreCtrl;
  late final TextEditingController _enemyScoreCtrl;
  late final TextEditingController _noteCtrl;
  String? _strategyUsed;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _outcome = widget.result.outcome;
    _teamScoreCtrl =
        TextEditingController(text: '${widget.result.teamScore}');
    _enemyScoreCtrl =
        TextEditingController(text: '${widget.result.enemyScore}');
    _noteCtrl = TextEditingController(text: widget.result.note ?? '');
    _strategyUsed = widget.result.strategyUsed;
  }

  @override
  void dispose() {
    _teamScoreCtrl.dispose();
    _enemyScoreCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final noteText = _noteCtrl.text.trim();
    final updated = GameResult(
      id: widget.result.id,
      imageBytes: widget.result.imageBytes,
      outcome: _outcome,
      teamScore: int.tryParse(_teamScoreCtrl.text) ?? 0,
      enemyScore: int.tryParse(_enemyScoreCtrl.text) ?? 0,
      strategyUsed: _strategyUsed,
      date: widget.result.date,
      ourPicks: widget.result.ourPicks,
      enemyPicks: widget.result.enemyPicks,
      ourBans: widget.result.ourBans,
      enemyBans: widget.result.enemyBans,
      gameNumber: widget.result.gameNumber,
      note: noteText.isEmpty ? null : noteText,
    );

    await ref.read(gameResultWriterProvider).updateResult(updated);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final strategies = ref.watch(strategyListProvider);

    return AlertDialog(
      title: const Text('Edit Result'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Draft picks preview (read-only)
              if (widget.result.ourPicks.isNotEmpty) ...[
                Row(
                  children: [
                    ...widget.result.ourPicks.map((h) => Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: HeroAvatar.fromName(h, size: 24),
                        )),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('vs',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    ...widget.result.enemyPicks.map((h) => Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Opacity(
                            opacity: 0.7,
                            child: HeroAvatar.fromName(h, size: 24),
                          ),
                        )),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Outcome
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Victory'),
                      selected: _outcome == GameOutcome.victory,
                      selectedColor: Colors.green.withAlpha(40),
                      onSelected: (_) =>
                          setState(() => _outcome = GameOutcome.victory),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Defeat'),
                      selected: _outcome == GameOutcome.defeat,
                      selectedColor: Colors.red.withAlpha(40),
                      onSelected: (_) =>
                          setState(() => _outcome = GameOutcome.defeat),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Scores
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
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Strategy
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
                    ...list.map((s) => DropdownMenuItem(
                        value: s.name, child: Text(s.name))),
                  ],
                  onChanged: (v) => setState(() => _strategyUsed = v),
                ),
              ),
              const SizedBox(height: 16),

              // Coach's Note
              TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: "Coach's Note",
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
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save, size: 18),
          label: const Text('Save Changes'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Result screen (manual entry, kept as-is)
// ─────────────────────────────────────────────────────────────────────────────
class _AddResultScreen extends ConsumerStatefulWidget {
  const _AddResultScreen();

  @override
  ConsumerState<_AddResultScreen> createState() => _AddResultScreenState();
}

class _AddResultScreenState extends ConsumerState<_AddResultScreen> {
  Uint8List? _imageBytes;
  GameOutcome _outcome = GameOutcome.victory;
  final _teamScoreCtrl = TextEditingController(text: '0');
  final _enemyScoreCtrl = TextEditingController(text: '0');
  String? _strategyUsed;
  bool _saving = false;

  @override
  void dispose() {
    _teamScoreCtrl.dispose();
    _enemyScoreCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _imageBytes = bytes);
    }
  }

  Future<void> _save() async {
    final teamScore = int.tryParse(_teamScoreCtrl.text) ?? 0;
    final enemyScore = int.tryParse(_enemyScoreCtrl.text) ?? 0;

    setState(() => _saving = true);

    final result = GameResult(
      id: _uuid.v4(),
      imageBytes: _imageBytes,
      outcome: _outcome,
      teamScore: teamScore,
      enemyScore: enemyScore,
      strategyUsed: _strategyUsed,
      date: DateTime.now(),
    );

    await ref.read(gameResultWriterProvider).addResult(result);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final strategies = ref.watch(strategyListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Game Result')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Screenshot ──
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: _imageBytes != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(_imageBytes!, fit: BoxFit.cover),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: cs.surface.withAlpha(200),
                            child:
                                Icon(Icons.edit, size: 16, color: cs.primary),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo,
                            size: 48, color: cs.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text('Tap to upload screenshot',
                            style: TextStyle(color: cs.onSurfaceVariant)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Outcome ──
          DropdownButtonFormField<GameOutcome>(
            initialValue: _outcome,
            decoration: const InputDecoration(
              labelText: 'Result',
              border: OutlineInputBorder(),
            ),
            items: GameOutcome.values
                .map((o) => DropdownMenuItem(
                      value: o,
                      child: Text(
                        o.label,
                        style: TextStyle(
                          color: o == GameOutcome.victory
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _outcome = v);
            },
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
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('—',
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              Expanded(
                child: TextField(
                  controller: _enemyScoreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Enemy Score',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Strategy used ──
          strategies.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
            data: (list) => DropdownButtonFormField<String?>(
              initialValue: _strategyUsed,
              decoration: const InputDecoration(
                labelText: 'Strategy Used (optional)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                ...list.map((s) =>
                    DropdownMenuItem(value: s.name, child: Text(s.name))),
              ],
              onChanged: (v) => setState(() => _strategyUsed = v),
            ),
          ),
          const SizedBox(height: 32),

          // ── Save ──
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Save Result'),
          ),
        ],
      ),
    );
  }
}
