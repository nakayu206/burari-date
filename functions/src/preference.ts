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
 * 好みのジャンルに合う飲食店を先頭に並べ替える(元の順序は保つ)。
 *
 * 好みは絞り込みではなく優先なので、合わない店も後ろに残す。ジャンルの
 * 判定は、店のジャンル名に好みの語が含まれるかどうかで行う(例: 好み
 * 「カフェ」「スイーツ」は、どちらもジャンル名「カフェ・スイーツ」に一致する)。
 * ジャンル名が取れない店、好みのジャンルがない場合は、順序を変えない。
 */
export function prioritizeByGenres<T extends { categoryName?: string }>(
  places: T[],
  genres: string[],
): T[] {
  if (genres.length === 0) return places;
  const matches = (place: T) =>
    place.categoryName !== undefined &&
    genres.some((genre) => place.categoryName!.includes(genre));
  return [...places.filter(matches), ...places.filter((p) => !matches(p))];
}

/** 予算の目安(平均ディナー予算の円)が、好みの予算感に合うかの境目 */
const BUDGET_LOW_MAX = 2000;
const BUDGET_HIGH_MIN = 4000;

/**
 * 予算の文言(「900円」「1001~1500円」など)から、金額(最初の数字)を読む。
 * 読めなければundefined。
 */
export function parseBudgetYen(text: string | undefined): number | undefined {
  const m = text?.replace(/,/g, "").match(/\d+/);
  return m ? Number(m[0]) : undefined;
}

/** 0=好みの予算感に合う(または、予算の好みなし)、1=予算が不明、2=合わない */
function budgetRank(budget: string | undefined, preferred: string | undefined): number {
  // 「普通」は、極端に安い・高いを避ける指定ではないため、順序を変えない。
  if (!preferred || preferred === "普通") return 0;
  const yen = parseBudgetYen(budget);
  if (yen === undefined) return 1;
  if (preferred === "安め") return yen <= BUDGET_LOW_MAX ? 0 : 2;
  return yen >= BUDGET_HIGH_MIN ? 0 : 2; // 高め
}

/**
 * 好み(ジャンル・予算感)に合う飲食店を先頭に並べ替える。ジャンルを優先し、同じ
 * ジャンルの中で、予算感に合う店を前にする。元の順序(距離順)は、同順位の中で保つ。
 * AIは紹介文だけを書くため、AIに渡す前に、ここで一覧に出す候補を決める。
 */
export function prioritizeByPreference<
  T extends { categoryName?: string; budget?: string },
>(places: T[], preference: Preference | undefined): T[] {
  if (!preference) return places;
  const genres = preference.genres;
  const genreRank = (place: T) =>
    genres.length === 0 ||
    (place.categoryName !== undefined &&
      genres.some((genre) => place.categoryName!.includes(genre)))
      ? 0
      : 1;
  return places
    .map((place, index) => ({
      place,
      index,
      genre: genreRank(place),
      budget: budgetRank(place.budget, preference.budget),
    }))
    .sort((a, b) => a.genre - b.genre || a.budget - b.budget || a.index - b.index)
    .map(({ place }) => place);
}

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
