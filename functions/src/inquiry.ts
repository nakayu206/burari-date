import { getFirestore } from "firebase-admin/firestore";
import { defineSecret } from "firebase-functions/params";
import { HttpsError } from "firebase-functions/v2/https";

/** メール送信サービス(Resend)のAPIキー(Issue #119) */
export const resendApiKey = defineSecret("RESEND_API_KEY");

/**
 * 問い合わせを受け取る運営者のメールアドレス。アプリには持たせず、Secretにだけ
 * 置く(アプリを解析されても漏れない)。
 */
export const inquiryToEmail = defineSecret("INQUIRY_TO_EMAIL");

export const INQUIRY_CATEGORIES = ["bug", "request", "other"] as const;
export type InquiryCategory = (typeof INQUIRY_CATEGORIES)[number];

const CATEGORY_LABELS: Record<InquiryCategory, string> = {
  bug: "不具合",
  request: "要望",
  other: "その他",
};

export const MAX_MESSAGE_LENGTH = 1000;
const MAX_REPLY_TO_LENGTH = 254;
const MAX_META_LENGTH = 40;

/** 1人が、1日に送れる問い合わせの回数(悪用・誤送信の対策) */
export const DAILY_INQUIRY_LIMIT = 5;

/** 差出人。独自ドメインを持つまでは、Resendのテスト用アドレスを使う。 */
const FROM_ADDRESS = "ぶらりデートガチャ <onboarding@resend.dev>";

export interface Inquiry {
  category: InquiryCategory;
  message: string;
  /** 返信先のメールアドレス(必須。匿名ログインのため、ほかに連絡の手段がない) */
  replyTo: string;
}

/** 調査用に、メールに添える情報 */
export interface InquiryMeta {
  uid: string;
  appVersion?: string;
  flavor?: string;
}

// 厳密な検証はせず、明らかな間違い(空白・@なし)だけを弾く。
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function invalid(message: string): HttpsError {
  return new HttpsError("invalid-argument", message);
}

/** リクエストの内容を検証して、問い合わせに変換する(Firestoreを使わない純粋な関数) */
export function parseInquiry(data: unknown): Inquiry {
  const d = (data ?? {}) as Record<string, unknown>;

  const category = d.category;
  if (!INQUIRY_CATEGORIES.includes(category as InquiryCategory)) {
    throw invalid("お問い合わせの種類が不正です");
  }

  if (typeof d.message !== "string") throw invalid("本文を入力してください");
  const message = d.message.trim();
  if (message === "") throw invalid("本文を入力してください");
  if (message.length > MAX_MESSAGE_LENGTH) {
    throw invalid(`本文は${MAX_MESSAGE_LENGTH}文字までです`);
  }

  if (typeof d.replyTo !== "string" || d.replyTo.trim() === "") {
    throw invalid("返信先のメールアドレスを入力してください");
  }
  const replyTo = d.replyTo.trim();
  if (replyTo.length > MAX_REPLY_TO_LENGTH || !EMAIL_PATTERN.test(replyTo)) {
    throw invalid("返信先のメールアドレスが不正です");
  }

  return { category: category as InquiryCategory, message, replyTo };
}

/** 改行や制御文字を除き、長さを切る(本文に添える、アプリ側が送る文字列用) */
export function sanitizeMeta(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  // eslint-disable-next-line no-control-regex
  const cleaned = value.replace(/[\u0000-\u001f\u007f]/g, " ").trim();
  return cleaned === "" ? undefined : cleaned.slice(0, MAX_META_LENGTH);
}

/**
 * Resend(メール送信API)に渡す内容を作る。件名は固定の文言と種類だけで作り、
 * 利用者の入力は本文にだけ入れる(件名への注入を防ぐ)。返信先(必須)はReply-Toに設定する。
 */
export function buildResendPayload(
  inquiry: Inquiry,
  meta: InquiryMeta,
  to: string,
) {
  const label = CATEGORY_LABELS[inquiry.category];
  const lines = [
    `種類: ${label}`,
    `返信先: ${inquiry.replyTo}`,
    "",
    inquiry.message,
    "",
    "---",
    `ユーザーID: ${meta.uid}`,
    `アプリのバージョン: ${meta.appVersion ?? "不明"}`,
    `Flavor: ${meta.flavor ?? "不明"}`,
  ];
  return {
    from: FROM_ADDRESS,
    to: [to],
    subject: `[ぶらりデートガチャ] ${label}のお問い合わせ`,
    text: lines.join("\n"),
    reply_to: inquiry.replyTo,
  };
}

/** 回数の判断(Firestoreを使わない純粋な関数)。上限に達していたら例外を投げる。 */
export function assertWithinDailyLimit(sentToday: number): void {
  if (sentToday >= DAILY_INQUIRY_LIMIT) {
    throw new HttpsError(
      "resource-exhausted",
      `お問い合わせは、1日${DAILY_INQUIRY_LIMIT}回までです。明日、もう一度お試しください。`,
    );
  }
}

/** 日本時間の日付(YYYYMMDD)。1日の回数を数える単位。 */
export function dayKeyOf(now: Date): string {
  const jst = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  return jst.toISOString().slice(0, 10).replace(/-/g, "");
}

/**
 * 今日の送信回数を1つ増やす(チェックと加算を1トランザクションで行い、同時
 * リクエストによる上限の突破を防ぐ)。メールを送る前に呼ぶこと。返す値は、
 * 失敗したときに回数を戻す(releaseInquiry)ための、日付のキー。
 */
export async function reserveInquiry(
  uid: string,
  now: Date = new Date(),
): Promise<string> {
  const db = getFirestore();
  const dayKey = dayKeyOf(now);
  const ref = db
    .collection("users")
    .doc(uid)
    .collection("inquiryUsage")
    .doc(dayKey);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const count = (snap.data()?.count as number | undefined) ?? 0;
    assertWithinDailyLimit(count);
    tx.set(ref, { count: count + 1, updatedAt: new Date() }, { merge: true });
  });
  return dayKey;
}

/** メールの送信に失敗したときに、reserveInquiryで増やした回数を戻す */
export async function releaseInquiry(uid: string, dayKey: string): Promise<void> {
  const db = getFirestore();
  const ref = db
    .collection("users")
    .doc(uid)
    .collection("inquiryUsage")
    .doc(dayKey);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const count = (snap.data()?.count as number | undefined) ?? 0;
    tx.set(ref, { count: Math.max(0, count - 1) }, { merge: true });
  });
}

/** Resendでメールを送る。失敗したら例外を投げる。 */
export async function sendEmail(
  apiKey: string,
  payload: ReturnType<typeof buildResendPayload>,
): Promise<void> {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    throw new Error(`メールの送信に失敗しました: ${res.status}`);
  }
}
