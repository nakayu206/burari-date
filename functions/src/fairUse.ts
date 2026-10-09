import { randomUUID } from "node:crypto";

import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import { deletedAccountRef } from "./account";

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
  /** 枠を確保した月(日本時間のYYYYMM)。月をまたいで失敗したときに、戻す月を照合する */
  monthKey: string;
  /**
   * この呼び出しを区別するID。同じカテゴリの取り直しなど、別の呼び出しが、ガチャの
   * 記録を引き継いだあとに、遅れて失敗した呼び出しが、その記録を消さないようにする。
   */
  requestId: string;
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

/**
 * 消費した回数を戻してよいか(Firestoreを使わない純粋な関数)。月の回数は、消費した月と、
 * ユーザーが持つ月の回数の月(`monthlyKey`)が、同じときだけ戻す。月をまたいで失敗したとき、
 * 先月の分を戻すと、その間に成功した、今月の回数を減らしてしまうため。消費した月の記録が
 * ない(古い記録)ときは、戻す。月に関係しない回数(無料枠)は、いつでも戻す。
 */
export function isRefundableMonth(
  source: UsageSource,
  userMonthlyKey: string | undefined,
  chargedMonthKey: string | undefined,
): boolean {
  if (source !== "monthly") return true;
  if (chargedMonthKey === undefined) return true;
  return userMonthlyKey === chargedMonthKey;
}

/** ガチャの記録にカテゴリを加える(重複しない) */
export function addCategory(recorded: string[] | undefined, category: string): string[] {
  const list = recorded ?? [];
  return list.includes(category) ? list : [...list, category];
}

/**
 * 処理中の取得を、記録に残しておく時間(ミリ秒)。`getCandidates`の待ち時間(120秒)より
 * 長くする。クラッシュなどで、処理中のまま残った記録は、これを過ぎたら、無視する。
 */
export const IN_FLIGHT_TTL_MS = 150 * 1000;

/** カテゴリごとの、処理中の取得(呼び出しのIDと、開始した時刻) */
export interface InFlightEntry {
  id: string;
  at: number;
}

/** 処理中の取得の一覧に、今回の呼び出しを加える。古い(期限を過ぎた)ものは、取り除く。 */
export function addInFlight(
  list: InFlightEntry[] | undefined,
  requestId: string,
  nowMs: number,
): InFlightEntry[] {
  const alive = (list ?? []).filter(
    (e) => e.id !== requestId && nowMs - e.at < IN_FLIGHT_TTL_MS,
  );
  return [...alive, { id: requestId, at: nowMs }];
}

/** 処理中の取得の一覧から、今回の呼び出しを外す(成功・失敗で、終わったとき)。 */
export function removeInFlight(
  list: InFlightEntry[] | undefined,
  requestId: string,
): InFlightEntry[] {
  return (list ?? []).filter((e) => e.id !== requestId);
}

/** 今回の呼び出しのほかに、同じカテゴリで、処理中の取得があるか(期限を過ぎたものは除く)。 */
export function hasOtherInFlight(
  list: InFlightEntry[] | undefined,
  requestId: string,
  nowMs: number,
): boolean {
  return (list ?? []).some((e) => e.id !== requestId && nowMs - e.at < IN_FLIGHT_TTL_MS);
}

/** ガチャの記録からカテゴリを外す */
export function removeCategory(recorded: string[] | undefined, category: string): string[] {
  return (recorded ?? []).filter((c) => c !== category);
}

/**
 * 取得に失敗した呼び出しの枠を、戻すかどうかを判断する(Firestoreを使わない純粋な関数)。
 *
 * ガチャの記録は、**消費を、何回、保持しているか**(`heldCharges`)を持つ。決まりは、次の2つ。
 * - ガチャに、カテゴリが残っている(成功・処理中)間は、**最低1回の消費を、保持する**。
 * - 失敗した呼び出しは、自分の分を戻しても、保持が、必要な回数(カテゴリが残っていれば1)を
 *   下回らないときだけ、戻す。
 *
 * これで、グルメ・観光、取り直しが、どの順番で、成功・失敗しても、成功したカテゴリがある間は、
 * 消費が1回、残る。取り直しで、追加で消費した分は、保持が、必要な回数を超えているため、
 * 失敗したら、戻る。
 *
 * - `reservationCharged`: 今回の呼び出しが、回数を消費したか(別カテゴリは、消費しない)。
 * - `heldCharges`: ガチャの記録が、いま、保持している消費の回数(今回の分を含む)。
 * - `categorySucceeded`: そのカテゴリを、すでに、取得に成功したか。成功済みのカテゴリは、
 *   取り直しが失敗しても、記録を残す。
 * - `othersInFlight`: 同じカテゴリで、今回のほかに、処理中の取得があるか。ある間は、記録を残す。
 * - 戻り値の`remaining`: 失敗のあとに、ガチャの記録に残すカテゴリ。
 */
export function planRelease(
  reservationCharged: boolean,
  heldCharges: number,
  recorded: string[] | undefined,
  category: string,
  othersInFlight = false,
  categorySucceeded = false,
): { refund: boolean; remaining: string[] } {
  const keepCategory = categorySucceeded || othersInFlight;
  const remaining = keepCategory ? (recorded ?? []) : removeCategory(recorded, category);
  // カテゴリが残っていれば、最低1回の消費を、保持する。
  const needed = remaining.length > 0 ? 1 : 0;
  // 消費した呼び出しは、自分の分を戻す。消費していない呼び出し(別カテゴリ)は、ガチャとして
  // 保持している分のうち、必要な回数を超える分を戻す。
  const refund = reservationCharged ? heldCharges - 1 >= needed : heldCharges > needed;
  return { refund, remaining };
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
  const requestId = randomUUID();

  const deletedRef = deletedAccountRef(uid);

  return db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    // 削除済みのアカウントは、断る(削除したユーザーの記録を、作り直さないため)。
    if ((await tx.get(deletedRef)).exists) {
      throw new HttpsError("unauthenticated", "サインインが必要です");
    }
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
      // 回数の出どころと、消費した月は、ガチャで最初に消費したときのものを引き継ぐ
      // (取り直しで、追加で消費した分は、その呼び出しの[Reservation]が持つ)。
      const existing = gachaSnap?.data();
      const chargedSource = alreadyCharged
        ? (existing?.chargedSource as UsageSource | undefined)
        : source;
      const chargedMonthKey = alreadyCharged
        ? (existing?.chargedMonthKey as string | undefined)
        : source
          ? monthKeyOf(now)
          : undefined;
      // ガチャが、保持している消費の回数。古い記録(heldChargesなし)は、消費済みなら1回とみなす。
      const heldBefore =
        (existing?.heldCharges as number | undefined) ?? (alreadyCharged ? 1 : 0);
      tx.set(gachaRef, {
        categories: addCategory(recorded, category),
        heldCharges: heldBefore + (source !== undefined ? 1 : 0),
        // 取得に成功したカテゴリ(markCategorySucceededで記録する)。引き継ぐ。
        categorySucceeded: (existing?.categorySucceeded as string[] | undefined) ?? [],
        // カテゴリごとの、処理中の取得。終わった呼び出し(成功・失敗)が、自分を外す。
        // ほかに処理中のものがある間は、失敗した呼び出しが、カテゴリの記録を消さない。
        inFlight: {
          ...((existing?.inFlight as Record<string, InFlightEntry[]> | undefined) ?? {}),
          [category]: addInFlight(
            (existing?.inFlight as Record<string, InFlightEntry[]> | undefined)?.[category],
            requestId,
            now.getTime(),
          ),
        },
        charged: alreadyCharged || source !== undefined,
        ...(chargedSource ? { chargedSource } : {}),
        ...(chargedMonthKey ? { chargedMonthKey } : {}),
        updatedAt: now,
        expiresAt: new Date(now.getTime() + GACHA_USAGE_TTL_DAYS * 24 * 60 * 60 * 1000),
      });
    }
    return {
      charged: source !== undefined,
      source,
      monthKey: monthKeyOf(now),
      requestId,
    };
  });
}

/**
 * そのカテゴリの取得に成功したことを、ガチャの記録に残し、処理中の一覧から、今回の呼び出しを
 * 外す。あとの取り直しが失敗しても、成功済みのカテゴリの記録を消さないために使う。記録がない
 * (ほかの呼び出しが消した・アカウントを削除した)ときや、失敗したときは、何もしない
 * (取得自体は成功しているため、失敗にしない)。
 */
export async function markCategorySucceeded(
  uid: string,
  gachaId: string | undefined,
  category: string,
  requestId: string,
): Promise<void> {
  if (!gachaId) return;
  try {
    const db = getFirestore();
    const ref = db
      .collection("users")
      .doc(uid)
      .collection("gachaUsage")
      .doc(gachaId);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return;
      const inFlight = (snap.data()?.inFlight as Record<string, InFlightEntry[]> | undefined)?.[
        category
      ];
      tx.update(ref, {
        categorySucceeded: FieldValue.arrayUnion(category),
        [`inFlight.${category}`]: removeInFlight(inFlight, requestId),
      });
    });
  } catch (e) {
    console.warn("取得の成功を記録できませんでした", e);
  }
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
    // ガチャが、保持している消費の回数。古い記録(heldChargesなし)は、消費済みなら1回とみなす。
    // 記録がない(gachaIdなし)ときは、今回消費した分だけ。
    const heldCharges = gachaSnap?.exists
      ? ((gachaSnap.data()?.heldCharges as number | undefined) ??
        ((gachaSnap.data()?.charged as boolean | undefined) === false ? 0 : 1))
      : reservation.charged
        ? 1
        : 0;

    // アカウントが削除されたあとに、遅れて終わった呼び出しは、何も書かない(削除した
    // ユーザーの記録を、作り直さないため)。
    if (!userSnap.exists) return;

    // 同じカテゴリで、今回のほかに、処理中の取得があるか。
    const inFlight = (
      gachaSnap?.data()?.inFlight as Record<string, InFlightEntry[]> | undefined
    )?.[category];
    const othersInFlight = hasOtherInFlight(inFlight, reservation.requestId, now.getTime());
    const categorySucceeded =
      (gachaSnap?.data()?.categorySucceeded as string[] | undefined)?.includes(category) ===
      true;

    const { refund, remaining } = planRelease(
      reservation.charged,
      heldCharges,
      recorded,
      category,
      othersInFlight,
      categorySucceeded,
    );

    if (refund) {
      // 出どころの記録がない古い記録は、無料枠を消費したものとして戻す。
      const source: UsageSource =
        reservation.source ??
        (gachaSnap?.data()?.chargedSource as UsageSource | undefined) ??
        "free";
      // 戻す回数を、消費した月。今回の呼び出しが消費したなら、その月。そうでなければ、
      // ガチャの記録が持つ、最初に消費した月。
      const chargedMonthKey = reservation.charged
        ? reservation.monthKey
        : (gachaSnap?.data()?.chargedMonthKey as string | undefined);
      const usage = readUserUsage(userSnap.data(), now, deviceSnap?.data());
      const refundFields = isRefundableMonth(
        source,
        userSnap.data()?.monthlyKey as string | undefined,
        chargedMonthKey,
      )
        ? applyRefund(source, usage, now)
        : {};
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
        // 今回の呼び出しは、終わったので、処理中の一覧から、外す。
        tx.update(gachaRef, {
          categories: remaining,
          heldCharges: refund ? Math.max(0, heldCharges - 1) : heldCharges,
          [`inFlight.${category}`]: removeInFlight(inFlight, reservation.requestId),
        });
      }
    }
  });
}
