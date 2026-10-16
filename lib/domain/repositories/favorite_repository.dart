import '../entities/candidate.dart';
import '../entities/favorite.dart';

/// お気に入り候補の永続化を抽象化する(仕様書 6.1 Favorite)。
abstract interface class FavoriteRepository {
  /// 保存済みのお気に入りを新しい順に取得する。
  Future<List<Favorite>> loadFavorites();

  /// 候補をお気に入りに追加する。既に同じcandidateIdが保存済みの場合は上書きする。
  Future<void> addFavorite(Favorite favorite);

  /// 今も保存されていて、まだ仮の説明のお気に入りだけを、AIの紹介文に更新する。
  /// 更新したかを返す。解除済みのものは、作り直さない。
  Future<bool> refreshDescription(
    String candidateId,
    CandidateDescription description,
  );

  /// お気に入りを解除する。
  Future<void> removeFavorite(String candidateId);

  /// 指定した候補が保存済みかどうか。
  Future<bool> isFavorite(String candidateId);
}
