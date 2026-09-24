import { defineSecret } from "firebase-functions/params";

import type { RawPlace } from "./types";

/** ホットペッパーグルメAPI(飲食店検索、Issue #3・#28) */
export const hotpepperApiKey = defineSecret("HOTPEPPER_API_KEY");

interface RawHotPepperShop {
  id: string;
  name: string;
  address?: string;
  lat?: number;
  lng?: number;
  genre?: { name?: string };
  photo?: { pc?: { l?: string } };
}

export async function searchGourmet(
  lat: number,
  lng: number,
): Promise<RawPlace[]> {
  const url = new URL("https://webservice.recruit.co.jp/hotpepper/gourmet/v1/");
  url.searchParams.set("key", hotpepperApiKey.value());
  url.searchParams.set("lat", String(lat));
  url.searchParams.set("lng", String(lng));
  url.searchParams.set("range", "3");
  url.searchParams.set("count", "20");
  url.searchParams.set("format", "json");

  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`ホットペッパーグルメAPI呼び出しに失敗しました: ${res.status}`);
  }
  const body = (await res.json()) as {
    results?: { shop?: RawHotPepperShop[] };
  };
  return (body.results?.shop ?? []).map(toRawPlace);
}

function toRawPlace(shop: RawHotPepperShop): RawPlace {
  return {
    id: shop.id,
    name: shop.name,
    address: shop.address,
    imageUrl: shop.photo?.pc?.l,
    latitude: shop.lat,
    longitude: shop.lng,
    categoryName: shop.genre?.name,
  };
}
