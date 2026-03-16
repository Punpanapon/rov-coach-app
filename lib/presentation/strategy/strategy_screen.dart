import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rov_coach/core/enums/enums.dart';
import 'package:rov_coach/data/models/game_result.dart';
import 'package:rov_coach/providers/room_provider.dart';
import 'package:rov_coach/providers/game_result_provider.dart';
import 'package:rov_coach/providers/strategy_provider.dart';
import 'package:rov_coach/providers/scrim_provider.dart';
import 'package:rov_coach/providers/vod_review_provider.dart';
import 'package:rov_coach/data/models/vod_review.dart';
import 'package:rov_coach/presentation/strategy/strategy_form_screen.dart';
import 'package:rov_coach/presentation/widgets/hero_avatar.dart';

class StrategyScreen extends ConsumerStatefulWidget {
  final String roomId;

  const StrategyScreen({super.key, required this.roomId});

  @override
  ConsumerState<StrategyScreen> createState() => _StrategyScreenState();
}

class _StrategyScreenState extends ConsumerState<StrategyScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(roomIdProvider.notifier).set(widget.roomId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final strategyAsync = ref.watch(strategyListProvider);
    final matchResultsAsync = ref.watch(firestoreMatchResultsProvider);
    final playbooksAsync = ref.watch(firestorePlaybooksProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Strategies'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Team Comps'),
              Tab(text: 'Playbooks'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ── Tab 1: Local strategies (existing) ──
            _buildStrategyList(context, ref, strategyAsync, matchResultsAsync),
            // ── Tab 2: Firestore playbooks ──
            _buildPlaybookList(context, ref, playbooksAsync),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const StrategyFormScreen(),
            ),
          ),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildStrategyList(
      BuildContext context,
      WidgetRef ref,
      AsyncValue strategyAsync,
      AsyncValue<List<GameResult>> matchResultsAsync) {
    return strategyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (strategies) {
        final recs = matchResultsAsync.maybeWhen(
          data: _computeRecommendations,
          orElse: () => const <_CompRecommendation>[],
        );

        if (strategies.isEmpty && recs.isEmpty) {
          return const Center(
              child: Text('No strategies yet. Tap + to create one.'));
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _MetaAnalyzerSection(
              recommendations: recs,
              onSaveMainComp: (rec) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StrategyFormScreen(
                      initialName: rec.isCore
                          ? 'Core ${rec.heroes.take(3).join(' + ')}'
                          : 'Main Comp ${rec.heroes.take(2).join(' + ')}',
                      initialComposition: rec.toRoleComposition(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            for (final strategy in strategies)
              Builder(builder: (context) {
                final winRate = ref.watch(strategyWinRateProvider(strategy.id));
                final winRateText = winRate != null
                    ? '${(winRate * 100).toStringAsFixed(0)}%'
                    : 'No data';

                return Card(
                  child: ListTile(
                    title: Text(strategy.name),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: strategy.composition.allHeroes
                            .map((name) => Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: HeroAvatar.fromName(name, size: 28),
                                ))
                            .toList(),
                      ),
                    ),
                    trailing: Chip(
                      label: Text(winRateText),
                      backgroundColor: winRate != null && winRate >= 0.5
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StrategyFormScreen(strategy: strategy),
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildPlaybookList(BuildContext context, WidgetRef ref,
      AsyncValue<List<SavedPlaybook>> playbooksAsync) {
    return playbooksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (playbooks) => playbooks.isEmpty
          ? const Center(
              child: Text(
                  'No playbooks yet.\nSave one from the VOD Review Board.',
                  textAlign: TextAlign.center))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: playbooks.length,
              itemBuilder: (context, index) {
                final pb = playbooks[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.map_outlined),
                    title: Text(pb.title),
                    subtitle: Text(
                      '${pb.strokes.length} strokes · ${pb.heroes.length} heroes · ${_formatDate(pb.createdAt)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () {
                        ref
                            .read(vodBoardRepositoryProvider)
                            .deletePlaybook(pb.roomId, pb.id);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _CompRecommendation {
  final List<String> heroes;
  final int games;
  final int wins;
  final bool isCore;

  const _CompRecommendation({
    required this.heroes,
    required this.games,
    required this.wins,
    required this.isCore,
  });

  double get winRate => games == 0 ? 0 : wins / games;

  Map<PlayerRole, String?> toRoleComposition() {
    final slots = List<String?>.filled(5, null);
    for (var i = 0; i < heroes.length && i < 5; i++) {
      slots[i] = heroes[i];
    }

    return {
      PlayerRole.slayerLane: slots[0],
      PlayerRole.jungle: slots[1],
      PlayerRole.midLane: slots[2],
      PlayerRole.abyssalDragonLane: slots[3],
      PlayerRole.support: slots[4],
    };
  }
}

List<_CompRecommendation> _computeRecommendations(List<GameResult> results) {
  final fullStats = <String, List<int>>{}; // key -> [games, wins]
  final coreStats = <String, List<int>>{};

  for (final r in results) {
    final picks = [...r.ourPicks]..sort();
    if (picks.isEmpty) continue;
    final won = r.outcome == GameOutcome.victory;

    if (picks.length >= 5) {
      final key = picks.take(5).join('|');
      final row = fullStats.putIfAbsent(key, () => [0, 0]);
      row[0] += 1;
      if (won) row[1] += 1;
    }

    if (picks.length >= 3) {
      final combos = _pickThreeCombos(picks);
      for (final c in combos) {
        final key = c.join('|');
        final row = coreStats.putIfAbsent(key, () => [0, 0]);
        row[0] += 1;
        if (won) row[1] += 1;
      }
    }
  }

  final recs = <_CompRecommendation>[];

  fullStats.forEach((key, v) {
    final games = v[0];
    final wins = v[1];
    final wr = games == 0 ? 0 : wins / games;
    if (games > 1 && wr > 0.5) {
      recs.add(_CompRecommendation(
        heroes: key.split('|'),
        games: games,
        wins: wins,
        isCore: false,
      ));
    }
  });

  coreStats.forEach((key, v) {
    final games = v[0];
    final wins = v[1];
    final wr = games == 0 ? 0 : wins / games;
    if (games > 1 && wr > 0.5) {
      recs.add(_CompRecommendation(
        heroes: key.split('|'),
        games: games,
        wins: wins,
        isCore: true,
      ));
    }
  });

  recs.sort((a, b) {
    final wrCmp = b.winRate.compareTo(a.winRate);
    if (wrCmp != 0) return wrCmp;
    final gCmp = b.games.compareTo(a.games);
    if (gCmp != 0) return gCmp;
    if (a.isCore == b.isCore) return 0;
    return a.isCore ? 1 : -1;
  });

  return recs.take(8).toList();
}

List<List<String>> _pickThreeCombos(List<String> heroes) {
  final out = <List<String>>[];
  for (var i = 0; i < heroes.length - 2; i++) {
    for (var j = i + 1; j < heroes.length - 1; j++) {
      for (var k = j + 1; k < heroes.length; k++) {
        out.add([heroes[i], heroes[j], heroes[k]]);
      }
    }
  }
  return out;
}

class _MetaAnalyzerSection extends StatelessWidget {
  final List<_CompRecommendation> recommendations;
  final ValueChanged<_CompRecommendation> onSaveMainComp;

  const _MetaAnalyzerSection({
    required this.recommendations,
    required this.onSaveMainComp,
  });

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Meta Analyzer',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text(
                'No high-win comp patterns yet. Log more match results to unlock recommendations.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Recommended Comps',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recommendations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final rec = recommendations[i];
              final winRateText = '${(rec.winRate * 100).toStringAsFixed(0)}%';

              return Container(
                width: 260,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: rec.isCore
                                ? Colors.orange.withAlpha(30)
                                : Colors.green.withAlpha(30),
                          ),
                          child: Text(
                            rec.isCore ? 'Core 3' : 'Full 5',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: rec.isCore ? Colors.orange : Colors.green,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text('$winRateText WR',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: rec.heroes
                          .map((h) => HeroAvatar.fromName(h, size: 36))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    Text('${rec.games} matches played together',
                        style: const TextStyle(fontSize: 12)),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () => onSaveMainComp(rec),
                      icon: const Icon(Icons.save, size: 16),
                      label: const Text('Save as Main Comp'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
