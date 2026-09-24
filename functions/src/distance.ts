const EARTH_RADIUS_METERS = 6371000;
const WALK_METERS_PER_MINUTE = 80;

/** 2地点間の直線距離から徒歩分数を概算する(仕様上の目安値) */
export function estimateWalkMinutes(
  fromLat: number,
  fromLng: number,
  toLat: number,
  toLng: number,
): number {
  const meters = haversineMeters(fromLat, fromLng, toLat, toLng);
  return Math.max(1, Math.round(meters / WALK_METERS_PER_MINUTE));
}

function haversineMeters(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return EARTH_RADIUS_METERS * c;
}
