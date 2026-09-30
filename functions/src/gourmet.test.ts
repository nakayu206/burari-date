import assert from "node:assert/strict";
import { test } from "node:test";

import { toBudgetText } from "./gourmet";

test("平均ディナー予算があれば、それを予算の目安にする", () => {
  assert.equal(toBudgetText({ name: "1001~1500円", average: "900円" }), "900円");
});

test("平均予算が空なら、予算の帯を使う", () => {
  assert.equal(toBudgetText({ name: "1001~1500円", average: "" }), "1001~1500円");
  assert.equal(toBudgetText({ name: "1001~1500円" }), "1001~1500円");
});

test("前後の空白を取り除く", () => {
  assert.equal(toBudgetText({ average: "  3000円 " }), "3000円");
});

test("予算のデータがなければundefined", () => {
  assert.equal(toBudgetText(undefined), undefined);
  assert.equal(toBudgetText({}), undefined);
  assert.equal(toBudgetText({ name: " ", average: " " }), undefined);
});
