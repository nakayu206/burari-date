import assert from "node:assert/strict";
import { test } from "node:test";

import {
  interpretCustomerInfo,
  isAuthorized,
  isFirebaseUid,
  parseWebhookEvent,
  PREMIUM_ENTITLEMENT_ID,
  shouldApplySync,
} from "./subscription";

const NOW = new Date("2026-10-15T03:00:00Z");
const REQUESTED = NOW.getTime();
const UID = "AbCdEf0123456789AbCdEf012345";

// ---- 認証 ----

test("Authorizationヘッダーが、設定した値と同じなら、通す", () => {
  assert.equal(isAuthorized("secret-value", "secret-value"), true);
});

test("Authorizationヘッダーは、Bearer付きの形も、通す", () => {
  assert.equal(isAuthorized("Bearer secret-value", "secret-value"), true);
});

test("値が違う・ヘッダーがない・設定が空のときは、通さない", () => {
  assert.equal(isAuthorized("wrong", "secret-value"), false);
  assert.equal(isAuthorized("secret-valuX", "secret-value"), false);
  assert.equal(isAuthorized("secret-value ", "secret-value"), false);
  assert.equal(isAuthorized(undefined, "secret-value"), false);
  assert.equal(isAuthorized("", "secret-value"), false);
  // 設定が空のときに、空のヘッダーで通ってしまわない。
  assert.equal(isAuthorized("", ""), false);
  assert.equal(isAuthorized("anything", ""), false);
});

// ---- 通知の読み取り ----

test("FirebaseのUIDとして使えるIDだけを、通す(RevenueCatの匿名IDや、パスを壊す文字は、除く)", () => {
  assert.equal(isFirebaseUid(UID), true);
  assert.equal(isFirebaseUid("$RCAnonymousID:abc123"), false);
  assert.equal(isFirebaseUid("a/b"), false);
  assert.equal(isFirebaseUid("../x"), false);
  assert.equal(isFirebaseUid(""), false);
  assert.equal(isFirebaseUid("a".repeat(129)), false);
  assert.equal(isFirebaseUid(123), false);
  assert.equal(isFirebaseUid(undefined), false);
});

test("通知から、種類と、状態を取り直すUIDを取り出す", () => {
  const event = parseWebhookEvent({
    api_version: "1.0",
    event: { type: "RENEWAL", app_user_id: UID, expiration_at_ms: 1 },
  });
  assert.deepEqual(event, { type: "RENEWAL", uids: [UID] });
});

test("RevenueCatの匿名IDの通知は、取り直す対象がない(空)", () => {
  const event = parseWebhookEvent({
    event: { type: "INITIAL_PURCHASE", app_user_id: "$RCAnonymousID:abc" },
  });
  assert.deepEqual(event, { type: "INITIAL_PURCHASE", uids: [] });
});

test("TRANSFERは、移動元・移動先のUIDも、対象にする(重複は除く)", () => {
  const other = "ZyXwVu9876543210ZyXwVu987654";
  const event = parseWebhookEvent({
    event: {
      type: "TRANSFER",
      app_user_id: UID,
      transferred_from: [UID, "$RCAnonymousID:x"],
      transferred_to: [other],
    },
  });
  assert.deepEqual(event, { type: "TRANSFER", uids: [UID, other] });
});

test("対象のUIDの数には、上限がある", () => {
  const many = Array.from({ length: 20 }, (_, i) => `user${i}`);
  const event = parseWebhookEvent({
    event: { type: "TRANSFER", app_user_id: UID, transferred_to: many },
  });
  assert.equal(event?.uids.length, 5);
});

test("通知の形が不正なら、nullにする", () => {
  assert.equal(parseWebhookEvent(undefined), null);
  assert.equal(parseWebhookEvent(null), null);
  assert.equal(parseWebhookEvent({}), null);
  assert.equal(parseWebhookEvent({ event: {} }), null);
  assert.equal(parseWebhookEvent({ event: { type: 5, app_user_id: UID } }), null);
  assert.equal(parseWebhookEvent("text"), null);
});

test("TESTなど、app_user_idのない通知は、取り直す対象がない(空)", () => {
  assert.deepEqual(parseWebhookEvent({ event: { type: "TEST" } }), {
    type: "TEST",
    uids: [],
  });
});

// ---- 購読の状態の読み取り ----

const infoWith = (entitlements: Record<string, unknown>, requestDateMs?: number) => ({
  request_date_ms: requestDateMs ?? REQUESTED,
  subscriber: { entitlements },
});

test("期限が、これから先なら、購読中", () => {
  const info = interpretCustomerInfo(
    infoWith({ [PREMIUM_ENTITLEMENT_ID]: { expires_date: "2026-11-15T03:00:00Z" } }),
    PREMIUM_ENTITLEMENT_ID,
    NOW,
  );
  assert.deepEqual(info, {
    status: "active",
    expiresAtMs: Date.parse("2026-11-15T03:00:00Z"),
    requestedAtMs: REQUESTED,
  });
});

test("期限を過ぎていたら、購読していない", () => {
  const info = interpretCustomerInfo(
    infoWith({ [PREMIUM_ENTITLEMENT_ID]: { expires_date: "2026-10-01T00:00:00Z" } }),
    PREMIUM_ENTITLEMENT_ID,
    NOW,
  );
  assert.equal(info?.status, "inactive");
  assert.equal(info?.expiresAtMs, Date.parse("2026-10-01T00:00:00Z"));
});

test("期限を過ぎていても、猶予期間が残っていれば、その終わりまで、購読中", () => {
  const info = interpretCustomerInfo(
    infoWith({
      [PREMIUM_ENTITLEMENT_ID]: {
        expires_date: "2026-10-14T00:00:00Z",
        grace_period_expires_date: "2026-10-17T00:00:00Z",
      },
    }),
    PREMIUM_ENTITLEMENT_ID,
    NOW,
  );
  assert.equal(info?.status, "active");
  assert.equal(info?.expiresAtMs, Date.parse("2026-10-17T00:00:00Z"));
});

test("猶予期間も過ぎていたら、購読していない", () => {
  const info = interpretCustomerInfo(
    infoWith({
      [PREMIUM_ENTITLEMENT_ID]: {
        expires_date: "2026-10-10T00:00:00Z",
        grace_period_expires_date: "2026-10-12T00:00:00Z",
      },
    }),
    PREMIUM_ENTITLEMENT_ID,
    NOW,
  );
  assert.equal(info?.status, "inactive");
});

test("期限がnullの権利は、期限のない購読中", () => {
  const info = interpretCustomerInfo(
    infoWith({ [PREMIUM_ENTITLEMENT_ID]: { expires_date: null } }),
    PREMIUM_ENTITLEMENT_ID,
    NOW,
  );
  assert.deepEqual(info, { status: "active", expiresAtMs: null, requestedAtMs: REQUESTED });
});

test("Entitlementがなければ、購読していない", () => {
  const info = interpretCustomerInfo(infoWith({}), PREMIUM_ENTITLEMENT_ID, NOW);
  assert.deepEqual(info, { status: "inactive", expiresAtMs: null, requestedAtMs: REQUESTED });
  // 別のEntitlementがあっても、購読中にはしない。
  const other = interpretCustomerInfo(
    infoWith({ other: { expires_date: "2099-01-01T00:00:00Z" } }),
    PREMIUM_ENTITLEMENT_ID,
    NOW,
  );
  assert.equal(other?.status, "inactive");
});

test("取得の時刻は、応答のrequest_date_msを使う(なければ、いまの時刻)", () => {
  const withMs = interpretCustomerInfo(infoWith({}, 123), PREMIUM_ENTITLEMENT_ID, NOW);
  assert.equal(withMs?.requestedAtMs, 123);
  const without = interpretCustomerInfo(
    { subscriber: { entitlements: {} } },
    PREMIUM_ENTITLEMENT_ID,
    NOW,
  );
  assert.equal(without?.requestedAtMs, NOW.getTime());
});

test("取得の時刻を基準に、期限が切れたかを判断する(古い取得で、切れた期限を購読中にしない)", () => {
  const entitlements = { [PREMIUM_ENTITLEMENT_ID]: { expires_date: "2026-10-15T00:00:00Z" } };
  const before = interpretCustomerInfo(
    infoWith(entitlements, Date.parse("2026-10-14T00:00:00Z")),
    PREMIUM_ENTITLEMENT_ID,
    NOW,
  );
  const after = interpretCustomerInfo(
    infoWith(entitlements, Date.parse("2026-10-16T00:00:00Z")),
    PREMIUM_ENTITLEMENT_ID,
    NOW,
  );
  assert.equal(before?.status, "active");
  assert.equal(after?.status, "inactive");
});

test("応答の形が不正なら、undefinedにする(保存しない)", () => {
  assert.equal(interpretCustomerInfo(undefined, PREMIUM_ENTITLEMENT_ID, NOW), undefined);
  assert.equal(interpretCustomerInfo({}, PREMIUM_ENTITLEMENT_ID, NOW), undefined);
  assert.equal(interpretCustomerInfo({ subscriber: {} }, PREMIUM_ENTITLEMENT_ID, NOW), undefined);
  assert.equal(
    interpretCustomerInfo(
      infoWith({ [PREMIUM_ENTITLEMENT_ID]: { expires_date: "not a date" } }),
      PREMIUM_ENTITLEMENT_ID,
      NOW,
    ),
    undefined,
  );
  assert.equal(
    interpretCustomerInfo(
      infoWith({ [PREMIUM_ENTITLEMENT_ID]: { expires_date: 123 } }),
      PREMIUM_ENTITLEMENT_ID,
      NOW,
    ),
    undefined,
  );
});

// ---- 保存してよいか ----

test("保存済みがなければ、保存する", () => {
  assert.equal(shouldApplySync(undefined, 100), true);
  assert.equal(shouldApplySync(null, 100), true);
});

test("保存済みより、新しい(同じ)時刻の取得なら、保存する", () => {
  assert.equal(shouldApplySync(100, 101), true);
  assert.equal(shouldApplySync(100, 100), true);
});

test("保存済みより、古い時刻の取得では、上書きしない(順番が前後しても、新しい状態が残る)", () => {
  assert.equal(shouldApplySync(100, 99), false);
});
