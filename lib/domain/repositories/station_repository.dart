import '../entities/railway_line.dart';
import '../entities/station.dart';

/// 駅・路線データへのアクセスを抽象化する(仕様書 6.1 Line / Station)。
///
/// 実装はHeartRails Express(無料・APIキー不要の駅データWebサービス)への
/// リモートアクセスに置き換え済み(Issue #2)。ネットワークI/Oを伴うため、
/// 初期構築時のモック実装(同期メソッド)から非同期メソッドへ変更している。
abstract interface class StationRepository {
  /// 駅名の部分一致でサジェスト候補を検索する(S-02b)。
  Future<List<Station>> searchStations(String query);

  /// 指定した駅が所属する路線を取得する。
  Future<RailwayLine?> findLineForStation(Station station);
}
