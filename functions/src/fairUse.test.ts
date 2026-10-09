import assert from "node:assert/strict";
import { test } from "node:test";

import {
  addCategory,
  applyCharge,
  applyRefund,
  addInFlight,
  hasOtherInFlight,
  IN_FLIGHT_TTL_MS,
  isRefundableMonth,
  readHeldCharges,
  removeInFlight,
  takeCharge,
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

// ---- 失敗したときの返却(消費の保持: planRelease(消費したか, 保持, 記録, カテゴリ, 処理中, 成功済み)) ----

test("枠を消費したグルメが失敗しても、観光が成功・取得中なら枠を戻さない", () => {
  const plan = planRelease(true, 1, ["gourmet", "sightseeing"], "gourmet");
  assert.equal(plan.refund, false);
  assert.deepEqual(plan.remaining, ["sightseeing"]);
});

test("グルメが先に失敗したあと観光も失敗したら、そのガチャで消費した枠を戻す", () => {
  const second = planRelease(false, 1, ["sightseeing"], "sightseeing");
  assert.equal(second.refund, true);
  assert.deepEqual(second.remaining, []);
});

test("観光が先に失敗しても、グルメが残っていれば戻さず、グルメの失敗で戻す", () => {
  assert.equal(planRelease(false, 1, ["gourmet", "sightseeing"], "sightseeing").refund, false);
  assert.equal(planRelease(true, 1, ["gourmet"], "gourmet").refund, true);
});

test("1つだけ取得して失敗したときは、消費した枠を戻し、記録も空にする", () => {
  const plan = planRelease(true, 1, ["gourmet"], "gourmet");
  assert.equal(plan.refund, true);
  assert.deepEqual(plan.remaining, []);
});

test("gachaIdなし(記録なし)では、今回数えた分だけを戻す", () => {
  assert.equal(planRelease(true, 1, undefined, "gourmet").refund, true);
  assert.equal(planRelease(false, 0, undefined, "gourmet").refund, false);
});

test("取得に成功済みのカテゴリの取り直しが失敗したら、追加で消費した1回を戻し、記録は残す", () => {
  // 保持2回(最初の消費と、取り直しの追加)。成功済みなので、カテゴリは残り、必要は1回。
  const plan = planRelease(true, 2, ["gourmet", "sightseeing"], "gourmet", false, true);
  assert.equal(plan.refund, true);
  assert.deepEqual(plan.remaining, ["gourmet", "sightseeing"]);
});

test("処理中の取得(A)が残っている間に、取り直し(B)が失敗しても、記録は残し、Bの分だけ戻す", () => {
  const plan = planRelease(true, 2, ["gourmet"], "gourmet", true, false);
  assert.equal(plan.refund, true);
  assert.deepEqual(plan.remaining, ["gourmet"]);
});

test("取り直し(B)が成功したあとに、最初の取得(A)が失敗しても、成功の記録は残し、Aの分だけ戻す", () => {
  const plan = planRelease(true, 2, ["gourmet"], "gourmet", false, true);
  assert.equal(plan.refund, true);
  assert.deepEqual(plan.remaining, ["gourmet"]);
});

test("同じカテゴリの取得が重なって、両方失敗したら、消費は0になり、記録も消える", () => {
  // A→Bの順に失敗。Aの時点では、Bが処理中なので、記録を残し、Aの分を戻す(保持2→1)。
  const a = planRelease(true, 2, ["gourmet"], "gourmet", true, false);
  assert.equal(a.refund, true);
  // Bの失敗: 成功済みでも、処理中でもないので、記録を消し、残りの1回も戻す。
  const b = planRelease(true, 1, ["gourmet"], "gourmet", false, false);
  assert.equal(b.refund, true);
  assert.deepEqual(b.remaining, []);
});

test("グルメA・Bが重複→観光が成功→A・Bが失敗: どの順番でも、観光の分の1回が残る", () => {
  const recorded = ["gourmet", "sightseeing"];
  // A→B の順: Aの時点でBは処理中(記録を残す)。保持2→1。Bは、観光が残るので、戻さない。
  const a1 = planRelease(true, 2, recorded, "gourmet", true, false);
  assert.equal(a1.refund, true);
  const b1 = planRelease(true, 1, recorded, "gourmet", false, false);
  assert.equal(b1.refund, false, "観光が使う1回は、残す");
  assert.deepEqual(b1.remaining, ["sightseeing"]);
  // B→A の順: Bの時点でAは処理中(記録を残す)。保持2→1。Aは、観光が残るので、戻さない。
  const b2 = planRelease(true, 2, recorded, "gourmet", true, false);
  assert.equal(b2.refund, true);
  const a2 = planRelease(true, 1, recorded, "gourmet", false, false);
  assert.equal(a2.refund, false);
});

test("グルメA開始→B開始→A失敗→観光成功→B失敗: 観光の分の1回が残る(観光の開始が遅い場合)", () => {
  // Aの失敗の時点では、観光の記録は、まだない。Bが処理中なので、記録を残し、Aの分を戻す(2→1)。
  const a = planRelease(true, 2, ["gourmet"], "gourmet", true, false);
  assert.equal(a.refund, true);
  // 観光が成功(消費なし。記録にグルメがあるため、別カテゴリは数えない)。Bが失敗。
  const b = planRelease(true, 1, ["gourmet", "sightseeing"], "gourmet", false, false);
  assert.equal(b.refund, false, "成功した観光のために、1回残す");
  assert.deepEqual(b.remaining, ["sightseeing"]);
});

test("保持している消費の一覧: 新しい記録は、そのまま読み、古い記録は、1回分に直す", () => {
  const list = [
    { source: "free" as const, monthKey: "202610" },
    { source: "monthly" as const, monthKey: "202610" },
  ];
  assert.deepEqual(readHeldCharges({ charges: list }), list);
  // 古い記録(chargesなし): 出どころ・月の記録があれば、それを使う。
  assert.deepEqual(
    readHeldCharges({ charged: true, chargedSource: "monthly", chargedMonthKey: "202609" }),
    [{ source: "monthly", monthKey: "202609" }],
  );
  // 出どころの記録がない古い記録は、無料枠。
  assert.deepEqual(readHeldCharges({ charged: true }), [{ source: "free" }]);
  assert.deepEqual(readHeldCharges({ charged: false }), []);
  assert.deepEqual(readHeldCharges(undefined), []);
});

test("消費を戻すときは、今回の呼び出しが消費した出どころと月のものを優先して取り出す", () => {
  const free = { source: "free" as const, monthKey: "202610" };
  const monthly = { source: "monthly" as const, monthKey: "202610" };
  const lastMonth = { source: "monthly" as const, monthKey: "202609" };

  // 月額枠(今月)の呼び出しが失敗: 無料枠ではなく、月額枠(今月)を戻す。
  const a = takeCharge([free, monthly], monthly);
  assert.deepEqual(a.entry, monthly);
  assert.deepEqual(a.rest, [free]);

  // 先月に消費した月額枠: 月も、合わせる。
  const b = takeCharge([monthly, lastMonth], lastMonth);
  assert.deepEqual(b.entry, lastMonth);

  // 今回消費していない呼び出し(別カテゴリ)は、いちばん古いものを戻す。
  const c = takeCharge([free, monthly]);
  assert.deepEqual(c.entry, free);

  // 一致するものがなければ、いちばん古いもの。空なら、何もない。
  assert.deepEqual(takeCharge([free], monthly).entry, free);
  assert.deepEqual(takeCharge([]), { entry: undefined, rest: [] });
});

test("最初の消費(無料枠)を戻したあと、取り直し(月額枠)の分が残っても、別カテゴリの失敗は、月額枠に戻る", () => {
  // 保持: A=無料枠、B=月額枠。Aが失敗して、Aの分(無料枠)が戻る。残りは、Bの月額枠。
  const held = [
    { source: "free" as const, monthKey: "202610" },
    { source: "monthly" as const, monthKey: "202610" },
  ];
  const afterA = takeCharge(held, { source: "free", monthKey: "202610" });
  assert.deepEqual(afterA.entry?.source, "free");
  // 観光(消費していない呼び出し)が失敗して、ガチャの消費を戻すとき: 残っているのは、月額枠。
  const forSightseeing = takeCharge(afterA.rest);
  assert.equal(forSightseeing.entry?.source, "monthly", "無料枠ではなく、月額枠に戻る");
});

test("処理中の一覧: 追加・取り外し・ほかの処理中の判定", () => {
  const t0 = 1_000_000;
  const a = addInFlight(undefined, "A", t0);
  const ab = addInFlight(a, "B", t0 + 1000);
  assert.deepEqual(ab.map((e) => e.id), ["A", "B"]);

  assert.equal(hasOtherInFlight(ab, "B", t0 + 2000), true, "Aが処理中");
  assert.equal(hasOtherInFlight(removeInFlight(ab, "A"), "B", t0 + 2000), false);
  assert.equal(hasOtherInFlight(undefined, "B", t0), false);

  assert.equal(addInFlight(ab, "A", t0 + 3000).filter((e) => e.id === "A").length, 1);
});

test("処理中の一覧: 期限を過ぎた記録は、無視する(クラッシュで、残り続けないように)", () => {
  const t0 = 1_000_000;
  const list = addInFlight(undefined, "A", t0);
  assert.equal(hasOtherInFlight(list, "B", t0 + IN_FLIGHT_TTL_MS - 1), true);
  assert.equal(hasOtherInFlight(list, "B", t0 + IN_FLIGHT_TTL_MS), false);
  const next = addInFlight(list, "C", t0 + IN_FLIGHT_TTL_MS + 1);
  assert.deepEqual(next.map((e) => e.id), ["C"]);
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
