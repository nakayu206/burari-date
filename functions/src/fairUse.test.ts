import assert from "node:assert/strict";
import { test } from "node:test";

import { currentMonthKey } from "./fairUse";

test("1桁の月は先頭にゼロを付ける", () => {
  assert.equal(currentMonthKey(new Date("2026-01-05T00:00:00Z")), "2026-01");
});

test("2桁の月はそのまま2桁になる", () => {
  assert.equal(currentMonthKey(new Date("2026-09-24T00:00:00Z")), "2026-09");
});

test("月をまたぐと異なるキーになる", () => {
  const a = currentMonthKey(new Date("2026-09-30T23:59:59Z"));
  const b = currentMonthKey(new Date("2026-10-01T00:00:00Z"));
  assert.notEqual(a, b);
});
