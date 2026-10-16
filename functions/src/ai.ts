import { defineSecret } from "firebase-functions/params";

import type { Preference } from "./preference";
import type { Candidate, CandidateCategory, RawPlace } from "./types";

/** Claude API(候補の要約・キャッチコピー生成、Issue #4・#28) */
export const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");

const MODEL = "claude-haiku-4-5-20251001";
const MAX_RESULTS = 5;

/** Claudeの応答を待つ上限。超えたら中止して失敗にする(利用枠は、呼び出し元が戻す) */
const AI_TIMEOUT_MS = 40_000;
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
  const text = await callClaude(prompt);
  return requireCandidates(toCandidates(parsePicks(text), targets, category));
}

/** 紹介文(キャッチコピー・おすすめ理由)。 */
export interface Description {
  id: string;
  catchCopy: string;
  reason: string;
}

/**
 * すでに選ばれた場所(最大5件)に、紹介文だけを付ける。場所は選び直さない。
 * 一覧を先に出したあとの後追いで呼ぶため、失敗しても利用者の画面は壊れない。
 */
export async function describePlaces(
  stationName: string,
  category: CandidateCategory,
  places: RawPlace[],
  preference?: Preference,
): Promise<Description[]> {
  if (places.length === 0) return [];
  const text = await callClaude(
    buildDescribePrompt(stationName, category, places, preference),
  );
  const seen = new Set<number>();
  const descriptions = parsePicks(text)
    .filter(({ index, catchCopy, reason }) => {
      if (seen.has(index) || !places[index]) return false;
      if (catchCopy.trim() === "" || reason.trim() === "") return false;
      seen.add(index);
      return true;
    })
    .map(({ index, catchCopy, reason }) => ({
      id: places[index].id,
      catchCopy,
      reason,
    }));
  // 一部の場所に紹介文がないまま成功にすると、アプリが取り直せないため、失敗として投げる。
  if (descriptions.length < places.length) {
    throw new Error("Claude APIの応答に、全件の紹介文が含まれていませんでした");
  }
  return descriptions;
}

async function callClaude(prompt: string): Promise<string> {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    signal: AbortSignal.timeout(AI_TIMEOUT_MS),
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
  return extractText(body);
}

/**
 * Claudeの応答からテキストを取り出す。テキストがなければ例外を投げる
 * (空の応答を「候補なし」の正常結果にすると、無料枠だけ消費してしまうため)。
 */
export function extractText(body: {
  content?: { type: string; text?: string }[];
}): string {
  const text = body.content?.find((c) => c.type === "text")?.text;
  if (typeof text !== "string" || text.trim() === "") {
    throw new Error("Claude APIの応答にテキストがありませんでした");
  }
  return text;
}

/**
 * 実データがあるのに、使える候補が1件も残らなかった場合は、AIの不正な応答
 * (存在しない番号だけを返した等)として例外を投げる。周辺に施設が実際に
 * ない場合(実データが0件)は、generateCandidatesの冒頭で空配列を返しており、
 * ここには来ない。
 */
export function requireCandidates<T>(candidates: T[]): T[] {
  if (candidates.length === 0) {
    throw new Error("Claude APIの応答から、使える候補を得られませんでした");
  }
  return candidates;
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
        categoryName: place.categoryName,
        budget: place.budget,
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
ユーザーの好み(${items.join(" / ")})に合いそうな場所を優先して選び、結果の上位(先頭)に並べてください。
ただし好みに合う場所が少ない場合は、他の場所も選んで構いません。
好みに合うかどうかは、与えられたデータ(店名・カテゴリなど)から推測できる範囲で判断し、
価格や雰囲気など、データにない事実は断定して書かないでください。${
    category === "gourmet" && preference.budget
      ? "\n予算感は、データのbudget(平均ディナー予算の目安)から判断してください。"
      : ""
  }
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
    budget: place.budget ?? null,
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

export function buildDescribePrompt(
  stationName: string,
  category: CandidateCategory,
  places: RawPlace[],
  preference?: Preference,
): string {
  const categoryLabel = category === "gourmet" ? "飲食店" : "観光・レジャー施設";
  const mood = preference?.mood
    ? `
ユーザーの好みの雰囲気(${preference.mood})を意識した文章にしてください。ただし、データにない事実は断定しないでください。`
    : "";
  const data = places.map((place, index) => ({
    index,
    name: place.name,
    address: place.address ?? null,
    category: place.categoryName ?? null,
    budget: place.budget ?? null,
  }));
  return `あなたは日本のデートスポット案内アシスタントです。
${stationName}周辺の${categoryLabel}の実データが以下のJSONで与えられます。
すべての場所について、短いキャッチコピー(15文字程度)とおすすめ理由(40文字程度)を日本語で書いてください。場所を選び直したり、減らしたりしないでください。${mood}
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
