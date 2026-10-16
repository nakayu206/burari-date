/**
 * 利用枠の確保・返却を、Firestoreエミュレータで、実際の書き込みまで確かめるテスト(Issue #189)。
 *
 * 判断の部分(純粋な関数)は`fairUse.test.ts`で確かめている。ここでは、トランザクションの
 * 読み書きと、重なった呼び出しの組み合わせを確かめる。実行は、`npm run test:emulator`
 * (エミュレータを起動して、このファイルを実行する)。通常の`npm test`には含めない。
 */
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { before, describe, test } from "node:test";

import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

import { markAccountDeleted } from "./account";
import {
  LIFETIME_FREE_LIMIT,
  MAX_DESCRIBE_TRIES,
  MONTHLY_FAIR_USE_LIMIT,
  markCategorySucceeded,
  releaseUsage,
  reserveUsage,
  savePlacesForDescription,
  takeDescribeTry,
} from "./fairUse";

before(() => {
  // 本番のFirestoreに、書き込まないための安全装置。
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error(
      "FIRESTORE_EMULATOR_HOSTがありません。`npm run test:emulator`で実行してください。",
    );
  }
  initializeApp({ projectId: "demo-burari" });
});

/** テストごとに、別のユーザー・ガチャ・端末にして、互いに影響しないようにする。 */
const newUid = () => `u-${randomUUID()}`;
const newGacha = () => `g-${randomUUID()}`;
const newDevice = () => `d-${randomUUID()}`;

const db = () => getFirestore();

async function userData(uid: string) {
  return (await db().collection("users").doc(uid).get()).data();
}

async function gachaDoc(uid: string, gachaId: string) {
  return db().collection("users").doc(uid).collection("gachaUsage").doc(gachaId).get();
}

/** 購読中のユーザーを作る(月の回数と、その月を指定できる)。 */
async function makeSubscriber(uid: string, monthlyKey: string, monthlyGachaCount: number) {
  await db()
    .collection("users")
    .doc(uid)
    .set({ subscriptionStatus: "active", monthlyKey, monthlyGachaCount });
}

/** 指定したコードのHttpsErrorで失敗すること(上限の種類も、指定できる)。 */
function rejectsWith(code: string, limitType?: string) {
  return (e: unknown) => {
    const err = e as { code?: string; details?: { limitType?: string } };
    assert.equal(err.code, code);
    if (limitType) assert.equal(err.details?.limitType, limitType);
    return true;
  };
}

describe("利用枠: 取得の確保", () => {
  test("初めての取得は無料枠を1回消費し、同じガチャの別カテゴリは数えない", async () => {
    const uid = newUid();
    const gacha = newGacha();

    const first = await reserveUsage(uid, "gourmet", gacha);
    const second = await reserveUsage(uid, "sightseeing", gacha);

    assert.equal(first.charged, true);
    assert.equal(first.source, "free");
    assert.equal(second.charged, false);
    assert.equal((await userData(uid))?.lifetimeFreeUsed, 1);
    assert.deepEqual(
      ((await gachaDoc(uid, gacha)).data()?.categories as string[]).sort(),
      ["gourmet", "sightseeing"],
    );
  });

  test("無料枠を使い切ると、それ以上は断り、回数は増えない", async () => {
    const uid = newUid();
    for (let i = 0; i < LIFETIME_FREE_LIMIT; i++) {
      await reserveUsage(uid, "gourmet", newGacha());
    }

    await assert.rejects(
      reserveUsage(uid, "gourmet", newGacha()),
      rejectsWith("resource-exhausted", "free_tier"),
    );
    assert.equal((await userData(uid))?.lifetimeFreeUsed, LIFETIME_FREE_LIMIT);
  });

  test("上限の手前で同時に取得しても、上限を超えて確保されない", async () => {
    const uid = newUid();
    for (let i = 0; i < LIFETIME_FREE_LIMIT - 1; i++) {
      await reserveUsage(uid, "gourmet", newGacha());
    }

    const results = await Promise.allSettled([
      reserveUsage(uid, "gourmet", newGacha()),
      reserveUsage(uid, "gourmet", newGacha()),
      reserveUsage(uid, "gourmet", newGacha()),
    ]);

    assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
    assert.equal((await userData(uid))?.lifetimeFreeUsed, LIFETIME_FREE_LIMIT);
  });

  test("グルメと観光が同時でも、1回のガチャとして1回しか数えない", async () => {
    const uid = newUid();
    const gacha = newGacha();

    const [a, b] = await Promise.all([
      reserveUsage(uid, "gourmet", gacha),
      reserveUsage(uid, "sightseeing", gacha),
    ]);

    assert.equal([a, b].filter((r) => r.charged).length, 1);
    assert.equal((await userData(uid))?.lifetimeFreeUsed, 1);
  });

  test("削除済みのアカウントは、断る", async () => {
    const uid = newUid();
    await markAccountDeleted(uid);

    await assert.rejects(
      reserveUsage(uid, "gourmet", newGacha()),
      rejectsWith("unauthenticated"),
    );
  });
});

describe("利用枠: 端末ごとの無料枠", () => {
  test("同じ端末では、別のユーザーになっても、無料枠が数え直されない", async () => {
    const device = newDevice();
    const first = newUid();
    for (let i = 0; i < LIFETIME_FREE_LIMIT; i++) {
      await reserveUsage(first, "gourmet", newGacha(), undefined, device);
    }

    await assert.rejects(
      reserveUsage(newUid(), "gourmet", newGacha(), undefined, device),
      rejectsWith("resource-exhausted", "free_tier"),
    );
  });

  test("別の端末なら、新しいユーザーは無料枠を使える", async () => {
    const used = newDevice();
    const first = newUid();
    for (let i = 0; i < LIFETIME_FREE_LIMIT; i++) {
      await reserveUsage(first, "gourmet", newGacha(), undefined, used);
    }

    const result = await reserveUsage(newUid(), "gourmet", newGacha(), undefined, newDevice());

    assert.equal(result.charged, true);
  });

  test("失敗して返却すると、端末の回数も戻る", async () => {
    const device = newDevice();
    const uid = newUid();
    const gacha = newGacha();
    const reservation = await reserveUsage(uid, "gourmet", gacha, undefined, device);

    await releaseUsage(uid, reservation, "gourmet", gacha, undefined, device);

    assert.equal((await db().collection("devices").doc(device).get()).data()?.lifetimeFreeUsed, 0);
    assert.equal((await userData(uid))?.lifetimeFreeUsed, 0);
  });
});

describe("利用枠: 失敗したときの返却", () => {
  test("取得が失敗(周辺に施設がない0件も同じ)すると、回数を戻し、ガチャの記録も消す", async () => {
    const uid = newUid();
    const gacha = newGacha();
    const reservation = await reserveUsage(uid, "gourmet", gacha);

    await releaseUsage(uid, reservation, "gourmet", gacha);

    assert.equal((await userData(uid))?.lifetimeFreeUsed, 0);
    assert.equal((await gachaDoc(uid, gacha)).exists, false);
  });

  test("グルメが成功し、観光が失敗しても、1回の消費は残る", async () => {
    const uid = newUid();
    const gacha = newGacha();
    const gourmet = await reserveUsage(uid, "gourmet", gacha);
    await markCategorySucceeded(uid, gacha, "gourmet", gourmet.requestId);
    const sightseeing = await reserveUsage(uid, "sightseeing", gacha);

    await releaseUsage(uid, sightseeing, "sightseeing", gacha);

    assert.equal((await userData(uid))?.lifetimeFreeUsed, 1);
    assert.deepEqual((await gachaDoc(uid, gacha)).data()?.categories, ["gourmet"]);
  });

  test("消費した側のグルメが先に失敗し、観光が成功しても、1回の消費は残る", async () => {
    const uid = newUid();
    const gacha = newGacha();
    const gourmet = await reserveUsage(uid, "gourmet", gacha);
    const sightseeing = await reserveUsage(uid, "sightseeing", gacha);

    await releaseUsage(uid, gourmet, "gourmet", gacha);
    await markCategorySucceeded(uid, gacha, "sightseeing", sightseeing.requestId);

    assert.equal((await userData(uid))?.lifetimeFreeUsed, 1);
    assert.deepEqual((await gachaDoc(uid, gacha)).data()?.categories, ["sightseeing"]);
  });

  test("両方が失敗したら、消費は全部戻る", async () => {
    const uid = newUid();
    const gacha = newGacha();
    const gourmet = await reserveUsage(uid, "gourmet", gacha);
    const sightseeing = await reserveUsage(uid, "sightseeing", gacha);

    await releaseUsage(uid, gourmet, "gourmet", gacha);
    await releaseUsage(uid, sightseeing, "sightseeing", gacha);

    assert.equal((await userData(uid))?.lifetimeFreeUsed, 0);
    assert.equal((await gachaDoc(uid, gacha)).exists, false);
  });

  test("成功したカテゴリの取り直しが失敗したら、取り直しの分だけ戻す", async () => {
    const uid = newUid();
    const gacha = newGacha();
    const first = await reserveUsage(uid, "gourmet", gacha);
    await markCategorySucceeded(uid, gacha, "gourmet", first.requestId);
    const retry = await reserveUsage(uid, "gourmet", gacha);
    assert.equal((await userData(uid))?.lifetimeFreeUsed, 2);

    await releaseUsage(uid, retry, "gourmet", gacha);

    assert.equal((await userData(uid))?.lifetimeFreeUsed, 1);
    assert.deepEqual((await gachaDoc(uid, gacha)).data()?.categories, ["gourmet"]);
  });

  test("同じカテゴリの取得が重なり、片方が失敗しても、処理中の側が残る", async () => {
    const uid = newUid();
    const gacha = newGacha();
    const a = await reserveUsage(uid, "gourmet", gacha);
    const b = await reserveUsage(uid, "gourmet", gacha);

    await releaseUsage(uid, a, "gourmet", gacha);
    await markCategorySucceeded(uid, gacha, "gourmet", b.requestId);

    assert.equal((await userData(uid))?.lifetimeFreeUsed, 1);
    assert.deepEqual((await gachaDoc(uid, gacha)).data()?.categories, ["gourmet"]);
  });
});

describe("利用枠: 購読中の月の回数", () => {
  const OCT = new Date("2026-10-15T03:00:00Z");
  const NOV = new Date("2026-11-15T03:00:00Z");

  test("月の上限に達すると断り、回数は増えない", async () => {
    const uid = newUid();
    await makeSubscriber(uid, "202610", MONTHLY_FAIR_USE_LIMIT);

    await assert.rejects(
      reserveUsage(uid, "gourmet", newGacha(), OCT),
      rejectsWith("resource-exhausted", "monthly"),
    );
    assert.equal((await userData(uid))?.monthlyGachaCount, MONTHLY_FAIR_USE_LIMIT);
  });

  test("月が替わると、月の回数は1から数え直す", async () => {
    const uid = newUid();
    await makeSubscriber(uid, "202610", MONTHLY_FAIR_USE_LIMIT);

    const result = await reserveUsage(uid, "gourmet", newGacha(), NOV);

    assert.equal(result.source, "monthly");
    const data = await userData(uid);
    assert.equal(data?.monthlyKey, "202611");
    assert.equal(data?.monthlyGachaCount, 1);
  });

  test("月をまたいで失敗しても、先月の分で、今月の回数を減らさない", async () => {
    const uid = newUid();
    await makeSubscriber(uid, "202610", 5);
    const gachaA = newGacha();
    const a = await reserveUsage(uid, "gourmet", gachaA, OCT); // 10月の6回目
    await reserveUsage(uid, "gourmet", newGacha(), NOV); // 11月の1回目

    await releaseUsage(uid, a, "gourmet", gachaA, NOV);

    assert.equal((await userData(uid))?.monthlyGachaCount, 1);
  });

  test("同じ月の失敗は、月の回数を戻す", async () => {
    const uid = newUid();
    await makeSubscriber(uid, "202610", 5);
    const gacha = newGacha();
    const reservation = await reserveUsage(uid, "gourmet", gacha, OCT);

    await releaseUsage(uid, reservation, "gourmet", gacha, OCT);

    assert.equal((await userData(uid))?.monthlyGachaCount, 5);
  });
});

describe("紹介文の後追い生成の回数制限", () => {
  const places = [{ id: "p1", name: "テスト食堂", budget: "900円" }];

  async function reserveAndSave(category: "gourmet" | "sightseeing" = "gourmet") {
    const uid = newUid();
    const gacha = newGacha();
    await reserveUsage(uid, category, gacha);
    await savePlacesForDescription(uid, gacha, category, "新宿", places);
    return { uid, gacha };
  }

  test("保存した場所と駅名を返し、回数の上限までは生成できる", async () => {
    const { uid, gacha } = await reserveAndSave();

    for (let i = 0; i < MAX_DESCRIBE_TRIES; i++) {
      const taken = await takeDescribeTry(uid, gacha, "gourmet");
      assert.equal(taken.stationName, "新宿");
      assert.deepEqual(taken.places, places);
    }
    await assert.rejects(
      takeDescribeTry(uid, gacha, "gourmet"),
      rejectsWith("resource-exhausted"),
    );
  });

  test("場所を保存していないカテゴリ・ガチャは、断る", async () => {
    const { uid, gacha } = await reserveAndSave("gourmet");

    await assert.rejects(
      takeDescribeTry(uid, gacha, "sightseeing"),
      rejectsWith("failed-precondition"),
    );
    await assert.rejects(
      takeDescribeTry(uid, newGacha(), "gourmet"),
      rejectsWith("failed-precondition"),
    );
  });

  test("取り直し(再取得)で場所を保存し直すと、回数を数え直す", async () => {
    const { uid, gacha } = await reserveAndSave();
    for (let i = 0; i < MAX_DESCRIBE_TRIES; i++) {
      await takeDescribeTry(uid, gacha, "gourmet");
    }

    await savePlacesForDescription(uid, gacha, "gourmet", "新宿", places);

    await takeDescribeTry(uid, gacha, "gourmet");
  });

  test("別カテゴリの取得で、保存した場所が消えない", async () => {
    const { uid, gacha } = await reserveAndSave("gourmet");

    await reserveUsage(uid, "sightseeing", gacha);

    const taken = await takeDescribeTry(uid, gacha, "gourmet");
    assert.deepEqual(taken.places, places);
  });
});
