import { getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

/**
 * 無料で使える累計回数(コスト対策バックストップ、仕様書10章)。
 * 1回は「1回のガチャ」で、そのガチャのグルメ・観光の両方の取得を含む。
 */
export const LIFETIME_FREE_LIMIT = 10;

/**
 * 上限エラーの種類。
 * - `free_tier`: 無料枠(累計10回)を使い切った
 * - `monthly`: 課金後の月のフェアユース上限(月30回目安)を超えた。まだ実装して
 *   いない(Issue #10)が、アプリが分岐できるよう、値だけ先に決めている。
 */
export type LimitType = "free_tier" | "monthly";

/** ガチャごとの取得記録を残す日数(TTLポリシーを設定したときに古い記録を消す目安) */
const GACHA_USAGE_TTL_DAYS = 30;

/** gachaIdとして受け付ける形式(FirestoreのドキュメントIDに使うため制限する) */
const GACHA_ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;

export function isValidGachaId(value: unknown): value is string {
  return typeof value === "string" && GACHA_ID_PATTERN.test(value);
}

function lifetimeUsedOf(data: FirebaseFirestore.DocumentData | undefined): number {
  return data?.lifetimeFreeUsed ?? 0;
}

/** 枠を確保した結果。失敗時に、何を戻すかを判断するために使う。 */
export interface Reservation {
  /** 今回の呼び出しで無料枠を1回消費したか(すでに数えたガチャの別カテゴリならfalse) */
  charged: boolean;
}

/**
 * 無料枠の消費を判断する(Firestoreを使わない純粋な関数)。
 *
 * - `recordedCategories`は、同じガチャですでに取得したカテゴリ。ガチャの記録が
 *   ない(または`gachaId`なし)ときはundefined。
 * - そのガチャで初めての取得は1回と数える。すでに取得したカテゴリと違う
 *   カテゴリなら、数えない(1回のガチャのグルメ・観光は1回)。
 * - 同じカテゴリの取り直しは、また1回と数える(同じgachaIdの使い回しによる
 *   無制限の利用を防ぐ)。
 * - 上限に達していても、数えない呼び出しは許可する。
 */
export function planReservation(
  used: number,
  recordedCategories: string[] | undefined,
  category: string,
): { charge: boolean } {
  const isOtherCategoryOfCountedGacha =
    recordedCategories !== undefined &&
    recordedCategories.length > 0 &&
    !recordedCategories.includes(category);
  if (isOtherCategoryOfCountedGacha) return { charge: false };

  if (used >= LIFETIME_FREE_LIMIT) {
    throw new HttpsError(
      "resource-exhausted",
      `無料利用の上限(${LIFETIME_FREE_LIMIT}回)に達しました。継続利用にはアカウント登録と課金が必要です。`,
      // アプリが、上限の種類に応じた案内(登録・課金・追加課金)を出し分けるため。
      { limitType: "free_tier" satisfies LimitType },
    );
  }
  return { charge: true };
}

/** ガチャの記録にカテゴリを加える(重複しない) */
export function addCategory(recorded: string[] | undefined, category: string): string[] {
  const list = recorded ?? [];
  return list.includes(category) ? list : [...list, category];
}

/** ガチャの記録からカテゴリを外す */
export function removeCategory(recorded: string[] | undefined, category: string): string[] {
  return (recorded ?? []).filter((c) => c !== category);
}

/**
 * 取得に失敗したカテゴリの枠を戻すかどうかを判断する(Firestoreを使わない純粋な関数)。
 *
 * グルメ・観光は並行して取得するため、無料枠を消費した側(最初に確保した側)が
 * 失敗しても、もう一方が成功・取得中なら、そのガチャは使われている。この場合は
 * 枠を戻さず、ガチャの記録に残す。全てのカテゴリが失敗して記録が空になったときに、
 * そのガチャで消費した枠を戻す。
 *
 * - `reservationCharged`: 今回の呼び出しで無料枠を消費したか。
 * - `gachaCharged`: ガチャの記録が、無料枠を消費済みか(記録がなければundefined)。
 */
export function planRelease(
  reservationCharged: boolean,
  gachaCharged: boolean | undefined,
  recorded: string[] | undefined,
  category: string,
): { refund: boolean; remaining: string[] } {
  const remaining = removeCategory(recorded, category);
  if (remaining.length > 0) return { refund: false, remaining };
  return { refund: reservationCharged || gachaCharged === true, remaining };
}

/**
 * 無料利用の枠を確保する(チェックと加算を1トランザクションで行い、
 * 同時リクエストによる上限の突破を防ぐ)。外部API呼び出しの前に呼ぶこと。
 * 上限超過時はHttpsErrorを投げ、加算は行わない。
 *
 * `gachaId`があれば、1回のガチャのグルメ・観光を1回と数える。ない(古い
 * バージョンのアプリ)ときは、従来どおり呼び出しごとに数える。
 */
export async function reserveUsage(
  uid: string,
  category: string,
  gachaId?: string,
): Promise<Reservation> {
  const db = getFirestore();
  const userRef = db.collection("users").doc(uid);
  const gachaRef = gachaId
    ? userRef.collection("gachaUsage").doc(gachaId)
    : undefined;

  return db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    const gachaSnap = gachaRef ? await tx.get(gachaRef) : undefined;
    const used = lifetimeUsedOf(userSnap.data());
    const recorded = gachaSnap?.data()?.categories as string[] | undefined;

    const { charge } = planReservation(used, recorded, category);

    if (charge) {
      tx.set(
        userRef,
        { lifetimeFreeUsed: used + 1, updatedAt: new Date() },
        { merge: true },
      );
    }
    if (gachaRef) {
      // 記録が古い形式(chargedなし)のときは、消費済みとみなす。
      const alreadyCharged = gachaSnap?.exists
        ? (gachaSnap.data()?.charged ?? true)
        : false;
      tx.set(gachaRef, {
        categories: addCategory(recorded, category),
        charged: alreadyCharged || charge,
        updatedAt: new Date(),
        expiresAt: new Date(Date.now() + GACHA_USAGE_TTL_DAYS * 24 * 60 * 60 * 1000),
      });
    }
    return { charged: charge };
  });
}

/**
 * 外部API呼び出しが失敗した場合に、reserveUsageで確保した枠を戻す。
 * 失敗した試行分の回数を消費しないようにするため。数えていた場合は1回分を
 * 戻し、ガチャの記録からそのカテゴリを外す(取り直しが二重に数えられない
 * ようにする)。
 */
export async function releaseUsage(
  uid: string,
  reservation: Reservation,
  category: string,
  gachaId?: string,
): Promise<void> {
  const db = getFirestore();
  const userRef = db.collection("users").doc(uid);
  const gachaRef = gachaId
    ? userRef.collection("gachaUsage").doc(gachaId)
    : undefined;

  await db.runTransaction(async (tx) => {
    // 記録の読み取りが先(トランザクションでは、読み取りのあとに書き込む)。
    const userSnap = await tx.get(userRef);
    const gachaSnap = gachaRef ? await tx.get(gachaRef) : undefined;
    const recorded = gachaSnap?.data()?.categories as string[] | undefined;
    const gachaCharged = gachaSnap?.exists
      ? ((gachaSnap.data()?.charged as boolean | undefined) ?? true)
      : undefined;

    const { refund, remaining } = planRelease(
      reservation.charged,
      gachaCharged,
      recorded,
      category,
    );

    if (refund) {
      const used = lifetimeUsedOf(userSnap.data());
      tx.set(
        userRef,
        { lifetimeFreeUsed: Math.max(0, used - 1), updatedAt: new Date() },
        { merge: true },
      );
    }
    if (gachaRef && gachaSnap?.exists) {
      if (remaining.length === 0) {
        tx.delete(gachaRef);
      } else {
        tx.set(gachaRef, { categories: remaining }, { merge: true });
      }
    }
  });
}
