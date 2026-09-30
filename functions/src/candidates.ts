import { HttpsError, onCall } from "firebase-functions/v2/https";

import { anthropicApiKey, generateCandidates } from "./ai";
import { estimateWalkMinutes } from "./distance";
import { isValidGachaId, releaseUsage, reserveUsage } from "./fairUse";
import { hotpepperApiKey, searchGourmet } from "./gourmet";
import { parsePreference, prioritizeByGenres } from "./preference";
import { foursquareApiKey, searchSightseeing } from "./sightseeing";
import type { Candidate, CandidateCategory } from "./types";

interface GetCandidatesRequest {
  latitude: number;
  longitude: number;
  stationName: string;
  category: CandidateCategory;
  /**
   * 1回のガチャを識別するID。同じガチャのグルメ・観光を、無料枠で1回と数える
   * ために使う(任意。ない古いバージョンのアプリは、呼び出しごとに数える)。
   */
  gachaId?: unknown;
  /** AI提案の好み設定(任意)。未設定なら従来どおりの提案にする。 */
  preference?: unknown;
}

/**
 * 到着駅周辺のグルメ/観光候補を返す(Issue #3・#4)。
 * 外部API(ホットペッパー/Foursquare)の実データのみをClaudeに渡し、
 * 店名・住所は創作させず、キャッチコピー・おすすめ理由だけを生成させる。
 */
export const getCandidates = onCall<GetCandidatesRequest>(
  {
    secrets: [hotpepperApiKey, foursquareApiKey, anthropicApiKey],
    region: "us-central1",
    // 実行中にタイムアウトで強制終了されるとreserveUsageの解放(catch節)が
    // 走らず無料枠を失ってしまうため、余裕を持たせて発生確率を下げる。
    timeoutSeconds: 120,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "サインインが必要です");
    }

    const { latitude, longitude, stationName, category } = request.data;
    if (
      typeof latitude !== "number" ||
      typeof longitude !== "number" ||
      typeof stationName !== "string" ||
      (category !== "gourmet" && category !== "sightseeing")
    ) {
      throw new HttpsError("invalid-argument", "リクエスト内容が不正です");
    }

    const gachaId = request.data.gachaId;
    if (gachaId !== undefined && !isValidGachaId(gachaId)) {
      throw new HttpsError("invalid-argument", "リクエスト内容が不正です");
    }

    const uid = request.auth.uid;
    const reservation = await reserveUsage(uid, category, gachaId);

    try {
      const preference = parsePreference(request.data.preference);
      // グルメは、好みのジャンルの店を先頭に並べてからAIに渡す(AIが受け取る
      // のは先頭の20件のため、近い順のままだと好みの店が漏れる)。
      const rawPlaces =
        category === "gourmet"
          ? prioritizeByGenres(
              await searchGourmet(latitude, longitude),
              preference?.genres ?? [],
            )
          : await searchSightseeing(latitude, longitude);

      const picks = await generateCandidates(
        stationName,
        category,
        rawPlaces,
        preference,
      );

      const candidates: Candidate[] = picks.map((pick) => ({
        ...pick,
        walkMinutes:
          pick.latitude != null && pick.longitude != null
            ? estimateWalkMinutes(
                latitude,
                longitude,
                pick.latitude,
                pick.longitude,
              )
            : 5,
      }));

      return { candidates };
    } catch (e) {
      await releaseUsage(uid, reservation, category, gachaId);
      throw e;
    }
  },
);
