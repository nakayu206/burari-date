import { HttpsError, onCall } from "firebase-functions/v2/https";

import { anthropicApiKey, describePlaces } from "./ai";
import { isValidGachaId, takeDescribeTry } from "./fairUse";
import { parsePreference } from "./preference";
import type { CandidateCategory } from "./types";

interface DescribeRequest {
  category: CandidateCategory;
  gachaId: unknown;
  preference?: unknown;
}

/**
 * `getCandidates`(phase: "places")で返した場所に、AIの紹介文(キャッチコピー・
 * おすすめ理由)を後から付ける。利用枠は、場所を返した取得で数え済みのため、数えない。
 *
 * 紹介文の対象は、アプリから受け取らず、`getCandidates`がサーバーに残した場所だけを使う
 * (駅名も同じ。任意の文章の生成や、AIへの指示の差し込みに使われないようにするため)。生成の回数は、1回の取得につき
 * 上限がある。
 */
export const describeCandidates = onCall<DescribeRequest>(
  {
    secrets: [anthropicApiKey],
    region: "us-central1",
    timeoutSeconds: 60,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "サインインが必要です");
    }
    const { category, gachaId } = request.data;
    if (
      (category !== "gourmet" && category !== "sightseeing") ||
      !isValidGachaId(gachaId)
    ) {
      throw new HttpsError("invalid-argument", "リクエスト内容が不正です");
    }

    // 駅名も、対象の場所と同じく、サーバーが残した値を使う(アプリから受け取った
    // 文字列を、AIへの指示に埋め込まないため)。
    const { places, stationName } = await takeDescribeTry(
      request.auth.uid,
      gachaId,
      category,
    );
    const descriptions = await describePlaces(
      stationName,
      category,
      places,
      parsePreference(request.data.preference),
    );
    return { descriptions };
  },
);
