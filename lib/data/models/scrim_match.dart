import 'package:equatable/equatable.dart';
import 'package:rov_coach/core/enums/enums.dart';

/// A single practice match (scrim) record linked to a [Strategy].
class ScrimMatch extends Equatable {
  final String id;
  final DateTime matchDate;
  final String opponentTeamName;
  final String strategyId; // Foreign key → Strategy.id
  final MatchResult result;
  final String coachNotes;

  const ScrimMatch({
    required this.id,
    required this.matchDate,
    required this.opponentTeamName,
    required this.strategyId,
    required this.result,
    this.coachNotes = '',
  });

  ScrimMatch copyWith({
    String? id,
    DateTime? matchDate,
    String? opponentTeamName,
    String? strategyId,
    MatchResult? result,
    String? coachNotes,
  }) {
    return ScrimMatch(
      id: id ?? this.id,
      matchDate: matchDate ?? this.matchDate,
      opponentTeamName: opponentTeamName ?? this.opponentTeamName,
      strategyId: strategyId ?? this.strategyId,
      result: result ?? this.result,
      coachNotes: coachNotes ?? this.coachNotes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'matchDate': matchDate.toIso8601String(),
      'opponentTeamName': opponentTeamName,
      'strategyId': strategyId,
      'result': result.name,
      'coachNotes': coachNotes,
    };
  }

  factory ScrimMatch.fromJson(Map<String, dynamic> json) {
    return ScrimMatch(
      id: json['id'] as String,
      matchDate: DateTime.parse(json['matchDate'] as String),
      opponentTeamName: json['opponentTeamName'] as String,
      strategyId: json['strategyId'] as String,
      result: MatchResult.values.byName(json['result'] as String),
      coachNotes: json['coachNotes'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [
        id,
        matchDate,
        opponentTeamName,
        strategyId,
        result,
        coachNotes,
      ];

  @override
  String toString() =>
      'ScrimMatch(id: $id, vs: $opponentTeamName, result: ${result.label})';
}
