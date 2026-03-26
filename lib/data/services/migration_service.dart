import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:rov_coach/data/models/game_result.dart';

/// One-time migration: copies local Hive results into Firestore.
///
/// Safety guarantees:
/// - Hive data is NEVER deleted.
/// - Uses Firestore batch writes with the same document IDs (idempotent).
/// - Sets a `hasMigratedResults__{roomId}` flag to prevent duplicates.
class MigrationService {
  static const _resultsBox = 'game_results';
  static const _flagsBox = 'migration_flags';

  /// Returns `true` if migration was performed, `false` if skipped.
  static Future<bool> migrateLocalResultsToFirestore(String roomId) async {
    // 1. Check if migration already ran for this room.
    final flagBox = await Hive.openBox<bool>(_flagsBox);
    final flagKey = 'hasMigratedResults__$roomId';
    if (flagBox.get(flagKey, defaultValue: false) == true) {
      return false; // Already migrated
    }

    // 2. Read all local results.
    final resultsBox = await Hive.openBox<String>(_resultsBox);
    final localResults = resultsBox.values
        .map((json) =>
            GameResult.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList();

    if (localResults.isEmpty) {
      // Nothing to migrate — mark as done.
      await flagBox.put(flagKey, true);
      return false;
    }

    // 3. Batch-write to Firestore (max 500 per batch, well within limit).
    final col = FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('match_results');

    final batch = FirebaseFirestore.instance.batch();
    for (final result in localResults) {
      batch.set(col.doc(result.id), result.toJson(), SetOptions(merge: true));
    }
    await batch.commit();

    // 4. Set flag — data is safe in Firestore now.
    await flagBox.put(flagKey, true);

    return true;
  }
}
