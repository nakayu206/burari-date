import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { clearAccountDeleted, markAccountDeleted } from "./account";
import { isFirebaseUid, revenueCatApiKey } from "./subscription";

/**
 * RevenueCatの、購読者の情報を削除するURL(Firestoreを使わない純粋な関数)。
 * アプリユーザーIDには、FirebaseのUIDを使っている。
 */
export function revenueCatSubscriberUrl(uid: string): string {
  return `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`;
}

/**
 * RevenueCatの、購読者の情報を削除する。存在しない(404)ときは、削除済みとして扱う。
 * 失敗しても、アカウントの削除は続けるため、呼び出し側で、例外を握りつぶす。
 */
export async function deleteRevenueCatSubscriber(
  apiKey: string,
  uid: string,
): Promise<void> {
  const res = await fetch(revenueCatSubscriberUrl(uid), {
    method: "DELETE",
    headers: { Authorization: `Bearer ${apiKey}` },
  });
  if (!res.ok && res.status !== 404) {
    throw new Error(`RevenueCatの削除に失敗しました: ${res.status}`);
  }
}

/**
 * ログイン中のユーザー自身のアカウントを削除する(Issue #190)。Google Playの規則
 * (アカウントを作れるアプリは、アプリ内で、アカウントの削除を依頼できること)に対応する。
 *
 * 1. RevenueCatの購読者の情報を削除する(失敗したら、何も削除せず、エラーを返す。
 *    削除したあとでは、元のアカウントから、やり直せなくなるため。存在しない(404)ときは成功)。
 * 2. Firestoreの`users/{uid}`と、その下の履歴・お気に入り・利用の記録などを、すべて削除する。
 * 3. Firebase認証のユーザーを削除する。
 * 4. 削除の途中に割り込んだ書き込みに備えて、Firestoreの削除を、もう一度行う(失敗しても続ける)。
 *
 * 削除の前に、削除済みの印(`deletedAccounts/{uid}`)を置く。削除前に始まった処理が、遅れて
 * 終わっても、保存・確保のトランザクションの中で、この印を確認し、記録を作り直さない。
 *
 * 2が失敗したときは、3に進まない(認証のユーザーを残し、やり直せるようにする)。
 * 端末ごとの無料枠の記録(`devices/{id}`)は、個人に紐づかないため、削除しない
 * (アカウントを削除して作り直すことで、無料枠が戻らないようにするため)。
 * 購読は、Google Playで、別に解約する必要がある。
 */
export const deleteAccount = onCall(
  {
    secrets: [revenueCatApiKey],
    region: "us-central1",
    timeoutSeconds: 60,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "サインインが必要です");
    }
    const uid = request.auth.uid;
    if (!isFirebaseUid(uid)) {
      throw new HttpsError("invalid-argument", "ユーザーを確認できませんでした");
    }

    try {
      await deleteRevenueCatSubscriber(revenueCatApiKey.value(), uid);
    } catch (e) {
      // 購読者の情報が残らないよう、ここで止める。Firestore・認証のユーザーは残るので、
      // 利用者は、あとから、やり直せる。
      console.error("RevenueCatの購読者の情報を削除できませんでした", e);
      throw new HttpsError(
        "internal",
        "アカウントを削除できませんでした。しばらくしてから、もう一度お試しください。",
      );
    }

    // 削除の前に、削除済みの印を置く。削除前に始まった処理が、遅れて終わっても、
    // 保存・確保のトランザクションの中で、この印を見て、書かない(記録を作り直さない)。
    await markAccountDeleted(uid);

    try {
      const db = getFirestore();
      await db.recursiveDelete(db.collection("users").doc(uid));
    } catch (e) {
      console.error("Firestoreのデータを削除できませんでした", e);
      // アカウントは残っているので、印は外す(通常どおり、使えるように)。
      await clearAccountDeleted(uid).catch(() => undefined);
      throw new HttpsError(
        "internal",
        "アカウントを削除できませんでした。しばらくしてから、もう一度お試しください。",
      );
    }

    try {
      await getAuth().deleteUser(uid);
    } catch (e) {
      // すでに削除済みのときは、成功として扱う。
      if ((e as { code?: string }).code !== "auth/user-not-found") {
        console.error("認証のユーザーを削除できませんでした", e);
        throw new HttpsError(
          "internal",
          "アカウントを削除できませんでした。しばらくしてから、もう一度お試しください。",
        );
      }
    }

    // 削除の途中に、割り込んだ書き込み(遅れて終わった取得・購読の通知)で、記録が、
    // 作り直されていた場合に備えて、もう一度、削除する。失敗しても、削除自体は、済んでいる。
    try {
      const db = getFirestore();
      await db.recursiveDelete(db.collection("users").doc(uid));
    } catch (e) {
      console.warn("Firestoreの再削除に失敗しました", e);
    }

    return { ok: true };
  },
);
