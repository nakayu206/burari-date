import assert from "node:assert/strict";
import { test } from "node:test";

import { LIFETIME_FREE_LIMIT } from "./fairUse";

test("無料上限は10回である", () => {
  assert.equal(LIFETIME_FREE_LIMIT, 10);
});
