import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'anonymous_auth.dart';
import '../../../domain/entities/candidate.dart';
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

  /// ログインしていなければ、ここでログインをやり直す(Issue #105)。
  Future<String> _resolveUid() async =>
      _uidOverride ?? await AnonymousAuth.instance.ensureUid();

  Future<CollectionReference<Map<String, dynamic>>> _collection() async =>
      _firestore
          .collection('users')
          .doc(await _resolveUid())
          .collection('favorites');

  Future<List<Favorite>> load() async {
    final snapshot = await (await _collection())
        .orderBy('savedAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => Favorite.fromJson(doc.data())).toList();
  }

  Future<void> upsert(Favorite favorite) async {
    final collection = await _collection();
    return collection.doc(favorite.candidateId).set(favorite.toJson());
  }

  /// 今も保存されていて、まだ仮の説明のお気に入りだけを、AIの紹介文に更新する。
  /// 更新できたかを返す。解除済みのものは、作り直さない(トランザクションで、
  /// 更新の直前に存在を確かめる)。
  Future<bool> refreshDescription(
    String candidateId,
    CandidateDescription description,
  ) async {
    final doc = (await _collection()).doc(candidateId);
    return _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(doc);
      if (!snapshot.exists) return false;
      // 保存済みの古いデータには、項目がない(AIの紹介文として扱う)。
      if (snapshot.data()?['isAiGenerated'] as bool? ?? true) return false;
      tx.update(doc, {
        'catchCopy': description.catchCopy,
        'reason': description.reason,
        'isAiGenerated': true,
      });
      return true;
    });
  }

  Future<void> remove(String candidateId) async {
    final collection = await _collection();
    return collection.doc(candidateId).delete();
  }

  Future<bool> exists(String candidateId) async {
    final doc = await (await _collection()).doc(candidateId).get();
    return doc.exists;
  }
}
