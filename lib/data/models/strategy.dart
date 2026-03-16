import 'package:equatable/equatable.dart';
import 'package:rov_coach/core/enums/enums.dart';

/// A 5-hero draft composition mapped to each competitive role.
class DraftComposition extends Equatable {
  final String slayerLane;
  final String jungle;
  final String midLane;
  final String abyssalDragonLane;
  final String support;

  const DraftComposition({
    required this.slayerLane,
    required this.jungle,
    required this.midLane,
    required this.abyssalDragonLane,
    required this.support,
  });

  /// Returns all hero names in this composition as a list.
  List<String> get allHeroes => [
        slayerLane,
        jungle,
        midLane,
        abyssalDragonLane,
        support,
      ];

  /// Returns the hero assigned to the given [role].
  String heroForRole(PlayerRole role) {
    switch (role) {
      case PlayerRole.slayerLane:
        return slayerLane;
      case PlayerRole.jungle:
        return jungle;
      case PlayerRole.midLane:
        return midLane;
      case PlayerRole.abyssalDragonLane:
        return abyssalDragonLane;
      case PlayerRole.support:
        return support;
    }
  }

  DraftComposition copyWith({
    String? slayerLane,
    String? jungle,
    String? midLane,
    String? abyssalDragonLane,
    String? support,
  }) {
    return DraftComposition(
      slayerLane: slayerLane ?? this.slayerLane,
      jungle: jungle ?? this.jungle,
      midLane: midLane ?? this.midLane,
      abyssalDragonLane: abyssalDragonLane ?? this.abyssalDragonLane,
      support: support ?? this.support,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slayerLane': slayerLane,
      'jungle': jungle,
      'midLane': midLane,
      'abyssalDragonLane': abyssalDragonLane,
      'support': support,
    };
  }

  factory DraftComposition.fromJson(Map<String, dynamic> json) {
    return DraftComposition(
      slayerLane: json['slayerLane'] as String,
      jungle: json['jungle'] as String,
      midLane: json['midLane'] as String,
      abyssalDragonLane: json['abyssalDragonLane'] as String,
      support: json['support'] as String,
    );
  }

  @override
  List<Object?> get props => [
        slayerLane,
        jungle,
        midLane,
        abyssalDragonLane,
        support,
      ];
}

/// Execution guide attached to a strategy.
class ExecutionGuide extends Equatable {
  final String earlyGamePlan;
  final String midLateGamePlan;
  final String keyWinConditions;

  const ExecutionGuide({
    this.earlyGamePlan = '',
    this.midLateGamePlan = '',
    this.keyWinConditions = '',
  });

  ExecutionGuide copyWith({
    String? earlyGamePlan,
    String? midLateGamePlan,
    String? keyWinConditions,
  }) {
    return ExecutionGuide(
      earlyGamePlan: earlyGamePlan ?? this.earlyGamePlan,
      midLateGamePlan: midLateGamePlan ?? this.midLateGamePlan,
      keyWinConditions: keyWinConditions ?? this.keyWinConditions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'earlyGamePlan': earlyGamePlan,
      'midLateGamePlan': midLateGamePlan,
      'keyWinConditions': keyWinConditions,
    };
  }

  factory ExecutionGuide.fromJson(Map<String, dynamic> json) {
    return ExecutionGuide(
      earlyGamePlan: json['earlyGamePlan'] as String? ?? '',
      midLateGamePlan: json['midLateGamePlan'] as String? ?? '',
      keyWinConditions: json['keyWinConditions'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [earlyGamePlan, midLateGamePlan, keyWinConditions];
}

/// A team strategy / composition plan.
class Strategy extends Equatable {
  final String id;
  final String name;
  final DraftComposition composition;
  final ExecutionGuide executionGuide;

  const Strategy({
    required this.id,
    required this.name,
    required this.composition,
    this.executionGuide = const ExecutionGuide(),
  });

  Strategy copyWith({
    String? id,
    String? name,
    DraftComposition? composition,
    ExecutionGuide? executionGuide,
  }) {
    return Strategy(
      id: id ?? this.id,
      name: name ?? this.name,
      composition: composition ?? this.composition,
      executionGuide: executionGuide ?? this.executionGuide,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'composition': composition.toJson(),
      'executionGuide': executionGuide.toJson(),
    };
  }

  factory Strategy.fromJson(Map<String, dynamic> json) {
    return Strategy(
      id: json['id'] as String,
      name: json['name'] as String,
      composition:
          DraftComposition.fromJson(json['composition'] as Map<String, dynamic>),
      executionGuide:
          ExecutionGuide.fromJson(json['executionGuide'] as Map<String, dynamic>),
    );
  }

  @override
  List<Object?> get props => [id, name, composition, executionGuide];

  @override
  String toString() => 'Strategy(id: $id, name: $name)';
}
