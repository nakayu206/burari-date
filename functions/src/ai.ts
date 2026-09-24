import { defineSecret } from "firebase-functions/params";

import type { Candidate, CandidateCategory, RawPlace } from "./types";

/** Claude API(候補の要約・キャッチコピー生成、Issue #4・#28) */
export const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");

const MODEL = "claude-haiku-4-5-20251001";
const MAX_RESULTS = 5;

interface Pick {
  index: number;
  catchCopy: string;
  reason: string;
}

export async function generateCandidates(
  stationName: string,
  category: CandidateCategory,
  rawPlaces: RawPlace[],
): Promise<Omit<Candidate, "walkMinutes">[]> {
  if (rawPlaces.length === 0) return [];

  const targets = rawPlaces.slice(0, 20);
  const prompt = buildPrompt(stationName, category, targets);

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": anthropicApiKey.value(),
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 1024,
      messages: [{ role: "user", content: prompt }],
    }),
  });
  if (!res.ok) {
    throw new Error(`Claude API呼び出しに失敗しました: ${res.status}`);
  }
  const body = (await res.json()) as {
    content?: { type: string; text?: string }[];
  };
  const text = body.content?.find((c) => c.type === "text")?.text ?? "[]";
  const picks = parsePicks(text);

  return picks
    .map(({ index, catchCopy, reason }) => {
      const place = targets[index];
      if (!place) return null;
      const candidate: Omit<Candidate, "walkMinutes"> = {
        id: place.id,
        category,
        name: place.name,
        catchCopy,
        reason,
        address: place.address,
        imageUrl: place.imageUrl,
        latitude: place.latitude,
        longitude: place.longitude,
      };
      return candidate;
    })
    .filter((c): c is Omit<Candidate, "walkMinutes"> => c !== null);
}

function buildPrompt(
  stationName: string,
  category: CandidateCategory,
  targets: RawPlace[],
): string {
  const categoryLabel = category === "gourmet" ? "飲食店" : "観光・レジャー施設";
  const sightseeingNote =
    category === "sightseeing"
      ? "飲食店・カフェは除外し、公園・観光施設・レジャー施設のみを選んでください。"
      : "";
  const data = targets.map((place, index) => ({
    index,
    name: place.name,
    address: place.address ?? null,
    category: place.categoryName ?? null,
  }));

  return `あなたは日本のデートスポット案内アシスタントです。
${stationName}周辺の${categoryLabel}の実データが以下のJSONで与えられます。
この中から、デートに向いていそうな場所を最大${MAX_RESULTS}件選び、
それぞれに短いキャッチコピー(15文字程度)とおすすめ理由(40文字程度)を日本語で書いてください。
${sightseeingNote}
店名・住所などの事実情報は絶対に創作せず、与えられたデータのみを使ってください。

データ:
${JSON.stringify(data)}

以下のJSON配列の形式のみで出力してください(説明文は不要):
[{"index": 0, "catchCopy": "...", "reason": "..."}]`;
}

export function parsePicks(text: string): Pick[] {
  let parsed: unknown;
  try {
    parsed = JSON.parse(extractJsonArray(text));
  } catch {
    return [];
  }
  if (!Array.isArray(parsed)) return [];
  return parsed.filter((item): item is Pick => {
    const p = item as Partial<Pick>;
    return (
      typeof p.index === "number" &&
      typeof p.catchCopy === "string" &&
      typeof p.reason === "string"
    );
  });
}

/** モデルが前後に説明文を付けた場合に備え、最初の配列部分だけを取り出す */
function extractJsonArray(text: string): string {
  const start = text.indexOf("[");
  const end = text.lastIndexOf("]");
  if (start === -1 || end === -1 || end < start) return "[]";
  return text.slice(start, end + 1);
}
