import 'package:equatable/equatable.dart';
import 'package:rov_coach/core/enums/enums.dart';

/// Represents a player on the esports roster.
class Player extends Equatable {
  final String id;
  final String ign; // In-Game Name (legacy key)
  final PlayerRole mainRole; // legacy key
  final String? name;
  final String? role;
  final String status;
  final List<String> comfortPicks; // Heroes the player has mastered
  final List<String> weakPicks; // Heroes the player needs practice on

  const Player({
    required this.id,
    required this.ign,
    required this.mainRole,
    this.name,
    this.role,
    this.status = 'Active',
    this.comfortPicks = const [],
    this.weakPicks = const [],
  });

  String get displayName => name ?? ign;
  String get displayRole => role ?? mainRole.label;

  Player copyWith({
    String? id,
    String? ign,
    PlayerRole? mainRole,
    String? name,
    String? role,
    String? status,
    List<String>? comfortPicks,
    List<String>? weakPicks,
  }) {
    return Player(
      id: id ?? this.id,
      ign: ign ?? this.ign,
      mainRole: mainRole ?? this.mainRole,
      name: name ?? this.name,
      role: role ?? this.role,
      status: status ?? this.status,
      comfortPicks: comfortPicks ?? this.comfortPicks,
      weakPicks: weakPicks ?? this.weakPicks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ign': ign,
      'mainRole': mainRole.name,
      'name': name ?? ign,
      'role': role ?? mainRole.label,
      'status': status,
      'comfortPicks': comfortPicks,
      'weakPicks': weakPicks,
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      ign: (json['ign'] ?? json['name']) as String,
      mainRole: PlayerRole.values.byName(
          (json['mainRole'] ?? _roleNameFromLabel(json['role'] as String?))
              as String),
      name: json['name'] as String?,
      role: json['role'] as String?,
      status: (json['status'] as String?) ?? 'Active',
      comfortPicks: List<String>.from((json['comfortPicks'] as List?) ?? const []),
      weakPicks: List<String>.from((json['weakPicks'] as List?) ?? const []),
    );
  }

  static String _roleNameFromLabel(String? label) {
    switch (label) {
      case 'Slayer Lane':
        return PlayerRole.slayerLane.name;
      case 'Jungle':
        return PlayerRole.jungle.name;
      case 'Mid Lane':
        return PlayerRole.midLane.name;
      case 'Abyssal Dragon Lane':
        return PlayerRole.abyssalDragonLane.name;
      case 'Support':
        return PlayerRole.support.name;
      default:
        return PlayerRole.slayerLane.name;
    }
  }

  @override
  List<Object?> get props =>
      [id, ign, mainRole, name, role, status, comfortPicks, weakPicks];

  @override
  String toString() => 'Player(id: $id, ign: $ign, role: ${mainRole.label})';
}
