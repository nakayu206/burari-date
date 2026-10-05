import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  buildResendPayload,
  inquiryToEmail,
  parseInquiry,
  releaseInquiry,
  reserveInquiry,
  resendApiKey,
  sanitizeMeta,
  sendEmail,
} from "./inquiry";

/**
 * アプリ内の問い合わせフォームの内容を、運営者のメールに送る(Issue #119)。
 * サインイン済み(匿名でよい)のユーザーだけが使え、1日の回数を制限する。
 */
export const sendInquiry = onCall(
  {
    secrets: [resendApiKey, inquiryToEmail],
    region: "us-central1",
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "サインインが必要です");
    }
    const uid = request.auth.uid;

    const inquiry = parseInquiry(request.data);
    const data = (request.data ?? {}) as Record<string, unknown>;
    const payload = buildResendPayload(
      inquiry,
      {
        uid,
        appVersion: sanitizeMeta(data.appVersion),
        flavor: sanitizeMeta(data.flavor),
      },
      inquiryToEmail.value(),
    );

    const dayKey = await reserveInquiry(uid);
    try {
      await sendEmail(resendApiKey.value(), payload);
    } catch (e) {
      await releaseInquiry(uid, dayKey);
      throw new HttpsError(
        "internal",
        "お問い合わせを送信できませんでした。しばらくしてから、もう一度お試しください。",
      );
    }
    return { ok: true };
  },
);
