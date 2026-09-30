/**
 * ユーザーのAI提案の好み設定(アプリの「AI提案の好み設定」画面と同じ選択肢)。
 * プロンプトに埋め込むため、ユーザー入力をそのまま渡さず、下記の許可された値
 * だけを通す(プロンプトインジェクション対策)。
 */
export interface Preference {
  genres: string[];
  budget?: string;
  mood?: string;
}

const ALLOWED_GENRES = ["和食", "洋食", "中華", "カフェ", "スイーツ"];
const ALLOWED_BUDGETS = ["安め", "普通", "高め"];
const ALLOWED_MOODS = ["静か", "賑やか", "おしゃれ", "レトロ"];

/**
 * リクエストのpreferenceを検証して取り出す。未指定・形式不正・有効な値が
 * 1つもない場合はundefinedを返し、従来どおりの(好みを使わない)提案にする。
 */
export function parsePreference(raw: unknown): Preference | undefined {
  if (typeof raw !== "object" || raw === null) return undefined;
  const { genres, budget, mood } = raw as Record<string, unknown>;

  const validGenres = Array.isArray(genres)
    ? ALLOWED_GENRES.filter((g) => genres.includes(g))
    : [];
  const validBudget = ALLOWED_BUDGETS.find((b) => b === budget);
  const validMood = ALLOWED_MOODS.find((m) => m === mood);

  if (validGenres.length === 0 && !validBudget && !validMood) {
    return undefined;
  }
  return { genres: validGenres, budget: validBudget, mood: validMood };
}
