import { getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

/** 月次フェアユース上限(Claude API等のコスト対策バックストップ、仕様書10章) */
export const MONTHLY_LIMIT = 30;

export function currentMonthKey(date: Date = new Date()): string {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}`;
}

/**
 * 月次フェアユース上限をチェックし、上限内であれば利用回数を1増やす。
 * 上限超過時はHttpsErrorを投げ、呼び出し元(getCandidates)の処理を止める。
 */
export async function checkAndRecordUsage(uid: string): Promise<void> {
  const db = getFirestore();
  const ref = db.collection("users").doc(uid);
  const month = currentMonthKey();

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data();
    const sameMonth = data?.monthlyResetKey === month;
    const monthlyCount = sameMonth ? (data?.monthlyGachaCount ?? 0) : 0;

    if (monthlyCount >= MONTHLY_LIMIT) {
      throw new HttpsError(
        "resource-exhausted",
        "今月の利用上限に達しました。来月またご利用ください",
      );
    }

    tx.set(
      ref,
      {
        monthlyGachaCount: monthlyCount + 1,
        monthlyResetKey: month,
        lifetimeFreeUsed: (data?.lifetimeFreeUsed ?? 0) + 1,
        updatedAt: new Date(),
      },
      { merge: true },
    );
  });
}
