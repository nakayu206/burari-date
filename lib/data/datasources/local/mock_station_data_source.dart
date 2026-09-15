import '../../../domain/entities/railway_line.dart';
import '../../../domain/entities/station.dart';

/// 実際の駅・路線APIが未選定のため(仕様書 7.1)、初期構築ではモックデータで
/// 山手線の一部区間を再現するローカルデータソース。
/// 将来的に駅すぱあと/HeartRails Express/ODPT等のリモートAPIに置き換える。
class MockStationDataSource {
  const MockStationDataSource();

  static final yamanoteLine = RailwayLine(
    id: 'line_yamanote',
    name: 'JR山手線',
    stations: const [
      Station(
        id: 'st_tokyo',
        name: '東京駅',
        lineId: 'line_yamanote',
        orderIndex: 0,
      ),
      Station(
        id: 'st_kanda',
        name: '神田駅',
        lineId: 'line_yamanote',
        orderIndex: 1,
      ),
      Station(
        id: 'st_akihabara',
        name: '秋葉原駅',
        lineId: 'line_yamanote',
        orderIndex: 2,
      ),
      Station(
        id: 'st_ueno',
        name: '上野駅',
        lineId: 'line_yamanote',
        orderIndex: 3,
      ),
      Station(
        id: 'st_ikebukuro',
        name: '池袋駅',
        lineId: 'line_yamanote',
        orderIndex: 4,
      ),
      Station(
        id: 'st_shinjuku',
        name: '新宿駅',
        lineId: 'line_yamanote',
        orderIndex: 5,
      ),
      Station(
        id: 'st_shibuya',
        name: '渋谷駅',
        lineId: 'line_yamanote',
        orderIndex: 6,
      ),
      Station(
        id: 'st_ebisu',
        name: '恵比寿駅',
        lineId: 'line_yamanote',
        orderIndex: 7,
      ),
      Station(
        id: 'st_shinagawa',
        name: '品川駅',
        lineId: 'line_yamanote',
        orderIndex: 8,
      ),
    ],
  );

  List<RailwayLine> get lines => [yamanoteLine];
}
