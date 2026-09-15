/// 駅マスタ(仕様書 6.2 Station)
class Station {
  const Station({
    required this.id,
    required this.name,
    required this.lineId,
    required this.orderIndex,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String lineId;

  /// 路線内の駅順序(隣接駅数の計算に利用)
  final int orderIndex;
  final double? latitude;
  final double? longitude;
}
