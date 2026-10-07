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
  return parseGourmetResponse(await res.json());
}

/**
 * ホットペッパーグルメAPIの応答から、店舗を取り出す。このAPIは、認証エラーや障害の
 * ときも、HTTP 200を返し、本文の`results.error`にエラーを入れる。これを「店舗が0件の
 * 成功」と見なすと、候補が出ないのに利用枠を消費してしまうため、失敗として投げる
 * (呼び出し元のgetCandidatesが、確保した枠を戻せる)。
 */
export function parseGourmetResponse(body: unknown): RawPlace[] {
  const results = (body as { results?: unknown } | null | undefined)?.results as
    | { shop?: unknown; error?: unknown }
    | undefined;
  if (results === undefined || results === null || typeof results !== "object") {
    throw new Error("ホットペッパーグルメAPIの応答が、想定した形式ではありません");
  }
  if (results.error !== undefined) {
    const first = Array.isArray(results.error) ? results.error[0] : results.error;
    const { code, message } = (first ?? {}) as { code?: unknown; message?: unknown };
    throw new Error(
      `ホットペッパーグルメAPIがエラーを返しました: ${String(code ?? "")} ${String(message ?? "")}`.trim(),
    );
  }
  // 店舗が0件のときは、shopが空の配列(または、ない)。これは、失敗ではない。
  const shops = Array.isArray(results.shop) ? (results.shop as RawHotPepperShop[]) : [];
  return shops.map(toRawPlace);
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
