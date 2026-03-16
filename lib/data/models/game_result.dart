import 'dart:convert';
import 'dart:typed_data';
import 'package:equatable/equatable.dart';

/// Victory / Defeat outcome for a game result.
enum GameOutcome {
  victory('Victory'),
  defeat('Defeat');

  const GameOutcome(this.label);
  final String label;
}

/// A recorded game result with an optional screenshot.
///
/// [imageBytes] stores the screenshot as raw bytes (web-safe).
/// On serialisation the bytes are base64-encoded into the JSON string
/// stored in Hive.
class GameResult extends Equatable {
  final String id;
  final Uint8List? imageBytes;
  final GameOutcome outcome;
  final int teamScore;
  final int enemyScore;
  final String? strategyUsed;
  final DateTime date;

  /// Draft picks / bans captured from End-Game flow (optional for legacy data).
  final List<String> ourPicks;
  final List<String> enemyPicks;
  final List<String> ourBans;
  final List<String> enemyBans;
  final int? gameNumber;
  final String? note;

  const GameResult({
    required this.id,
    this.imageBytes,
    required this.outcome,
    required this.teamScore,
    required this.enemyScore,
    this.strategyUsed,
    required this.date,
    this.ourPicks = const [],
    this.enemyPicks = const [],
    this.ourBans = const [],
    this.enemyBans = const [],
    this.gameNumber,
    this.note,
  });

  GameResult copyWith({
    String? id,
    Uint8List? imageBytes,
    GameOutcome? outcome,
    int? teamScore,
    int? enemyScore,
    String? strategyUsed,
    DateTime? date,
    List<String>? ourPicks,
    List<String>? enemyPicks,
    List<String>? ourBans,
    List<String>? enemyBans,
    int? gameNumber,
    String? note,
  }) {
    return GameResult(
      id: id ?? this.id,
      imageBytes: imageBytes ?? this.imageBytes,
      outcome: outcome ?? this.outcome,
      teamScore: teamScore ?? this.teamScore,
      enemyScore: enemyScore ?? this.enemyScore,
      strategyUsed: strategyUsed ?? this.strategyUsed,
      date: date ?? this.date,
      ourPicks: ourPicks ?? this.ourPicks,
      enemyPicks: enemyPicks ?? this.enemyPicks,
      ourBans: ourBans ?? this.ourBans,
      enemyBans: enemyBans ?? this.enemyBans,
      gameNumber: gameNumber ?? this.gameNumber,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'imageBase64': imageBytes != null ? base64Encode(imageBytes!) : null,
        'outcome': outcome.name,
        'teamScore': teamScore,
        'enemyScore': enemyScore,
        'strategyUsed': strategyUsed,
        'date': date.toIso8601String(),
        'ourPicks': ourPicks,
        'enemyPicks': enemyPicks,
        'ourBans': ourBans,
        'enemyBans': enemyBans,
        if (gameNumber != null) 'gameNumber': gameNumber,
        if (note != null) 'note': note,
      };

  factory GameResult.fromJson(Map<String, dynamic> json) {
    Uint8List? bytes;
    if (json['imageBase64'] != null) {
      bytes = base64Decode(json['imageBase64'] as String);
    }
    return GameResult(
      id: json['id'] as String,
      imageBytes: bytes,
      outcome: GameOutcome.values.firstWhere(
        (e) => e.name == json['outcome'],
        orElse: () => GameOutcome.defeat,
      ),
      teamScore: json['teamScore'] as int,
      enemyScore: json['enemyScore'] as int,
      strategyUsed: json['strategyUsed'] as String?,
      date: DateTime.parse(json['date'] as String),
      ourPicks: _stringList(json['ourPicks']),
      enemyPicks: _stringList(json['enemyPicks']),
      ourBans: _stringList(json['ourBans']),
      enemyBans: _stringList(json['enemyBans']),
      gameNumber: json['gameNumber'] as int?,
      note: json['note'] as String?,
    );
  }

  static List<String> _stringList(dynamic v) =>
      v is List ? v.cast<String>() : const [];

  @override
  List<Object?> get props =>
      [id, outcome, teamScore, enemyScore, strategyUsed, date, ourPicks, enemyPicks, ourBans, enemyBans, gameNumber, note];
}
