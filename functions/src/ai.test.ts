import assert from "node:assert/strict";
import { test } from "node:test";

import { parsePicks } from "./ai";

test("正しいJSON配列をパースできる", () => {
  const picks = parsePicks(
    '[{"index": 0, "catchCopy": "a", "reason": "b"}]',
  );
  assert.deepEqual(picks, [{ index: 0, catchCopy: "a", reason: "b" }]);
});

test("説明文が前後に付いていても配列部分だけ取り出せる", () => {
  const picks = parsePicks(
    'はい、選びました:\n[{"index": 1, "catchCopy": "a", "reason": "b"}]\n以上です。',
  );
  assert.deepEqual(picks, [{ index: 1, catchCopy: "a", reason: "b" }]);
});

test("不正な形式は空配列を返す", () => {
  assert.deepEqual(parsePicks("こわれています"), []);
});

test("必須フィールドが欠けた要素は除外する", () => {
  const picks = parsePicks(
    '[{"index": 0, "catchCopy": "a"}, {"index": 1, "catchCopy": "a", "reason": "b"}]',
  );
  assert.deepEqual(picks, [{ index: 1, catchCopy: "a", reason: "b" }]);
});
