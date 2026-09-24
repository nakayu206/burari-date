import { getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

/** 無料で使える累計回数(コスト対策バックストップ、仕様書10章) */
export const LIFETIME_FREE_LIMIT = 10;

function lifetimeUsedOf(data: FirebaseFirestore.DocumentData | undefined): number {
  return data?.lifetimeFreeUsed ?? 0;
}

/**
 * 無料利用の累計上限に達していないか確認する(書き込みは行わない)。
 * 外部API呼び出し前にfail-fastさせ、失敗が確定している呼び出しでの
 * 無駄な課金を防ぐ。上限超過時はHttpsErrorを投げる。
 */
export async function assertUnderFreeLimit(uid: string): Promise<void> {
  const db = getFirestore();
  const snap = await db.collection("users").doc(uid).get();

  if (lifetimeUsedOf(snap.data()) >= LIFETIME_FREE_LIMIT) {
    throw new HttpsError(
      "resource-exhausted",
      "無料利用の上限(10回)に達しました。継続利用にはアカウント登録と課金が必要です。",
    );
  }
}

/**
 * 候補生成に成功した後にのみ呼び出し、累計利用回数を1増やす。
 * 外部API呼び出しが失敗した試行分は消費しない(候補を返せなかったのに
 * 枠だけ失う事故を防ぐため、記録は成功時のみ行う)。
 */
export async function recordUsage(uid: string): Promise<void> {
  const db = getFirestore();
  const ref = db.collection("users").doc(uid);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const used = lifetimeUsedOf(snap.data());

    tx.set(
      ref,
      {
        lifetimeFreeUsed: used + 1,
        updatedAt: new Date(),
      },
      { merge: true },
    );
  });
}
