import assert from "node:assert/strict";
import { test } from "node:test";

import { parseGourmetResponse, toBudgetText } from "./gourmet";

test("応答のエラー(HTTP 200で返る)は、店舗0件の成功ではなく、失敗として投げる", () => {
  const body = {
    results: { api_version: "1.26", error: [{ code: 2000, message: "APIキーが不正です" }] },
  };
  assert.throws(() => parseGourmetResponse(body), /エラーを返しました: 2000 APIキーが不正です/);
});

test("応答の形式がおかしいときも、失敗として投げる", () => {
  assert.throws(() => parseGourmetResponse({}), /想定した形式ではありません/);
  assert.throws(() => parseGourmetResponse(null), /想定した形式ではありません/);
  assert.throws(() => parseGourmetResponse({ results: "x" }), /想定した形式ではありません/);
});

test("店舗が0件(shopが空・なし)のときは、失敗ではなく、空の配列", () => {
  assert.deepEqual(parseGourmetResponse({ results: { shop: [], results_available: 0 } }), []);
  assert.deepEqual(parseGourmetResponse({ results: { results_available: 0 } }), []);
});

test("店舗があれば、候補の元データにする", () => {
  const places = parseGourmetResponse({
    results: {
      shop: [{ id: "J001", name: "テスト食堂", address: "東京都", genre: { name: "居酒屋" } }],
    },
  });
  assert.equal(places.length, 1);
  assert.equal(places[0].id, "J001");
  assert.equal(places[0].name, "テスト食堂");
  assert.equal(places[0].categoryName, "居酒屋");
});

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
