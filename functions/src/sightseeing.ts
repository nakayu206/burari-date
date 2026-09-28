import { defineSecret } from "firebase-functions/params";

import type { RawPlace } from "./types";

/** Foursquare Places API(観光・レジャー施設検索、Issue #3・#28) */
export const foursquareApiKey = defineSecret("FOURSQUARE_API_KEY");

const API_VERSION = "2025-06-17";

/**
 * 観光・レジャー施設として検索したいFoursquareの大分類カテゴリID。
 * https://docs.foursquare.com/data-products/docs/categories
 * 絞り込まずに距離順で取得すると、駅前の近い20件が飲食店で埋まり、
 * 少し離れた公園・観光施設が候補にすら上がらないことがあるため、
 * 検索段階でカテゴリを絞る(AIに事後で除外させるだけでは不十分)。
 */
const SIGHTSEEING_CATEGORY_IDS = [
  "4d4b7105d754a06377d81259", // Outdoors & Recreation
  "4d4b7104d754a06370d81259", // Arts & Entertainment
];

interface RawFoursquarePlace {
  fsq_place_id: string;
  name: string;
  latitude?: number;
  longitude?: number;
  location?: { formatted_address?: string };
  categories?: { name?: string }[];
  photos?: { prefix: string; suffix: string }[];
}

export async function searchSightseeing(
  lat: number,
  lng: number,
): Promise<RawPlace[]> {
  const url = new URL("https://places-api.foursquare.com/places/search");
  url.searchParams.set("ll", `${lat},${lng}`);
  url.searchParams.set("radius", "1000");
  url.searchParams.set("limit", "20");
  url.searchParams.set("sort", "DISTANCE");
  url.searchParams.set("fsq_category_ids", SIGHTSEEING_CATEGORY_IDS.join(","));

  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${foursquareApiKey.value()}`,
      "X-Places-Api-Version": API_VERSION,
      Accept: "application/json",
    },
  });
  if (!res.ok) {
    throw new Error(`Foursquare Places API呼び出しに失敗しました: ${res.status}`);
  }
  const body = (await res.json()) as { results?: RawFoursquarePlace[] };
  return (body.results ?? []).map(toRawPlace);
}

function toRawPlace(place: RawFoursquarePlace): RawPlace {
  const photo = place.photos?.[0];
  return {
    id: place.fsq_place_id,
    name: place.name,
    address: place.location?.formatted_address,
    imageUrl: photo ? `${photo.prefix}300x300${photo.suffix}` : undefined,
    latitude: place.latitude,
    longitude: place.longitude,
    categoryName: place.categories?.[0]?.name,
  };
}
