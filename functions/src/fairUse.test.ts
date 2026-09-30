import assert from "node:assert/strict";
import { test } from "node:test";

import {
  addCategory,
  isValidGachaId,
  LIFETIME_FREE_LIMIT,
  planReservation,
  removeCategory,
} from "./fairUse";

test("無料上限は10回である", () => {
  assert.equal(LIFETIME_FREE_LIMIT, 10);
});

test("新しいガチャの最初の取得は、1回と数える", () => {
  assert.deepEqual(planReservation(0, undefined, "gourmet"), { charge: true });
  assert.deepEqual(planReservation(3, [], "sightseeing"), { charge: true });
});

test("同じガチャの、もう一方のカテゴリは数えない(グルメ・観光で1回)", () => {
  assert.deepEqual(planReservation(3, ["gourmet"], "sightseeing"), {
    charge: false,
  });
  assert.deepEqual(planReservation(3, ["sightseeing"], "gourmet"), {
    charge: false,
  });
});

test("同じガチャの同じカテゴリを取り直すと、また1回と数える(gachaIdの使い回し対策)", () => {
  assert.deepEqual(planReservation(3, ["gourmet"], "gourmet"), { charge: true });
});

test("上限に達していると、新しいガチャの取得は拒否する", () => {
  assert.throws(
    () => planReservation(LIFETIME_FREE_LIMIT, undefined, "gourmet"),
    (e: unknown) =>
      (e as { code?: string }).code === "resource-exhausted" &&
      String((e as Error).message).includes("無料利用の上限(10回)"),
  );
});

test("上限のエラーは、種類(無料枠)を details に付けて返す", () => {
  assert.throws(
    () => planReservation(LIFETIME_FREE_LIMIT, undefined, "gourmet"),
    (e: unknown) =>
      (e as { details?: { limitType?: string } }).details?.limitType ===
      "free_tier",
  );
});

test("上限に達していても、数え済みのガチャの、もう一方のカテゴリは見られる", () => {
  assert.deepEqual(planReservation(LIFETIME_FREE_LIMIT, ["gourmet"], "sightseeing"), {
    charge: false,
  });
});

test("上限に達していると、同じカテゴリの取り直しは拒否する", () => {
  assert.throws(() =>
    planReservation(LIFETIME_FREE_LIMIT, ["gourmet"], "gourmet"),
  );
});

test("gachaIdがない古いアプリは、呼び出しごとに数える", () => {
  assert.deepEqual(planReservation(0, undefined, "gourmet"), { charge: true });
  assert.deepEqual(planReservation(0, undefined, "sightseeing"), { charge: true });
});

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
  // 観光の取り直しは、数え済みガチャの別カテゴリとして、無料のまま。
  assert.deepEqual(planReservation(1, recorded, "sightseeing"), { charge: false });
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
