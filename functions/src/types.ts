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
}
