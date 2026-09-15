import '../entities/railway_line.dart';
import '../entities/station.dart';

/// 駅・路線データへのアクセスを抽象化する(仕様書 6.1 Line / Station)。
///
/// 実装は初期構築ではモックデータ(data/datasources/local)を返すが、将来的に
/// 駅すぱあとWebサービス/HeartRails Express/ODPT等の外部APIへ差し替える想定
/// (仕様書 7.1 外部連携・技術要件)。
abstract interface class StationRepository {
  /// 駅名の部分一致でサジェスト候補を検索する(S-02b)。
  List<Station> searchStations(String query);

  /// 指定した駅が所属する路線を取得する。
  RailwayLine? findLineForStation(Station station);
}
