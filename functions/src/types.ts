export type CandidateCategory = "gourmet" | "sightseeing";

/** 外部API(ホットペッパー/Foursquare)から取得した実在データ */
export interface RawPlace {
  id: string;
  name: string;
  address?: string;
  imageUrl?: string;
  latitude?: number;
  longitude?: number;
  categoryName?: string;
  /** 予算の目安(ホットペッパーの平均ディナー予算。飲食店のみ) */
  budget?: string;
}

/** クライアントの Candidate エンティティと対応するレスポンス形式 */
export interface Candidate {
  id: string;
  category: CandidateCategory;
  name: string;
  catchCopy: string;
  reason: string;
  walkMinutes: number;
  address?: string;
  imageUrl?: string;
  latitude?: number;
  longitude?: number;
  /** ジャンル名(ホットペッパーのジャンル、Foursquareのカテゴリ)。アイコンの出し分けに使う */
  categoryName?: string;
  /** 予算の目安(飲食店のみ) */
  budget?: string;
}
