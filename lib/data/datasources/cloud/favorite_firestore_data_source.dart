import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../domain/entities/favorite.dart';

/// Firestore(users/{uid}/favorites)にお気に入りを保存するデータソース
/// (Issue #9)。匿名認証のUIDに紐付けて保存することで、後からアカウント
/// 連携した際にもデータを引き継げるようにする。
class FavoriteFirestoreDataSource {
  FavoriteFirestoreDataSource({FirebaseFirestore? firestore, String? uid})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _uidOverride = uid;

  final FirebaseFirestore _firestore;

  /// テストで[FirebaseAuth.instance]に触れずに済むための注入ポイント。
  final String? _uidOverride;

  String get _uid {
    final uid = _uidOverride ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('サインインが完了していません');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_uid).collection('favorites');

  Future<List<Favorite>> load() async {
    final snapshot = await _collection
        .orderBy('savedAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => Favorite.fromJson(doc.data())).toList();
  }

  Future<void> upsert(Favorite favorite) {
    return _collection.doc(favorite.candidateId).set(favorite.toJson());
  }

  Future<void> remove(String candidateId) {
    return _collection.doc(candidateId).delete();
  }

  Future<bool> exists(String candidateId) async {
    final doc = await _collection.doc(candidateId).get();
    return doc.exists;
  }
}
