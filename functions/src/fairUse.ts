import { getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

/**
 * 無料で使える累計回数(コスト対策バックストップ、仕様書10章)。
 * 1回は「1回のガチャ」で、そのガチャのグルメ・観光の両方の取得を含む。
 */
export const LIFETIME_FREE_LIMIT = 10;

/**
 * 購読中(月額サブスク)の、月のフェアユース上限(月30回目安、仕様書10章)。
 * 表向きは使い放題で、日常の利用では達しない想定。月ごとに数え直す。
 */
export const MONTHLY_FAIR_USE_LIMIT = 30;

/**
 * 上限エラーの種類。
 * - `free_tier`: 無料枠(累計10回)を使い切った
 * - `monthly`: 購読中の、月のフェアユース上限(月30回目安)を超えた(来月まで待つ)
 */
export type LimitType = "free_tier" | "monthly";

/**
 * 回数の出どころ(どの回数を消費したか)。失敗したときに、同じ種類の回数を戻す
 * ために、記録する。
 * - `free`: 無料枠(累計10回)
 * - `monthly`: 購読中の、月の回数
 */
export type UsageSource = "free" | "monthly";

/** ガチャごとの取得記録を残す日数(TTLポリシーを設定したときに古い記録を消す目安) */
const GACHA_USAGE_TTL_DAYS = 30;

/** gachaIdとして受け付ける形式(FirestoreのドキュメントIDに使うため制限する) */
const GACHA_ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;

export function isValidGachaId(value: unknown): value is string {
  return typeof value === "string" && GACHA_ID_PATTERN.test(value);
}

/** deviceIdとして受け付ける形式(FirestoreのドキュメントIDに使うため制限する) */
const DEVICE_ID_PATTERN = /^[A-Za-z0-9_-]{16,64}$/;

/**
 * 端末ごとの識別子として受け付けられるか。アプリが最初に1回だけ作るランダムなIDで、
 * 無料枠を、ログアウトで数え直されないようにするために使う(再インストールは、バックアップで復元されたときだけ防げる)。
 */
export function isValidDeviceId(value: unknown): value is string {
  return typeof value === "string" && DEVICE_ID_PATTERN.test(value);
}

/**
 * 回数の判断に使う、ユーザーの利用状況。Firestoreの値([readUserUsage])を、判断に
 * 使う形にしたもの。
 */
export interface UserUsage {
  /** 無料枠(累計)で、使った回数。月ごとには回復しない */
  lifetimeFreeUsed: number;
  /** 購読中か(解約しても、期限が切れるまでは購読中) */
  isSubscriber: boolean;
  /** 今月、使った回数(月が変わっていれば0) */
  monthlyUsed: number;
}

function countOf(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) && value > 0
    ? Math.floor(value)
    : 0;
}

/** FirestoreのTimestamp・Date・ミリ秒を、ミリ秒にそろえる */
function toMillis(value: unknown): number | undefined {
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number") return value;
  const v = value as { toMillis?: () => number } | null | undefined;
  if (v && typeof v.toMillis === "function") return v.toMillis();
  return undefined;
}

/** 月の区切り(日本時間のYYYYMM)。月のフェアユース上限を、数え直す単位。 */
export function monthKeyOf(now: Date): string {
  const jst = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  return jst.toISOString().slice(0, 7).replace("-", "");
}

/**
 * 購読中か。`subscriptionStatus`が`active`で、期限(`subscriptionExpiresAt`)が
 * あれば、まだ過ぎていないとき。期限がないときは、状態だけで判断する。
 * 解約しても、期限が切れるまでは、購読中として扱う。
 *
 * 更新の通知は、期限を過ぎてから届くことがある(Test Storeでは約1分半)。そのあいだに、
 * 購読中の利用者が、上限の画面にならないよう、期限から`SUBSCRIPTION_GRACE_MS`までは、
 * 購読中として扱う。
 */
export function isSubscriptionActive(
  data: FirebaseFirestore.DocumentData | undefined,
  now: Date,
): boolean {
  if (data?.subscriptionStatus !== "active") return false;
  const expiresAt = toMillis(data?.subscriptionExpiresAt);
  return expiresAt === undefined || expiresAt + SUBSCRIPTION_GRACE_MS > now.getTime();
}

/** 期限を過ぎたあとも、更新の通知を待つ猶予(6時間) */
export const SUBSCRIPTION_GRACE_MS = 6 * 60 * 60 * 1000;

/**
 * ユーザーのドキュメントの値を、判断に使う利用状況にする(月が変われば、月の回数は0)。
 *
 * 無料枠の使用回数は、ユーザーと端末(`deviceData`)の、多いほうにする。ログアウトで
 * 新しいゲストになっても、端末の記録が残るため、無料枠が数え直されない。
 */
export function readUserUsage(
  data: FirebaseFirestore.DocumentData | undefined,
  now: Date,
  deviceData?: FirebaseFirestore.DocumentData,
): UserUsage {
  const isSameMonth = data?.monthlyKey === monthKeyOf(now);
  return {
    lifetimeFreeUsed: Math.max(
      countOf(data?.lifetimeFreeUsed),
      countOf(deviceData?.lifetimeFreeUsed),
    ),
    isSubscriber: isSubscriptionActive(data, now),
    monthlyUsed: isSameMonth ? countOf(data?.monthlyGachaCount) : 0,
  };
}

/** 枠を確保した結果。失敗時に、何を戻すかを判断するために使う。 */
export interface Reservation {
  /** 今回の呼び出しで、回数を1回消費したか(すでに数えたガチャの別カテゴリならfalse) */
  charged: boolean;
  /** 消費した回数の出どころ(消費していないときはundefined) */
  source?: UsageSource;
}

/**
 * 新しいガチャ1回を、どの回数から消費するかを決める(Firestoreを使わない純粋な関数)。
 * 消費できる回数がなければ、HttpsErrorを投げる。
 *
 * - 購読中: 月のフェアユース上限の範囲では、月の回数。上限に達したら、月の上限として
 *   拒否する(追加購入は、ない。来月になると、また使える)。
 * - 購読していない(解約・期限切れも含む): 無料枠(累計10回)。使い切っていたら
 *   拒否する。購読が切れても、無料枠は、復活しない。
 */
export function planCharge(usage: UserUsage): { source: UsageSource } {
  if (usage.isSubscriber) {
    if (usage.monthlyUsed < MONTHLY_FAIR_USE_LIMIT) return { source: "monthly" };
    throw new HttpsError(
      "resource-exhausted",
      `今月の利用上限(${MONTHLY_FAIR_USE_LIMIT}回)に達しました。来月になると、また、ご利用いただけます。`,
      // アプリが、上限の種類に応じた案内(登録・課金・来月まで待つ)を出し分けるため。
      { limitType: "monthly" satisfies LimitType },
    );
  }
  if (usage.lifetimeFreeUsed < LIFETIME_FREE_LIMIT) return { source: "free" };
  throw new HttpsError(
    "resource-exhausted",
    `無料利用の上限(${LIFETIME_FREE_LIMIT}回)に達しました。継続利用にはアカウント登録と課金が必要です。`,
    // アプリが、上限の種類に応じた案内(登録・課金・来月まで待つ)を出し分けるため。
    { limitType: "free_tier" satisfies LimitType },
  );
}

/**
 * 今回の取得で、回数を消費するかを判断する(Firestoreを使わない純粋な関数)。
 *
 * - `recordedCategories`は、同じガチャですでに取得したカテゴリ。ガチャの記録が
 *   ない(または`gachaId`なし)ときはundefined。
 * - そのガチャで初めての取得は1回と数える(どの回数かは[planCharge])。すでに取得した
 *   カテゴリと違うカテゴリなら、数えない(1回のガチャのグルメ・観光は1回)。
 * - 同じカテゴリの取り直しは、また1回と数える(同じgachaIdの使い回しによる
 *   無制限の利用を防ぐ)。
 * - 上限に達していても、数えない呼び出しは許可する。
 */
export function planUsage(
  usage: UserUsage,
  recordedCategories: string[] | undefined,
  category: string,
): { source?: UsageSource } {
  const isOtherCategoryOfCountedGacha =
    recordedCategories !== undefined &&
    recordedCategories.length > 0 &&
    !recordedCategories.includes(category);
  if (isOtherCategoryOfCountedGacha) return {};

  return planCharge(usage);
}

/**
 * 回数を消費するときの、ユーザーのドキュメントに書く値(Firestoreを使わない純粋な関数)。
 * 月の回数は、月が変わっていれば、今月の分として、1から数え直す。
 */
export function applyCharge(
  source: UsageSource,
  usage: UserUsage,
  now: Date,
): Record<string, number | string> {
  switch (source) {
    case "free":
      return { lifetimeFreeUsed: usage.lifetimeFreeUsed + 1 };
    case "monthly":
      return { monthlyGachaCount: usage.monthlyUsed + 1, monthlyKey: monthKeyOf(now) };
  }
}

/**
 * 消費した回数を戻すときの、ユーザーのドキュメントに書く値(Firestoreを使わない
 * 純粋な関数)。消費した回数と同じ種類の回数を戻す。
 *
 * 月の回数は、今月に消費した分だけ戻す。月をまたいだ後の失敗では、新しい月の回数は、
 * 消費していないため、戻さない(何も書かない)。
 */
export function applyRefund(
  source: UsageSource,
  usage: UserUsage,
  now: Date,
): Record<string, number | string> {
  switch (source) {
    case "free":
      return { lifetimeFreeUsed: Math.max(0, usage.lifetimeFreeUsed - 1) };
    case "monthly":
      return usage.monthlyUsed > 0
        ? { monthlyGachaCount: usage.monthlyUsed - 1, monthlyKey: monthKeyOf(now) }
        : {};
  }
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
 * グルメ・観光は並行して取得するため、回数を消費した側(最初に確保した側)が
 * 失敗しても、もう一方が成功・取得中なら、そのガチャは使われている。この場合は
 * 枠を戻さず、ガチャの記録に残す。全てのカテゴリが失敗して記録が空になったときに、
 * そのガチャで消費した枠を戻す。
 *
 * - `reservationCharged`: 今回の呼び出しで回数を消費したか。
 * - `gachaCharged`: ガチャの記録が、回数を消費済みか(記録がなければundefined)。
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
 * 利用の枠を確保する(チェックと加算を1トランザクションで行い、
 * 同時リクエストによる上限の突破を防ぐ)。外部API呼び出しの前に呼ぶこと。
 * 上限超過時はHttpsErrorを投げ、加算は行わない。
 *
 * `gachaId`があれば、1回のガチャのグルメ・観光を1回と数える。ない(古い
 * バージョンのアプリ)ときは、従来どおり呼び出しごとに数える。
 * どの回数(無料枠・月の回数)を使うかは、[planCharge]。
 *
 * `deviceId`があれば、無料枠は、端末ごとにも数える(ログアウトで
 * 無料枠が戻らないようにするため)。
 */
export async function reserveUsage(
  uid: string,
  category: string,
  gachaId?: string,
  now: Date = new Date(),
  deviceId?: string,
): Promise<Reservation> {
  const db = getFirestore();
  const userRef = db.collection("users").doc(uid);
  const deviceRef = deviceId ? db.collection("devices").doc(deviceId) : undefined;
  const gachaRef = gachaId
    ? userRef.collection("gachaUsage").doc(gachaId)
    : undefined;

  return db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    const deviceSnap = deviceRef ? await tx.get(deviceRef) : undefined;
    const gachaSnap = gachaRef ? await tx.get(gachaRef) : undefined;
    const usage = readUserUsage(userSnap.data(), now, deviceSnap?.data());
    const recorded = gachaSnap?.data()?.categories as string[] | undefined;

    const { source } = planUsage(usage, recorded, category);

    if (source) {
      tx.set(
        userRef,
        { ...applyCharge(source, usage, now), updatedAt: now },
        { merge: true },
      );
      if (deviceRef && source === "free") {
        tx.set(
          deviceRef,
          { lifetimeFreeUsed: usage.lifetimeFreeUsed + 1, updatedAt: now },
          { merge: true },
        );
      }
    }
    if (gachaRef) {
      // 記録が古い形式(chargedなし)のときは、消費済みとみなす。
      const alreadyCharged = gachaSnap?.exists
        ? (gachaSnap.data()?.charged ?? true)
        : false;
      // 回数の出どころは、最初に消費したときのものを引き継ぐ。
      const chargedSource =
        source ?? (gachaSnap?.data()?.chargedSource as UsageSource | undefined);
      tx.set(gachaRef, {
        categories: addCategory(recorded, category),
        charged: alreadyCharged || source !== undefined,
        ...(chargedSource ? { chargedSource } : {}),
        updatedAt: now,
        expiresAt: new Date(now.getTime() + GACHA_USAGE_TTL_DAYS * 24 * 60 * 60 * 1000),
      });
    }
    return { charged: source !== undefined, source };
  });
}

/**
 * 外部API呼び出しが失敗した場合に、reserveUsageで確保した枠を戻す。
 * 失敗した試行分の回数を消費しないようにするため。数えていた場合は、消費した回数と
 * 同じ種類の回数を1回分戻し、ガチャの記録からそのカテゴリを外す(取り直しが二重に
 * 数えられないようにする)。
 */
export async function releaseUsage(
  uid: string,
  reservation: Reservation,
  category: string,
  gachaId?: string,
  now: Date = new Date(),
  deviceId?: string,
): Promise<void> {
  const db = getFirestore();
  const userRef = db.collection("users").doc(uid);
  const deviceRef = deviceId ? db.collection("devices").doc(deviceId) : undefined;
  const gachaRef = gachaId
    ? userRef.collection("gachaUsage").doc(gachaId)
    : undefined;

  await db.runTransaction(async (tx) => {
    // 記録の読み取りが先(トランザクションでは、読み取りのあとに書き込む)。
    const userSnap = await tx.get(userRef);
    const deviceSnap = deviceRef ? await tx.get(deviceRef) : undefined;
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
      // 出どころの記録がない古い記録は、無料枠を消費したものとして戻す。
      const source: UsageSource =
        reservation.source ??
        (gachaSnap?.data()?.chargedSource as UsageSource | undefined) ??
        "free";
      const usage = readUserUsage(userSnap.data(), now, deviceSnap?.data());
      const refundFields = applyRefund(source, usage, now);
      if (Object.keys(refundFields).length > 0) {
        tx.set(userRef, { ...refundFields, updatedAt: now }, { merge: true });
      }
      if (deviceRef && source === "free") {
        tx.set(
          deviceRef,
          { lifetimeFreeUsed: Math.max(0, usage.lifetimeFreeUsed - 1), updatedAt: now },
          { merge: true },
        );
      }
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
