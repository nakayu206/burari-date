# ぶらりデートガチャ

駅ガチャでめぐる、偶然のデートスポット。出発駅と路線を選ぶとランダムに行き先が決まり、
その駅周辺のグルメ・観光スポットをAIが提案してくれるデート先発見アプリ。

## ドキュメント

- [全体設計書](docs/全体設計書.md) — プロジェクト目標・主要機能・アーキテクチャ・データ設計
- [デザイントークン](docs/デザイントークン.md) — カラー・スペーシング・サイズ等のUI定数
- [コード規約](docs/コード規約.md) — 命名規則・アーキテクチャ方針・テスト規約
- [環境とブランチ運用](docs/環境とブランチ運用.md) — GitHub Flow + タグリリース
- [環境構築手順](docs/環境構築手順.md) — 新規セットアップ手順(Flutter/Android/iOS)
- [テスト方針](docs/テスト方針.md)

一次情報源(詳細仕様)はNotion「ぶらりデートガチャ 仕様書」、画面デザインは
[Figmaデザインファイル](https://www.figma.com/design/1zNLU0L3FyTI4IXodCTtog)を参照。

## クイックスタート

```bash
flutter pub get
flutter run
```

詳細は[環境構築手順.md](docs/環境構築手順.md)を参照。

## 開発状況

初期構築(基盤)の段階。駅・路線データや店舗検索API、AI(Claude API)連携は未接続で、
`lib/data/datasources/local`のモックデータで画面遷移を確認できる状態。以降の機能追加は
GitHub Issue([一覧](https://github.com/nakayu206/burari-date/issues))で管理していく。
