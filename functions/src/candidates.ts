import { getAuth } from "firebase-admin/auth";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { anthropicApiKey, generateCandidates } from "./ai";
import { estimateWalkMinutes } from "./distance";
import {
  isValidDeviceId,
  isValidGachaId,
  markCategorySucceeded,
  releaseUsage,
  reserveUsage,
} from "./fairUse";
import { hotpepperApiKey, searchGourmet } from "./gourmet";
import { parsePreference, prioritizeByGenres } from "./preference";
import { foursquareApiKey, searchSightseeing } from "./sightseeing";
import type { Candidate, CandidateCategory } from "./types";

/**
 * 削除済みのアカウントからの呼び出しを、断る。アカウントを削除したあとも、ログインの情報
 * (トークン)は、しばらく有効なため、そのまま通すと、削除したユーザーの記録を、作り直して
 * しまう。確認できなかったとき(通信の失敗など)は、通す(正規の利用者を、止めないため)。
 */
async function assertAccountExists(uid: string): Promise<void> {
  try {
    await getAuth().getUser(uid);
  } catch (e) {
    if ((e as { code?: string }).code === "auth/user-not-found") {
      throw new HttpsError("unauthenticated", "サインインが必要です");
    }
    console.warn("ユーザーを確認できませんでした", e);
  }
}

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
  /**
   * 端末ごとの識別子(任意)。無料枠を、ログアウトで、数え直されない(再インストールは、バックアップで復元されたときだけ防げる)
   * ようにするために、端末ごとにも数える。ない古いバージョンのアプリは、ユーザーだけで数える。
   */
  deviceId?: unknown;
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

    const deviceId = request.data.deviceId;
    if (deviceId !== undefined && !isValidDeviceId(deviceId)) {
      throw new HttpsError("invalid-argument", "リクエスト内容が不正です");
    }

    const uid = request.auth.uid;
    await assertAccountExists(uid);
    const reservation = await reserveUsage(uid, category, gachaId, undefined, deviceId);

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

      // 周辺に施設がなく、候補が0件のときは、利用枠を消費しない(利用者に、何も提供して
      // いないため)。0件の結果は、成功として返す。
      if (candidates.length === 0) {
        await releaseUsage(uid, reservation, category, gachaId, undefined, deviceId);
      } else {
        // 取得に成功したことを記録する(あとの取り直しが失敗しても、記録を消さないため)。
        await markCategorySucceeded(uid, gachaId, category, reservation.requestId);
      }

      return { candidates };
    } catch (e) {
      await releaseUsage(uid, reservation, category, gachaId, undefined, deviceId);
      throw e;
    }
  },
);
