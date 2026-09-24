import { getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

/** 無料で使える累計回数(コスト対策バックストップ、仕様書10章) */
export const LIFETIME_FREE_LIMIT = 10;

function lifetimeUsedOf(data: FirebaseFirestore.DocumentData | undefined): number {
  return data?.lifetimeFreeUsed ?? 0;
}

/**
 * 無料利用の枠を1つ予約する(チェックと加算を1トランザクションで行い、
 * 同時リクエストによる上限の突破を防ぐ)。外部API呼び出しの前に呼ぶこと。
 * 上限超過時はHttpsErrorを投げ、加算は行わない。
 */
export async function reserveUsage(uid: string): Promise<void> {
  const db = getFirestore();
  const ref = db.collection("users").doc(uid);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const used = lifetimeUsedOf(snap.data());

    if (used >= LIFETIME_FREE_LIMIT) {
      throw new HttpsError(
        "resource-exhausted",
        "無料利用の上限(10回)に達しました。継続利用にはアカウント登録と課金が必要です。",
      );
    }

    tx.set(
      ref,
      { lifetimeFreeUsed: used + 1, updatedAt: new Date() },
      { merge: true },
    );
  });
}

/**
 * 外部API呼び出しが失敗した場合に、reserveUsageで確保した枠を1つ戻す。
 * 失敗した試行分の回数を消費しないようにするため。
 */
export async function releaseUsage(uid: string): Promise<void> {
  const db = getFirestore();
  const ref = db.collection("users").doc(uid);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const used = lifetimeUsedOf(snap.data());

    tx.set(
      ref,
      { lifetimeFreeUsed: Math.max(0, used - 1), updatedAt: new Date() },
      { merge: true },
    );
  });
}
