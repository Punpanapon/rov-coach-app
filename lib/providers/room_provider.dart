import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the currently active room ID.
/// Set by the router when a `:roomId` path segment is resolved.
/// Firestore-backed providers read this to scope their queries.
final roomIdProvider =
    NotifierProvider<RoomIdNotifier, String?>(RoomIdNotifier.new);

class RoomIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String id) => state = id;
}
