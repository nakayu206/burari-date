import assert from "node:assert/strict";
import { test } from "node:test";

import { deleteRevenueCatSubscriber, revenueCatSubscriberUrl } from "./deleteAccount";

test("RevenueCatの削除のURLは、アプリユーザーID(UID)を、エンコードして入れる", () => {
  assert.equal(
    revenueCatSubscriberUrl("abc123"),
    "https://api.revenuecat.com/v1/subscribers/abc123",
  );
  // 想定外の文字(区切りなど)が入っても、別のパスにならない。
  assert.equal(
    revenueCatSubscriberUrl("a/b?c"),
    "https://api.revenuecat.com/v1/subscribers/a%2Fb%3Fc",
  );
});

test("RevenueCatの削除: DELETEで、Bearerの認証を付けて呼ぶ", async () => {
  const original = globalThis.fetch;
  let called: { url: string; init?: RequestInit } | undefined;
  globalThis.fetch = (async (url: string | URL | Request, init?: RequestInit) => {
    called = { url: String(url), init };
    return new Response("{}", { status: 200 });
  }) as typeof fetch;
  try {
    await deleteRevenueCatSubscriber("sk_test", "uid1");
  } finally {
    globalThis.fetch = original;
  }
  assert.equal(called?.url, "https://api.revenuecat.com/v1/subscribers/uid1");
  assert.equal(called?.init?.method, "DELETE");
  assert.deepEqual(called?.init?.headers, { Authorization: "Bearer sk_test" });
});

test("RevenueCatの削除: 存在しない(404)ときは、削除済みとして成功にする", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = (async () => new Response("{}", { status: 404 })) as typeof fetch;
  try {
    await deleteRevenueCatSubscriber("sk_test", "uid1");
  } finally {
    globalThis.fetch = original;
  }
});

test("RevenueCatの削除: ほかのエラーは、失敗として投げる", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = (async () => new Response("{}", { status: 500 })) as typeof fetch;
  try {
    await assert.rejects(() => deleteRevenueCatSubscriber("sk_test", "uid1"), /500/);
  } finally {
    globalThis.fetch = original;
  }
});

test("削除済みの印は、ユーザーIDのドキュメントで、日時と有効期限だけを持つ", async () => {
  const { deletedAccountData, DELETED_ACCOUNT_TTL_DAYS } = await import("./account");
  const now = new Date("2026-10-09T05:00:00Z");
  const data = deletedAccountData(now);
  assert.deepEqual(Object.keys(data).sort(), ["deletedAt", "expiresAt"]);
  assert.equal(data.deletedAt.getTime(), now.getTime());
  assert.equal(
    data.expiresAt.getTime() - now.getTime(),
    DELETED_ACCOUNT_TTL_DAYS * 24 * 60 * 60 * 1000,
  );
});
