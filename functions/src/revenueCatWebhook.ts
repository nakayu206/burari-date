import { onRequest } from "firebase-functions/v2/https";

import {
  describeSync,
  fetchSubscriptionInfo,
  isAuthorized,
  parseWebhookEvent,
  revenueCatApiKey,
  revenueCatWebhookAuth,
  saveSubscription,
} from "./subscription";

/**
 * RevenueCatからの通知(Webhook)を受け取り、購読の状態を保存する(Issue #133)。
 *
 * 通知は、「このユーザーの状態が変わった」という合図として使い、状態は、RevenueCatの
 * REST APIで取り直す(通知は、重複・順番の前後があり得るため。RevenueCatの推奨)。
 * 通知が本物かは、Webhookの設定で決めた認証用の値で確かめる。
 *
 * 応答: 60秒以内に200を返す。失敗(500)のときは、RevenueCatが、最大5回、再送する。
 */
export const revenueCatWebhook = onRequest(
  {
    secrets: [revenueCatApiKey, revenueCatWebhookAuth],
    region: "us-central1",
    timeoutSeconds: 30,
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("method not allowed");
      return;
    }
    if (!isAuthorized(req.get("authorization"), revenueCatWebhookAuth.value())) {
      res.status(401).send("unauthorized");
      return;
    }

    const event = parseWebhookEvent(req.body);
    if (!event) {
      res.status(400).send("invalid body");
      return;
    }
    // 疎通の確認(TEST)や、FirebaseのユーザーではないID(RevenueCatの匿名IDなど)は、
    // することがない。再送されないよう、200を返す。
    if (event.uids.length === 0) {
      res.status(200).send("ignored");
      return;
    }

    try {
      const results = [];
      for (const uid of event.uids) {
        const info = await fetchSubscriptionInfo(revenueCatApiKey.value(), uid);
        const saved = await saveSubscription(uid, info);
        results.push({ uid, info, saved });
      }
      // 成功したときも、ログに残す(通知が届き、保存できたかを、確かめられるように)。
      console.log(JSON.stringify(describeSync(event.type, results)));
      res.status(200).send("ok");
    } catch (e) {
      // 500を返し、RevenueCatに再送してもらう。
      console.error("購読の状態を保存できませんでした", e);
      res.status(500).send("error");
    }
  },
);
