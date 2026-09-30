import { defineSecret } from "firebase-functions/params";

import type { RawPlace } from "./types";

/** ホットペッパーグルメAPI(飲食店検索、Issue #3・#28) */
export const hotpepperApiKey = defineSecret("HOTPEPPER_API_KEY");

/** 1回の検索で取得する飲食店の件数(ホットペッパーグルメAPIの上限) */
const GOURMET_FETCH_COUNT = 100;

interface RawHotPepperShop {
  id: string;
  name: string;
  address?: string;
  lat?: number;
  lng?: number;
  genre?: { name?: string };
  budget?: { name?: string; average?: string };
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
  // 位置検索では距離順に固定される。好みのジャンルを優先できるよう、AIに渡す
  // 件数(ai.tsで絞る)より多めに取得する(APIの上限は100件)。
  url.searchParams.set("count", String(GOURMET_FETCH_COUNT));
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
    budget: toBudgetText(shop.budget),
  };
}

/**
 * 予算の目安の文言を作る。平均ディナー予算(average。「900円」など)を優先し、
 * ない店は予算の帯(name。「1001~1500円」など)を使う。どちらもなければundefined。
 */
export function toBudgetText(
  budget: { name?: string; average?: string } | undefined,
): string | undefined {
  const average = budget?.average?.trim();
  if (average) return average;
  const name = budget?.name?.trim();
  return name ? name : undefined;
}
