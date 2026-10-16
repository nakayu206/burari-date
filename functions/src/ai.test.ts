import assert from "node:assert/strict";
import { test } from "node:test";

import { anthropicApiKey, describePlaces, generateCandidates, extractText, parsePicks, requireCandidates, toCandidates } from "./ai";
import type { RawPlace } from "./types";

const place = (id: string): RawPlace => ({ id, name: id });

test("AIの応答は生成結果として返し、障害は握りつぶさない", async (t) => {
  t.mock.method(anthropicApiKey, "value", () => "test-key");
  const fetchMock = t.mock.method(globalThis, "fetch", async () => new Response(JSON.stringify({
    content: [{ type: "text", text: '[{"index":0,"catchCopy":"紹介文","reason":"理由"}]' }],
  })));
  const [candidate] = await generateCandidates("駅", "sightseeing", [place("park")]);
  assert.equal(candidate.catchCopy, "紹介文");
  fetchMock.mock.mockImplementation(async () => new Response("error", { status: 503 }));
  await assert.rejects(generateCandidates("駅", "gourmet", [place("a")]), /503/);
});

test("周辺施設が0件ならAIを呼ばない", async (t) => {
  const fetchMock = t.mock.method(globalThis, "fetch", async () => { throw new Error("unexpected"); });
  assert.deepEqual(await generateCandidates("駅", "gourmet", []), []);
  assert.equal(fetchMock.mock.callCount(), 0);
});

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

test("配列が見つからない場合は例外を投げる(無料枠を消費しないため)", () => {
  assert.throws(() => parsePicks("こわれています"));
});

test("配列に見えても不正なJSONの場合は例外を投げる", () => {
  assert.throws(() => parsePicks("[{index: 0"));
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

test("候補に、ジャンル名と予算の目安を引き継ぐ", () => {
  const targets = [
    { id: "a", name: "a", categoryName: "中華", budget: "900円" },
  ];
  const [candidate] = toCandidates(
    [{ index: 0, catchCopy: "c", reason: "r" }],
    targets,
    "gourmet",
  );
  assert.equal(candidate.categoryName, "中華");
  assert.equal(candidate.budget, "900円");
});

test("応答にテキストがなければ、空の結果にせず例外を投げる", () => {
  assert.throws(() => extractText({}), /テキスト/);
  assert.throws(() => extractText({ content: [] }), /テキスト/);
  assert.throws(() => extractText({ content: [{ type: "text", text: "  " }] }), /テキスト/);
  assert.equal(extractText({ content: [{ type: "text", text: "[]" }] }), "[]");
});

test("存在しない番号だけを返した応答は、候補0件の正常結果にせず例外を投げる", () => {
  const picks = parsePicks('[{"index": 99, "catchCopy": "a", "reason": "b"}]');
  const candidates = toCandidates(picks, [place("a")], "gourmet");
  assert.throws(() => requireCandidates(candidates), /候補/);
});

test("候補が1件でもあれば、そのまま返す", () => {
  const picks = parsePicks('[{"index": 0, "catchCopy": "a", "reason": "b"}]');
  const candidates = toCandidates(picks, [place("a")], "gourmet");
  assert.equal(requireCandidates(candidates).length, 1);
});

test("紹介文は、渡した場所のidに対応づけて返し、範囲外・重複の番号は捨てる", async (t) => {
  t.mock.method(anthropicApiKey, "value", () => "test-key");
  t.mock.method(globalThis, "fetch", async () => new Response(JSON.stringify({
    content: [{ type: "text", text: '[{"index":1,"catchCopy":"b","reason":"B"},{"index":1,"catchCopy":"dup","reason":"x"},{"index":9,"catchCopy":"z","reason":"x"},{"index":0,"catchCopy":"a","reason":"A"}]' }],
  })));
  const result = await describePlaces("駅", "gourmet", [place("p0"), place("p1")]);
  assert.deepEqual(result, [
    { id: "p1", catchCopy: "b", reason: "B" },
    { id: "p0", catchCopy: "a", reason: "A" },
  ]);
});

test("紹介文を付ける場所が0件なら、AIを呼ばない", async (t) => {
  const fetchMock = t.mock.method(globalThis, "fetch", async () => { throw new Error("unexpected"); });
  assert.deepEqual(await describePlaces("駅", "gourmet", []), []);
  assert.equal(fetchMock.mock.callCount(), 0);
});

test("紹介文が一部の場所に足りない・空のときは、成功にせず失敗として投げる", async (t) => {
  t.mock.method(anthropicApiKey, "value", () => "test-key");
  const fetchMock = t.mock.method(globalThis, "fetch", async () => new Response(JSON.stringify({
    content: [{ type: "text", text: '[{"index":0,"catchCopy":"a","reason":"A"}]' }],
  })));
  await assert.rejects(describePlaces("駅", "gourmet", [place("p0"), place("p1")]), /全件/);

  fetchMock.mock.mockImplementation(async () => new Response(JSON.stringify({
    content: [{ type: "text", text: '[{"index":0,"catchCopy":"","reason":"A"}]' }],
  })));
  await assert.rejects(describePlaces("駅", "gourmet", [place("p0")]), /全件/);

  fetchMock.mock.mockImplementation(async () => new Response(JSON.stringify({
    content: [{ type: "text", text: "[]" }],
  })));
  await assert.rejects(describePlaces("駅", "gourmet", [place("p0")]), /全件/);
});
