import { defineSecret } from "firebase-functions/params";

import type { RawPlace } from "./types";

/** Foursquare Places API(観光・レジャー施設検索、Issue #3・#28) */
export const foursquareApiKey = defineSecret("FOURSQUARE_API_KEY");

const API_VERSION = "2025-06-17";

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
