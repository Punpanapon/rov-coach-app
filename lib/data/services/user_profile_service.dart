import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rov_coach/data/models/user_model.dart';

class UserProfileService {
  final FirebaseFirestore _firestore;

  UserProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  Stream<UserModel?> profileStream(String uid) {
    return _doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserModel.fromFirestore(snap);
    });
  }

  Future<UserModel?> fetchProfile(String uid) async {
    final snap = await _doc(uid).get();
    if (!snap.exists) return null;
    return UserModel.fromFirestore(snap);
  }

  Future<void> upsertProfile(UserModel user) async {
    await _doc(user.uid).set(user.toJson(), SetOptions(merge: true));
  }
}
