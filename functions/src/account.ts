import { getFirestore } from "firebase-admin/firestore";

/**
 * 削除済みのアカウントの印(墓標)を置くコレクション。アカウントを削除したあとも、削除前に
 * 始まった処理(取得・購読の通知の保存)が、遅れて終わり、削除したユーザーの記録を、作り直して
 * しまうことがある。保存・確保のトランザクションの中で、この印を確認し、ある場合は、書かない。
 * 印は、ユーザーID・削除した日時・有効期限だけを持つ(個人を特定する情報は、持たない)。
 */
export const DELETED_ACCOUNTS = "deletedAccounts";

/** 墓標を保存する日数(`expiresAt`に、Firestoreの有効期限(TTL)を設定すると、自動で消える)。 */
export const DELETED_ACCOUNT_TTL_DAYS = 30;

/** 削除済みの印のドキュメントの参照 */
export function deletedAccountRef(uid: string) {
  return getFirestore().collection(DELETED_ACCOUNTS).doc(uid);
}

/** 削除済みの印の内容(Firestoreを使わない純粋な関数) */
export function deletedAccountData(now: Date): { deletedAt: Date; expiresAt: Date } {
  return {
    deletedAt: now,
    expiresAt: new Date(now.getTime() + DELETED_ACCOUNT_TTL_DAYS * 24 * 60 * 60 * 1000),
  };
}

/** アカウントの削除を始める前に、削除済みの印を置く。 */
export async function markAccountDeleted(uid: string, now: Date = new Date()): Promise<void> {
  await deletedAccountRef(uid).set(deletedAccountData(now));
}

/** 削除に失敗したとき、印を外す(アカウントは、残っているため、通常どおり、使えるように)。 */
export async function clearAccountDeleted(uid: string): Promise<void> {
  await deletedAccountRef(uid).delete();
}
