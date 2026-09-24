import assert from "node:assert/strict";
import { test } from "node:test";

import { estimateWalkMinutes } from "./distance";

test("同じ地点なら1分になる(0分にはならない)", () => {
  assert.equal(estimateWalkMinutes(35.681, 139.767, 35.681, 139.767), 1);
});

test("約400m離れた地点は徒歩5分程度になる", () => {
  // 東京駅(35.681236, 139.767125)から新橋駅(35.665792, 139.758503)付近、
  // 緯度差だけで概算した約400m相当の座標。
  const minutes = estimateWalkMinutes(35.681, 139.767, 35.6846, 139.767);
  assert.ok(minutes >= 4 && minutes <= 6, `expected ~5, got ${minutes}`);
});
