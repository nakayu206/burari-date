import { defineSecret } from "firebase-functions/params";

import type { Preference } from "./preference";
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
  preference?: Preference,
): Promise<Omit<Candidate, "walkMinutes">[]> {
  if (rawPlaces.length === 0) return [];

  const targets = rawPlaces.slice(0, 20);
  const prompt = buildPrompt(stationName, category, targets, preference);

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
  return toCandidates(parsePicks(text), targets, category);
}

/** AIの選出結果(pick)を実データと突き合わせ、重複除去・件数上限を適用してCandidateに変換する */
export function toCandidates(
  picks: Pick[],
  targets: RawPlace[],
  category: CandidateCategory,
): Omit<Candidate, "walkMinutes">[] {
  const seen = new Set<number>();
  return picks
    .filter(({ index }) => {
      if (seen.has(index)) return false;
      seen.add(index);
      return true;
    })
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
    .filter((c): c is Omit<Candidate, "walkMinutes"> => c !== null)
    .slice(0, MAX_RESULTS);
}

/**
 * ユーザーの好みをプロンプトに添える文を作る。好みは絞り込みではなく
 * 「優先して選ぶ」ヒントとして扱い、該当が少なくても件数を減らさない。
 * 観光では飲食ジャンルは無関係なので、雰囲気と予算感だけを使う。
 */
export function buildPreferenceNote(
  category: CandidateCategory,
  preference?: Preference,
): string {
  if (!preference) return "";
  const items: string[] = [];
  if (category === "gourmet" && preference.genres.length > 0) {
    items.push(`好きなジャンル: ${preference.genres.join("、")}`);
  }
  if (preference.budget) items.push(`予算感: ${preference.budget}`);
  if (preference.mood) items.push(`好みの雰囲気: ${preference.mood}`);
  if (items.length === 0) return "";

  return `
ユーザーの好み(${items.join(" / ")})に合いそうな場所を優先して選んでください。
ただし好みに合う場所が少ない場合は、他の場所も選んで構いません。
好みに合うかどうかは、与えられたデータ(店名・カテゴリなど)から推測できる範囲で判断し、
価格や雰囲気など、データにない事実は断定して書かないでください。
`;
}

export function buildPrompt(
  stationName: string,
  category: CandidateCategory,
  targets: RawPlace[],
  preference?: Preference,
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
${sightseeingNote}${buildPreferenceNote(category, preference)}
店名・住所などの事実情報は絶対に創作せず、与えられたデータのみを使ってください。

データ:
${JSON.stringify(data)}

以下のJSON配列の形式のみで出力してください(説明文は不要):
[{"index": 0, "catchCopy": "...", "reason": "..."}]`;
}

/**
 * Claudeの応答を解析する。解析に失敗した場合は空配列を返さず例外を投げる
 * (呼び出し元のgetCandidatesがcatchしてreserveUsageで確保した無料枠を
 * 解放できるようにするため。空配列のまま成功扱いにすると、候補が1件も
 * 表示されないのに無料枠だけ消費してしまう)。
 */
export function parsePicks(text: string): Pick[] {
  const jsonText = extractJsonArray(text);
  if (jsonText === null) {
    throw new Error("Claude APIの応答からJSON配列を検出できませんでした");
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(jsonText);
  } catch {
    throw new Error("Claude APIの応答をJSONとして解析できませんでした");
  }
  if (!Array.isArray(parsed)) {
    throw new Error("Claude APIの応答が配列形式ではありません");
  }
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
function extractJsonArray(text: string): string | null {
  const start = text.indexOf("[");
  const end = text.lastIndexOf("]");
  if (start === -1 || end === -1 || end < start) return null;
  return text.slice(start, end + 1);
}
