import assert from "node:assert/strict";
import { test } from "node:test";

import {
  addCategory,
  applyCharge,
  applyRefund,
  isRefundableMonth,
  isSubscriptionActive,
  isValidDeviceId,
  SUBSCRIPTION_GRACE_MS,
  isValidGachaId,
  LIFETIME_FREE_LIMIT,
  MONTHLY_FAIR_USE_LIMIT,
  monthKeyOf,
  planCharge,
  planRelease,
  planUsage,
  readUserUsage,
  removeCategory,
  type UserUsage,
} from "./fairUse";

const NOW = new Date("2026-10-15T03:00:00Z");

/** 購読していない(無料枠だけの)ユーザーの利用状況 */
const free = (used: number): UserUsage => ({
  lifetimeFreeUsed: used,
  isSubscriber: false,
  monthlyUsed: 0,
});

/** 購読中のユーザーの利用状況 */
const subscriber = (monthlyUsed: number): UserUsage => ({
  lifetimeFreeUsed: 0,
  isSubscriber: true,
  monthlyUsed,
});

const limitTypeOf = (e: unknown) =>
  (e as { details?: { limitType?: string } }).details?.limitType;

test("無料上限は10回である", () => {
  assert.equal(LIFETIME_FREE_LIMIT, 10);
});

test("購読中の月の上限は30回である", () => {
  assert.equal(MONTHLY_FAIR_USE_LIMIT, 30);
});

// ---- 無料枠(購読していないユーザー) ----

test("新しいガチャの最初の取得は、1回と数える(無料枠)", () => {
  assert.deepEqual(planUsage(free(0), undefined, "gourmet"), { source: "free" });
  assert.deepEqual(planUsage(free(3), [], "sightseeing"), { source: "free" });
});

test("同じガチャの、もう一方のカテゴリは数えない(グルメ・観光で1回)", () => {
  assert.deepEqual(planUsage(free(3), ["gourmet"], "sightseeing"), {});
  assert.deepEqual(planUsage(free(3), ["sightseeing"], "gourmet"), {});
});

test("同じガチャの同じカテゴリを取り直すと、また1回と数える(gachaIdの使い回し対策)", () => {
  assert.deepEqual(planUsage(free(3), ["gourmet"], "gourmet"), { source: "free" });
});

test("上限に達していると、新しいガチャの取得は拒否する", () => {
  assert.throws(
    () => planUsage(free(LIFETIME_FREE_LIMIT), undefined, "gourmet"),
    (e: unknown) =>
      (e as { code?: string }).code === "resource-exhausted" &&
      String((e as Error).message).includes("無料利用の上限(10回)"),
  );
});

test("上限のエラーは、種類(無料枠)を details に付けて返す", () => {
  assert.throws(
    () => planUsage(free(LIFETIME_FREE_LIMIT), undefined, "gourmet"),
    (e: unknown) => limitTypeOf(e) === "free_tier",
  );
});

test("上限に達していても、数え済みのガチャの、もう一方のカテゴリは見られる", () => {
  assert.deepEqual(
    planUsage(free(LIFETIME_FREE_LIMIT), ["gourmet"], "sightseeing"),
    {},
  );
});

test("上限に達していると、同じカテゴリの取り直しは拒否する", () => {
  assert.throws(() => planUsage(free(LIFETIME_FREE_LIMIT), ["gourmet"], "gourmet"));
});

test("gachaIdがない古いアプリは、呼び出しごとに数える", () => {
  assert.deepEqual(planUsage(free(0), undefined, "gourmet"), { source: "free" });
  assert.deepEqual(planUsage(free(0), undefined, "sightseeing"), { source: "free" });
});

// ---- 購読中(月のフェアユース上限) ----

test("購読中は、無料枠ではなく、月の回数から数える", () => {
  assert.deepEqual(planCharge(subscriber(0)), { source: "monthly" });
  assert.deepEqual(planCharge(subscriber(MONTHLY_FAIR_USE_LIMIT - 1)), {
    source: "monthly",
  });
});

test("購読中は、無料枠を使い切っていても、月の上限の範囲で、使える", () => {
  const usage: UserUsage = { ...subscriber(0), lifetimeFreeUsed: LIFETIME_FREE_LIMIT };
  assert.deepEqual(planCharge(usage), { source: "monthly" });
});

test("月の上限に達したら、月の上限として拒否する(追加購入は、ない)", () => {
  assert.throws(
    () => planCharge(subscriber(MONTHLY_FAIR_USE_LIMIT)),
    (e: unknown) =>
      (e as { code?: string }).code === "resource-exhausted" &&
      limitTypeOf(e) === "monthly" &&
      String((e as Error).message).includes("今月の利用上限(30回)") &&
      String((e as Error).message).includes("来月") &&
      !String((e as Error).message).includes("追加"),
  );
});

test("月の上限に達していても、数え済みのガチャの、もう一方のカテゴリは見られる", () => {
  assert.deepEqual(
    planUsage(subscriber(MONTHLY_FAIR_USE_LIMIT), ["gourmet"], "sightseeing"),
    {},
  );
});

test("購読が切れたら、無料枠に戻り、使い切っていれば、無料枠の上限で拒否する(復活しない)", () => {
  const lapsed: UserUsage = { ...free(LIFETIME_FREE_LIMIT), monthlyUsed: 5 };
  assert.throws(
    () => planCharge(lapsed),
    (e: unknown) => limitTypeOf(e) === "free_tier",
  );
});

// ---- 利用状況の読み取り ----

test("月の区切りは、日本時間(UTCの15時に月が変わる)", () => {
  assert.equal(monthKeyOf(new Date("2026-10-31T14:59:59Z")), "202610");
  assert.equal(monthKeyOf(new Date("2026-10-31T15:00:00Z")), "202611");
  assert.equal(monthKeyOf(new Date("2026-12-31T15:00:00Z")), "202701");
});

test("購読中の判断: activeで、期限が過ぎていなければ、購読中", () => {
  const future = new Date(NOW.getTime() + 86400000);
  assert.equal(isSubscriptionActive({ subscriptionStatus: "active", subscriptionExpiresAt: future }, NOW), true);
  assert.equal(isSubscriptionActive({ subscriptionStatus: "inactive", subscriptionExpiresAt: future }, NOW), false);
  assert.equal(isSubscriptionActive({}, NOW), false);
  assert.equal(isSubscriptionActive(undefined, NOW), false);
});

test("購読中の判断: 期限を過ぎても、猶予(6時間)の間は、更新の通知を待って、購読中", () => {
  const justPast = new Date(NOW.getTime() - 90 * 1000);
  const insideGrace = new Date(NOW.getTime() - SUBSCRIPTION_GRACE_MS + 1000);
  const outsideGrace = new Date(NOW.getTime() - SUBSCRIPTION_GRACE_MS - 1000);
  assert.equal(isSubscriptionActive({ subscriptionStatus: "active", subscriptionExpiresAt: justPast }, NOW), true);
  assert.equal(isSubscriptionActive({ subscriptionStatus: "active", subscriptionExpiresAt: insideGrace }, NOW), true);
  assert.equal(isSubscriptionActive({ subscriptionStatus: "active", subscriptionExpiresAt: outsideGrace }, NOW), false);
});

test("購読中の判断: 切れた(inactive)と通知されたら、猶予の間でも、購読中ではない", () => {
  const justPast = new Date(NOW.getTime() - 90 * 1000);
  assert.equal(isSubscriptionActive({ subscriptionStatus: "inactive", subscriptionExpiresAt: justPast }, NOW), false);
});

test("購読中の判断: 期限がなければ、状態だけで判断する", () => {
  assert.equal(isSubscriptionActive({ subscriptionStatus: "active" }, NOW), true);
});

test("購読中の判断: FirestoreのTimestamp(toMillis)・ミリ秒も、期限として読める", () => {
  const later = NOW.getTime() + 1000;
  assert.equal(
    isSubscriptionActive(
      { subscriptionStatus: "active", subscriptionExpiresAt: { toMillis: () => later } },
      NOW,
    ),
    true,
  );
  assert.equal(
    isSubscriptionActive({ subscriptionStatus: "active", subscriptionExpiresAt: later }, NOW),
    true,
  );
  assert.equal(
    isSubscriptionActive(
      { subscriptionStatus: "active", subscriptionExpiresAt: NOW.getTime() - SUBSCRIPTION_GRACE_MS - 1 },
      NOW,
    ),
    false,
  );
});

test("利用状況の読み取り: 今月の回数は、月が変わっていれば0になる", () => {
  const data = {
    lifetimeFreeUsed: 4,
    monthlyGachaCount: 17,
    monthlyKey: "202609",
  };
  const usage = readUserUsage(data, NOW);
  assert.equal(usage.monthlyUsed, 0, "先月の回数は、持ち越さない");
  assert.equal(usage.lifetimeFreeUsed, 4, "無料枠は、月ごとに回復しない");

  assert.equal(readUserUsage({ ...data, monthlyKey: monthKeyOf(NOW) }, NOW).monthlyUsed, 17);
});

test("利用状況の読み取り: 値がない・おかしいときは0", () => {
  assert.deepEqual(readUserUsage(undefined, NOW), {
    lifetimeFreeUsed: 0,
    isSubscriber: false,
    monthlyUsed: 0,
  });
  const usage = readUserUsage(
    { lifetimeFreeUsed: -3, monthlyGachaCount: "x", monthlyKey: monthKeyOf(NOW) },
    NOW,
  );
  assert.equal(usage.lifetimeFreeUsed, 0);
  assert.equal(usage.monthlyUsed, 0);
});

// ---- 回数の加算・払い戻し ----

test("消費: 出どころごとの回数を、1つ進める", () => {
  assert.deepEqual(applyCharge("free", free(2), NOW), { lifetimeFreeUsed: 3 });
  assert.deepEqual(applyCharge("monthly", subscriber(5), NOW), {
    monthlyGachaCount: 6,
    monthlyKey: "202610",
  });
});

test("消費: 月が変わった最初の1回は、今月の分として、1から数える", () => {
  const usage = readUserUsage(
    { subscriptionStatus: "active", monthlyGachaCount: 29, monthlyKey: "202609" },
    NOW,
  );
  assert.deepEqual(applyCharge("monthly", usage, NOW), {
    monthlyGachaCount: 1,
    monthlyKey: "202610",
  });
});

test("払い戻し: 消費したのと同じ種類の回数を、1つ戻す", () => {
  assert.deepEqual(applyRefund("free", free(3), NOW), { lifetimeFreeUsed: 2 });
  assert.deepEqual(applyRefund("monthly", subscriber(6), NOW), {
    monthlyGachaCount: 5,
    monthlyKey: "202610",
  });
});

test("払い戻し: 0より下にはしない", () => {
  assert.deepEqual(applyRefund("free", free(0), NOW), { lifetimeFreeUsed: 0 });
});

test("払い戻し: 月をまたいだあとの失敗では、新しい月の回数は戻さない(何も書かない)", () => {
  // 先月に消費した分の失敗。いまの月の回数は0なので、戻すものがない。
  const usage = readUserUsage(
    { subscriptionStatus: "active", monthlyGachaCount: 12, monthlyKey: "202609" },
    NOW,
  );
  assert.deepEqual(applyRefund("monthly", usage, NOW), {});
});

test("消費して、同じ出どころで戻すと、元の回数に戻る", () => {
  const before = subscriber(7);
  const charged = applyCharge("monthly", before, NOW);
  const after: UserUsage = { ...before, monthlyUsed: charged.monthlyGachaCount as number };
  assert.deepEqual(applyRefund("monthly", after, NOW).monthlyGachaCount, 7);
});

// ---- ガチャの記録 ----

test("ガチャの記録にカテゴリを加える・外す", () => {
  assert.deepEqual(addCategory(undefined, "gourmet"), ["gourmet"]);
  assert.deepEqual(addCategory(["gourmet"], "gourmet"), ["gourmet"]);
  assert.deepEqual(addCategory(["gourmet"], "sightseeing"), [
    "gourmet",
    "sightseeing",
  ]);
  assert.deepEqual(removeCategory(["gourmet", "sightseeing"], "gourmet"), [
    "sightseeing",
  ]);
  assert.deepEqual(removeCategory(["gourmet"], "gourmet"), []);
  assert.deepEqual(removeCategory(undefined, "gourmet"), []);
});

test("取得に失敗して記録から外したカテゴリは、取り直しで二重に数えない", () => {
  // グルメ(数える)→観光(数えない)。観光が失敗すると観光を外す。
  let recorded = addCategory(addCategory(undefined, "gourmet"), "sightseeing");
  recorded = removeCategory(recorded, "sightseeing");
  // 観光の取り直しは、数え済みガチャの別カテゴリとして、数えない。
  assert.deepEqual(planUsage(free(1), recorded, "sightseeing"), {});
});

test("枠を消費したグルメが失敗しても、観光が成功・取得中なら枠を戻さない", () => {
  // グルメ(数える)と観光(数えない)を並行して取得し、グルメだけ失敗した。
  const plan = planRelease(true, true, ["gourmet", "sightseeing"], "gourmet");
  assert.equal(plan.refund, false);
  assert.deepEqual(plan.remaining, ["sightseeing"]);
});

test("グルメが先に失敗したあと観光も失敗したら、そのガチャで消費した枠を戻す", () => {
  // 1つ目の失敗では戻さず、記録に残った観光が失敗して空になったときに戻す。
  const second = planRelease(false, true, ["sightseeing"], "sightseeing");
  assert.equal(second.refund, true);
  assert.deepEqual(second.remaining, []);
});

test("観光が先に失敗しても、グルメが残っていれば戻さず、グルメの失敗で戻す", () => {
  assert.equal(planRelease(false, true, ["gourmet", "sightseeing"], "sightseeing").refund, false);
  assert.equal(planRelease(true, true, ["gourmet"], "gourmet").refund, true);
});

test("1つだけ取得して失敗したときは、消費した枠を戻す", () => {
  assert.equal(planRelease(true, true, ["gourmet"], "gourmet").refund, true);
});

test("gachaIdなし(記録なし)では、今回数えた分だけを戻す", () => {
  assert.equal(planRelease(true, undefined, undefined, "gourmet").refund, true);
  assert.equal(planRelease(false, undefined, undefined, "gourmet").refund, false);
});

test("取得済みのカテゴリの取り直しが失敗したら、追加で消費した1回を戻し、カテゴリの記録は残す", () => {
  // グルメ・観光を取得済みで、グルメを取り直して(追加で1回消費)失敗した。
  const plan = planRelease(true, true, ["gourmet", "sightseeing"], "gourmet", true);
  assert.equal(plan.refund, true);
  assert.deepEqual(plan.remaining, ["gourmet", "sightseeing"], "取得済みのカテゴリは、消さない");
});

test("取り直しの失敗で戻すのは、追加の1回だけ(ガチャの最初の消費は、戻さない)", () => {
  // 取り直しが失敗しても、記録は残るので、そのあとで、もう一方の取り直しが失敗しても、
  // 最初の消費は、全カテゴリが失敗するまで、戻らない。
  const first = planRelease(true, true, ["gourmet"], "gourmet", true);
  assert.equal(first.refund, true);
  assert.deepEqual(first.remaining, ["gourmet"]);
});

test("ガチャの最初の消費(取り直しではない)は、これまでどおり", () => {
  assert.equal(planRelease(true, true, ["gourmet", "sightseeing"], "gourmet", false).refund, false);
  assert.equal(planRelease(true, true, ["gourmet"], "gourmet", false).refund, true);
});

test("消費していない呼び出しは、取り直し扱いにしない", () => {
  // 別カテゴリで、消費しなかった呼び出し(isRefetchはfalse)。
  assert.equal(planRelease(false, true, ["gourmet", "sightseeing"], "sightseeing", false).refund, false);
});

test("月の回数は、消費した月と、いまの月の回数の月が同じときだけ、戻す(月またぎ)", () => {
  // 先月(202609)に消費して、今月(202610)に別のガチャが成功した後で失敗した。
  assert.equal(isRefundableMonth("monthly", "202610", "202609"), false);
  assert.equal(isRefundableMonth("monthly", "202609", "202609"), true);
});

test("消費した月の記録がない(古い記録)ときは、戻す。無料枠は、月に関係なく、戻す", () => {
  assert.equal(isRefundableMonth("monthly", "202610", undefined), true);
  assert.equal(isRefundableMonth("free", "202610", "202609"), true);
});

test("gachaIdの形式を検証する(英数字・_・-のみ、64文字まで)", () => {
  assert.equal(isValidGachaId("1727600000000000"), true);
  assert.equal(isValidGachaId("abc_DEF-123"), true);
  assert.equal(isValidGachaId(""), false);
  assert.equal(isValidGachaId("a/b"), false);
  assert.equal(isValidGachaId("a".repeat(65)), false);
  assert.equal(isValidGachaId(123), false);
  assert.equal(isValidGachaId(undefined), false);
});

// ---- 端末ごとの無料枠 ----

test("無料枠の使用回数は、ユーザーと端末の、多いほうにする(ログアウトで新しいゲストになっても戻らない)", () => {
  // 新しいゲスト(0回)でも、同じ端末で、すでに10回使っていれば、使用済み。
  assert.equal(readUserUsage({}, NOW, { lifetimeFreeUsed: 10 }).lifetimeFreeUsed, 10);
  // 端末の記録が少なくても、ユーザーの記録が多ければ、ユーザーの記録(別の端末で、使った分)。
  assert.equal(readUserUsage({ lifetimeFreeUsed: 7 }, NOW, { lifetimeFreeUsed: 2 }).lifetimeFreeUsed, 7);
  // 端末の記録がなければ、ユーザーだけで数える(古いアプリ)。
  assert.equal(readUserUsage({ lifetimeFreeUsed: 4 }, NOW).lifetimeFreeUsed, 4);
});

test("端末の記録で、無料枠を使い切っていれば、新しいゲストでも、拒否される", () => {
  const usage = readUserUsage({}, NOW, { lifetimeFreeUsed: LIFETIME_FREE_LIMIT });
  assert.throws(() => planCharge(usage), { code: "resource-exhausted" });
});

test("端末の記録で、無料枠を使い切っていても、購読中なら、月の回数を使える", () => {
  const usage = readUserUsage(
    { subscriptionStatus: "active" },
    NOW,
    { lifetimeFreeUsed: LIFETIME_FREE_LIMIT },
  );
  assert.deepEqual(planCharge(usage), { source: "monthly" });
});

test("deviceIdの形式: 16〜64文字の英数字・ハイフン・アンダースコア", () => {
  assert.equal(isValidDeviceId("0123456789abcdef"), true);
  assert.equal(isValidDeviceId("a1b2c3d4-e5f6-7890-abcd-ef1234567890"), true);
  assert.equal(isValidDeviceId("short"), false);
  assert.equal(isValidDeviceId("a".repeat(65)), false);
  assert.equal(isValidDeviceId("../../users/other-user-id"), false);
  assert.equal(isValidDeviceId(undefined), false);
  assert.equal(isValidDeviceId(123), false);
});
