import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String uid;
  final String email;
  final String inGameName;
  final String? currentTeamId;
  final List<String> roles;
  final List<String> preferredRoles;
  final List<String> mainHeroes;
  final List<String> nonMainHeroes;

  const UserModel({
    required this.uid,
    required this.email,
    required this.inGameName,
    required this.currentTeamId,
    required this.roles,
    required this.preferredRoles,
    required this.mainHeroes,
    required this.nonMainHeroes,
  });

  UserModel copyWith({
    String? uid,
    String? email,
    String? inGameName,
    String? currentTeamId,
    List<String>? roles,
    List<String>? preferredRoles,
    List<String>? mainHeroes,
    List<String>? nonMainHeroes,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      inGameName: inGameName ?? this.inGameName,
      currentTeamId: currentTeamId ?? this.currentTeamId,
      roles: roles ?? this.roles,
      preferredRoles: preferredRoles ?? this.preferredRoles,
      mainHeroes: mainHeroes ?? this.mainHeroes,
      nonMainHeroes: nonMainHeroes ?? this.nonMainHeroes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'inGameName': inGameName,
      'currentTeamId': currentTeamId,
      'roles': roles,
      'preferredRoles': preferredRoles,
      'mainHeroes': mainHeroes,
      'nonMainHeroes': nonMainHeroes,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      inGameName: json['inGameName'] as String,
      currentTeamId: json['currentTeamId'] as String?,
      roles: List<String>.from((json['roles'] as List?) ?? const []),
      preferredRoles:
          List<String>.from((json['preferredRoles'] as List?) ?? const []),
      mainHeroes:
          List<String>.from((json['mainHeroes'] as List?) ?? const []),
      nonMainHeroes:
          List<String>.from((json['nonMainHeroes'] as List?) ?? const []),
    );
  }

  factory UserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return UserModel.fromJson({
      ...data,
      'uid': doc.id,
    });
  }

  @override
  List<Object?> get props => [
        uid,
        email,
        inGameName,
        currentTeamId,
        roles,
        preferredRoles,
        mainHeroes,
        nonMainHeroes,
      ];
}
