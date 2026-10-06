import { timingSafeEqual } from "node:crypto";

import { getFirestore } from "firebase-admin/firestore";
import { defineSecret } from "firebase-functions/params";

/**
 * RevenueCat(課金サービス)の「Secret API key」。購読の最新の状態を、RevenueCatの
 * REST APIで取り直すために使う(Issue #133)。アプリには持たせない。
 */
export const revenueCatApiKey = defineSecret("REVENUECAT_API_KEY");

/**
 * RevenueCatのWebhookの設定画面で決める「Authorization header」の値。通知が、
 * RevenueCatからのものかを確かめるために使う(Issue #133)。
 */
export const revenueCatWebhookAuth = defineSecret("REVENUECAT_WEBHOOK_AUTH");

/**
 * 購読中かどうかを決める、RevenueCatのEntitlement(権利)のID。RevenueCatの
 * ダッシュボードで、月額プランの商品を、この名前のEntitlementにつなぐ。
 */
export const PREMIUM_ENTITLEMENT_ID = "burari_date_pro";

/** 通知1回で、状態を取り直すユーザーの最大数(TRANSFERなどで、複数になる場合の上限) */
const MAX_USERS_PER_EVENT = 5;

/**
 * Firebase Authのユーザー(uid)として、使えるIDか。RevenueCatの匿名ID
 * (`$RCAnonymousID:...`)や、Firestoreのパスを壊す文字を含むIDを、取り除く。
 * アプリは、RevenueCatのアプリユーザーIDに、FirebaseのUIDを使う(Issue #132)。
 */
export function isFirebaseUid(value: unknown): value is string {
  return typeof value === "string" && /^[A-Za-z0-9]{1,128}$/.test(value);
}

/**
 * 通知が、RevenueCatからのものかを確かめる(Firestoreを使わない純粋な関数)。
 * Authorizationヘッダーが、設定した値と同じか(`Bearer 値`の形も受け付ける)。
 * 値の比較は、時間で推測されないよう、定数時間で行う。
 */
export function isAuthorized(header: string | undefined, secret: string): boolean {
  if (!header || !secret) return false;
  const expected = [secret, `Bearer ${secret}`];
  return expected.some((candidate) => {
    const a = Buffer.from(header);
    const b = Buffer.from(candidate);
    return a.length === b.length && timingSafeEqual(a, b);
  });
}

/** 通知から取り出す内容 */
export interface WebhookEvent {
  type: string;
  /** 状態を取り直す、Firebaseのユーザー(uid)。TRANSFERでは、複数になる */
  uids: string[];
}

/**
 * 通知の本文を読む(Firestoreを使わない純粋な関数)。形が不正ならnull。
 *
 * 通知は、「このユーザーの購読の状態が変わった」という合図として使う。内容(種類や
 * 期限)は、重複や順番の前後があり得るため、信用せず、状態は、REST APIで取り直す。
 * 対象は、`app_user_id`と、TRANSFERの`transferred_from`・`transferred_to`のうち、
 * Firebaseのユーザーとして使えるID。
 */
export function parseWebhookEvent(body: unknown): WebhookEvent | null {
  const event = (body as { event?: unknown } | null | undefined)?.event as
    | Record<string, unknown>
    | undefined;
  if (!event || typeof event !== "object" || typeof event.type !== "string") {
    return null;
  }
  const candidates: unknown[] = [event.app_user_id];
  for (const key of ["transferred_from", "transferred_to"] as const) {
    const list = event[key];
    if (Array.isArray(list)) candidates.push(...list);
  }
  const uids = [...new Set(candidates.filter(isFirebaseUid))].slice(
    0,
    MAX_USERS_PER_EVENT,
  );
  return { type: event.type, uids };
}

/** REST APIの応答から読み取った、購読の状態 */
export interface SubscriptionInfo {
  /** 購読中は`active`。期限が切れていれば`inactive` */
  status: "active" | "inactive";
  /** 購読の期限(ミリ秒)。期限がないとき(期限のない権利)はnull */
  expiresAtMs: number | null;
  /** この状態を取得した時刻(ミリ秒)。古い取得で、新しい状態を上書きしないための印 */
  requestedAtMs: number;
}

function parseDateMs(value: unknown): number | null | undefined {
  if (value === null) return null;
  if (typeof value !== "string") return undefined;
  const ms = Date.parse(value);
  return Number.isNaN(ms) ? undefined : ms;
}

/**
 * RevenueCatのREST API(`GET /v1/subscribers/{app_user_id}`)の応答から、購読の状態を
 * 読む(Firestoreを使わない純粋な関数)。応答の形が不正なときはundefined。
 *
 * - Entitlementがなければ、購読していない。
 * - 期限(`expires_date`)がnullなら、期限のない権利として、購読中。
 * - 期限を過ぎていても、猶予期間(`grace_period_expires_date`。支払いの再試行の間)が
 *   残っていれば、その終わりまで、購読中として扱う。
 */
export function interpretCustomerInfo(
  json: unknown,
  entitlementId: string,
  fallbackNow: Date,
): SubscriptionInfo | undefined {
  const root = json as {
    request_date_ms?: unknown;
    subscriber?: { entitlements?: Record<string, unknown> };
  } | null;
  const entitlements = root?.subscriber?.entitlements;
  if (!entitlements || typeof entitlements !== "object") return undefined;

  const requestedAtMs =
    typeof root?.request_date_ms === "number"
      ? root.request_date_ms
      : fallbackNow.getTime();

  const entitlement = entitlements[entitlementId] as
    | { expires_date?: unknown; grace_period_expires_date?: unknown }
    | undefined;
  if (!entitlement) {
    return { status: "inactive", expiresAtMs: null, requestedAtMs };
  }

  const expires = parseDateMs(entitlement.expires_date);
  if (expires === undefined) return undefined;
  if (expires === null) {
    return { status: "active", expiresAtMs: null, requestedAtMs };
  }
  const grace = parseDateMs(entitlement.grace_period_expires_date);
  const effective =
    typeof grace === "number" ? Math.max(expires, grace) : expires;
  return {
    status: effective > requestedAtMs ? "active" : "inactive",
    expiresAtMs: effective,
    requestedAtMs,
  };
}

/**
 * 取得した状態を、保存してよいかを判断する(Firestoreを使わない純粋な関数)。
 * 保存済みの状態より、古い時刻に取得したものでは、上書きしない(複数の通知が、
 * 同時に処理されて、順番が前後しても、新しい状態が、残るようにする)。
 */
export function shouldApplySync(
  storedSyncedAtMs: unknown,
  requestedAtMs: number,
): boolean {
  return typeof storedSyncedAtMs !== "number" || requestedAtMs >= storedSyncedAtMs;
}

/** RevenueCatから、購読の状態を取り直す。失敗したら例外を投げる。 */
export async function fetchSubscriptionInfo(
  apiKey: string,
  uid: string,
  now: Date = new Date(),
): Promise<SubscriptionInfo> {
  const res = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`,
    { headers: { authorization: `Bearer ${apiKey}`, "content-type": "application/json" } },
  );
  if (!res.ok) {
    throw new Error(`RevenueCat APIの呼び出しに失敗しました: ${res.status}`);
  }
  const info = interpretCustomerInfo(await res.json(), PREMIUM_ENTITLEMENT_ID, now);
  if (!info) throw new Error("RevenueCat APIの応答を読めませんでした");
  return info;
}

/**
 * 購読の状態を、ユーザーのドキュメントに保存する。保存済みより古い取得なら、何もしない
 * (戻り値はfalse)。`subscriptionStatus`・`subscriptionExpiresAt`は、回数の判断
 * (fairUse.tsの`isSubscriptionActive`)が読む。
 */
export async function saveSubscription(
  uid: string,
  info: SubscriptionInfo,
  now: Date = new Date(),
): Promise<boolean> {
  const db = getFirestore();
  const ref = db.collection("users").doc(uid);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!shouldApplySync(snap.data()?.subscriptionSyncedAtMs, info.requestedAtMs)) {
      return false;
    }
    tx.set(
      ref,
      {
        subscriptionStatus: info.status,
        subscriptionExpiresAt:
          info.expiresAtMs === null ? null : new Date(info.expiresAtMs),
        subscriptionSyncedAtMs: info.requestedAtMs,
        updatedAt: now,
      },
      { merge: true },
    );
    return true;
  });
}
