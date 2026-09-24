import assert from "node:assert/strict";
import { test } from "node:test";

import { parsePicks, toCandidates } from "./ai";
import type { RawPlace } from "./types";

const place = (id: string): RawPlace => ({ id, name: id });

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

test("同じindexが複数回選ばれても候補は重複しない", () => {
  const targets = [place("a"), place("b")];
  const candidates = toCandidates(
    [
      { index: 0, catchCopy: "1回目", reason: "r1" },
      { index: 0, catchCopy: "2回目", reason: "r2" },
    ],
    targets,
    "gourmet",
  );
  assert.equal(candidates.length, 1);
  assert.equal(candidates[0]?.catchCopy, "1回目");
});

test("5件を超える選出は先頭5件に切り詰める", () => {
  const targets = [0, 1, 2, 3, 4, 5, 6].map((i) => place(`p${i}`));
  const picks = targets.map((_, index) => ({
    index,
    catchCopy: `c${index}`,
    reason: `r${index}`,
  }));
  const candidates = toCandidates(picks, targets, "sightseeing");
  assert.equal(candidates.length, 5);
});

test("存在しないindexは無視する", () => {
  const targets = [place("a")];
  const candidates = toCandidates(
    [{ index: 5, catchCopy: "存在しない", reason: "r" }],
    targets,
    "gourmet",
  );
  assert.deepEqual(candidates, []);
});
