import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rov_coach/data/models/player.dart';
import 'package:rov_coach/data/repositories/player_repository.dart';
import 'package:rov_coach/data/mock_data.dart';

/// Singleton instance of [PlayerRepository].
final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return PlayerRepository();
});

/// Manages the full list of players on the roster.
/// Initialised with mock data, then reads/writes through [PlayerRepository].
final rosterProvider =
    AsyncNotifierProvider<RosterNotifier, List<Player>>(RosterNotifier.new);

final activeRosterProvider =
    NotifierProvider<ActiveRosterNotifier, List<String>>(
        ActiveRosterNotifier.new);

class ActiveRosterNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void setActiveRoster(List<String> playerIds) {
    if (playerIds.length != 5) return;
    state = List<String>.from(playerIds);
  }
}

class RosterNotifier extends AsyncNotifier<List<Player>> {
  PlayerRepository get _repo => ref.read(playerRepositoryProvider);

  @override
  Future<List<Player>> build() async {
    final existing = await _repo.getAll();
    if (existing.isNotEmpty) return existing;

    // First launch — seed with mock data
    for (final player in MockData.players) {
      await _repo.save(player);
    }
    return MockData.players;
  }

  Future<void> addPlayer(Player player) async {
    await _repo.save(player);
    state = AsyncData(await _repo.getAll());
  }

  Future<void> updatePlayer(Player player) async {
    await _repo.save(player);
    state = AsyncData(await _repo.getAll());
  }

  Future<void> removePlayer(String id) async {
    await _repo.delete(id);
    state = AsyncData(await _repo.getAll());
  }
}
