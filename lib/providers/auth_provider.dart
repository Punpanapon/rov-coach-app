import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rov_coach/data/models/user_model.dart';
import 'package:rov_coach/data/services/user_profile_service.dart';
import 'package:rov_coach/services/auth_service.dart';

const _adminEmail = 'thpunpun@gmail.com';
const _adminRoles = ['admin', 'manager', 'coach', 'member', 'tester'];

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final userProfileServiceProvider = Provider<UserProfileService>((ref) {
  return UserProfileService();
});

final userProfileProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(userProfileServiceProvider).profileStream(user.uid);
    },
    orElse: () => Stream.value(null),
  );
});

final authActionsProvider = Provider<AuthActions>((ref) {
  return AuthActions(ref);
});

class AuthActions {
  final Ref ref;
  AuthActions(this.ref);

  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    final authService = ref.read(authServiceProvider);
    final profileService = ref.read(userProfileServiceProvider);
    UserCredential credential;
    try {
      credential = await authService.signInWithEmail(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapAuthError(e));
    }
    final user = credential.user;
    if (user == null) {
      throw StateError('Login failed.');
    }

    final existing = await profileService.fetchProfile(user.uid);
    if (existing != null) return existing;

    final fallback = UserModel(
      uid: user.uid,
      email: user.email ?? email,
      inGameName: _fallbackInGameName(user.email ?? email),
      currentTeamId: null,
      roles: const ['tester'],
      preferredRoles: const [],
      mainHeroes: const [],
      nonMainHeroes: const [],
    );
    await profileService.upsertProfile(fallback);
    return fallback;
  }

  Future<void> register({
    required String email,
    required String password,
    required String inGameName,
    required List<String> preferredRoles,
    required List<String> mainHeroes,
    required List<String> nonMainHeroes,
  }) async {
    final authService = ref.read(authServiceProvider);
    final profileService = ref.read(userProfileServiceProvider);
    UserCredential credential;
    try {
      credential = await authService.registerWithEmail(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapAuthError(e));
    }
    final user = credential.user;
    if (user == null) {
      throw StateError('Registration failed.');
    }

    // Firebase enforces a 6+ char minimum password; use at least 123456 for
    // the admin test account to avoid weak-password errors.
    final normalizedEmail = (user.email ?? email).trim().toLowerCase();
    final roles = normalizedEmail == _adminEmail
        ? _adminRoles
        : const ['tester'];

    final profile = UserModel(
      uid: user.uid,
      email: user.email ?? email,
      inGameName: inGameName,
      currentTeamId: null,
      roles: roles,
      preferredRoles: preferredRoles,
      mainHeroes: mainHeroes,
      nonMainHeroes: nonMainHeroes,
    );

    await profileService.upsertProfile(profile);
  }

  Future<void> logout() async {
    await ref.read(authServiceProvider).signOut();
  }
}

class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);

  @override
  String toString() => message;
}

String _mapAuthError(FirebaseAuthException e) {
  switch (e.code) {
    case 'user-not-found':
      return 'No user found for that email. Please register first.';
    case 'weak-password':
      return 'Password must be at least 6 characters.';
    case 'email-already-in-use':
      return 'This email is already registered.';
    case 'operation-not-allowed':
      return 'Email/Password sign-in is not enabled in Firebase Console.';
    default:
      return e.message ?? 'Authentication failed. Please try again.';
  }
}

String _fallbackInGameName(String email) {
  final parts = email.split('@');
  if (parts.isEmpty || parts.first.trim().isEmpty) {
    return 'NewPlayer';
  }
  return parts.first;
}
