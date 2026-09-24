import { HttpsError, onCall } from "firebase-functions/v2/https";

import { anthropicApiKey, generateCandidates } from "./ai";
import { estimateWalkMinutes } from "./distance";
import { releaseUsage, reserveUsage } from "./fairUse";
import { hotpepperApiKey, searchGourmet } from "./gourmet";
import { foursquareApiKey, searchSightseeing } from "./sightseeing";
import type { Candidate, CandidateCategory } from "./types";

interface GetCandidatesRequest {
  latitude: number;
  longitude: number;
  stationName: string;
  category: CandidateCategory;
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

    await reserveUsage(request.auth.uid);

    try {
      const rawPlaces =
        category === "gourmet"
          ? await searchGourmet(latitude, longitude)
          : await searchSightseeing(latitude, longitude);

      const picks = await generateCandidates(stationName, category, rawPlaces);

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
      await releaseUsage(request.auth.uid);
      throw e;
    }
  },
);
