import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'anonymous_auth.dart';
import '../../../domain/entities/gacha_history_entry.dart';

/// Firestore(users/{uid}/history)にガチャ履歴を保存するデータソース
/// (Issue #9)。匿名認証のUIDに紐付けて保存することで、後からアカウント
/// 連携した際にもデータを引き継げるようにする。
class GachaHistoryFirestoreDataSource {
  GachaHistoryFirestoreDataSource({FirebaseFirestore? firestore, String? uid})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _uidOverride = uid;

  /// 際限なく増え続けないよう、直近この件数だけ保持する。
  static const maxEntries = 50;

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
          .collection('history');

  Future<List<GachaHistoryEntry>> load() async {
    final snapshot = await (await _collection())
        .orderBy('executedAt', descending: true)
        .limit(maxEntries)
        .get();
    return snapshot.docs
        .map((doc) => GachaHistoryEntry.fromJson(doc.data()))
        .toList();
  }

  Future<void> add(GachaHistoryEntry entry) async {
    await (await _collection()).add(entry.toJson());
    await _trimOldEntries();
  }

  Future<void> _trimOldEntries() async {
    final snapshot = await (await _collection())
        .orderBy('executedAt', descending: true)
        .get();
    for (final doc in snapshot.docs.skip(maxEntries)) {
      await doc.reference.delete();
    }
  }
}
