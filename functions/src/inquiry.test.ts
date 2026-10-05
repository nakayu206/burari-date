import assert from "node:assert/strict";
import { test } from "node:test";

import {
  assertWithinDailyLimit,
  buildResendPayload,
  DAILY_INQUIRY_LIMIT,
  dayKeyOf,
  MAX_MESSAGE_LENGTH,
  parseInquiry,
  sanitizeMeta,
} from "./inquiry";

const meta = { uid: "uid-1", appVersion: "1.0.0", flavor: "prod" };

test("正しい内容は、問い合わせに変換する(本文の前後の空白は除く)", () => {
  const inquiry = parseInquiry({
    category: "bug",
    message: "  落ちました  ",
    replyTo: " user@example.com ",
  });
  assert.deepEqual(inquiry, {
    category: "bug",
    message: "落ちました",
    replyTo: "user@example.com",
  });
});

test("返信先は必須(未入力・空白だけ・null・文字列でないなら拒否する)", () => {
  for (const replyTo of [undefined, null, "", "   ", 123]) {
    assert.throws(
      () => parseInquiry({ category: "other", message: "こんにちは", replyTo }),
      /返信先のメールアドレスを入力/,
      String(replyTo),
    );
  }
});

test("種類が不正なら拒否する", () => {
  assert.throws(() => parseInquiry({ category: "spam", message: "a" }), /種類/);
  assert.throws(() => parseInquiry({ message: "a" }), /種類/);
  assert.throws(() => parseInquiry(undefined), /種類/);
});

test("本文が空・空白だけ・文字列でないなら拒否する", () => {
  assert.throws(() => parseInquiry({ category: "bug", message: "" }), /本文/);
  assert.throws(() => parseInquiry({ category: "bug", message: "  \n " }), /本文/);
  assert.throws(() => parseInquiry({ category: "bug", message: 123 }), /本文/);
});

test("本文は最大文字数まで(超えたら拒否する)", () => {
  const ok = parseInquiry({
    category: "bug",
    message: "あ".repeat(MAX_MESSAGE_LENGTH),
    replyTo: "user@example.com",
  });
  assert.equal(ok.message.length, MAX_MESSAGE_LENGTH);
  assert.throws(
    () => parseInquiry({ category: "bug", message: "あ".repeat(MAX_MESSAGE_LENGTH + 1) }),
    /文字まで/,
  );
});

test("返信先のメールアドレスが明らかに不正なら拒否する", () => {
  for (const replyTo of ["abc", "a@b", "a b@c.com", "@c.com"]) {
    assert.throws(
      () => parseInquiry({ category: "bug", message: "a", replyTo }),
      /返信先のメールアドレスが不正/,
      replyTo,
    );
  }
});

test("メールの件名は、固定の文言と種類だけで作る(利用者の入力を入れない)", () => {
  const payload = buildResendPayload(
    {
      category: "request",
      message: "件名\nBcc: evil@example.com",
      replyTo: "user@example.com",
    },
    meta,
    "owner@example.com",
  );
  assert.equal(payload.subject, "[ぶらりデートガチャ] 要望のお問い合わせ");
  assert.deepEqual(payload.to, ["owner@example.com"]);
});

test("メール本文に、種類・本文・返信先・調査用の情報を入れる", () => {
  const payload = buildResendPayload(
    { category: "bug", message: "落ちました", replyTo: "user@example.com" },
    meta,
    "owner@example.com",
  );
  assert.match(payload.text, /種類: 不具合/);
  assert.match(payload.text, /返信先: user@example\.com/);
  assert.match(payload.text, /落ちました/);
  assert.match(payload.text, /ユーザーID: uid-1/);
  assert.match(payload.text, /アプリのバージョン: 1\.0\.0/);
  assert.match(payload.text, /Flavor: prod/);
});

test("返信先を、Reply-Toに設定する", () => {
  const payload = buildResendPayload(
    { category: "bug", message: "a", replyTo: "user@example.com" },
    meta,
    "owner@example.com",
  );
  assert.equal(payload.reply_to, "user@example.com");
});

test("調査用の情報が不明のときは、「不明」と書く", () => {
  const payload = buildResendPayload(
    { category: "other", message: "a", replyTo: "user@example.com" },
    { uid: "u" },
    "o@example.com",
  );
  assert.match(payload.text, /アプリのバージョン: 不明/);
  assert.match(payload.text, /Flavor: 不明/);
});

test("アプリが送る文字列は、改行・制御文字を除き、長さを切る", () => {
  assert.equal(sanitizeMeta("1.0.0\nBcc: x"), "1.0.0 Bcc: x");
  assert.equal(sanitizeMeta("a".repeat(100))?.length, 40);
  assert.equal(sanitizeMeta("   "), undefined);
  assert.equal(sanitizeMeta(123), undefined);
  assert.equal(sanitizeMeta(undefined), undefined);
});

test("1日の送信は、上限の回数まで(上限に達したら拒否する)", () => {
  assert.doesNotThrow(() => assertWithinDailyLimit(0));
  assert.doesNotThrow(() => assertWithinDailyLimit(DAILY_INQUIRY_LIMIT - 1));
  assert.throws(() => assertWithinDailyLimit(DAILY_INQUIRY_LIMIT), (e: unknown) => {
    return (e as { code?: string }).code === "resource-exhausted";
  });
});

test("1日の区切りは、日本時間(UTCの15時に日付が変わる)", () => {
  assert.equal(dayKeyOf(new Date("2026-10-05T14:59:59Z")), "20261005");
  assert.equal(dayKeyOf(new Date("2026-10-05T15:00:00Z")), "20261006");
});
