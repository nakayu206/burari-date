# CLAUDE.md

このリポジトリで作業するAIエージェント（Claude Code）向けのルール集約ファイル。個別ドキュメントに散らばる決定事項ではなく、**作業の進め方そのものに関するルール**をここにまとめる。姉妹リポジトリ（kumayokeru-app、tekushare-app、kosodate-hitoiki／kosodate-hitoiki-backend、kumayokeru-backend）と運用方針を揃えることを前提とする。

## このリポジトリについて

ぶらりデートガチャ ― 駅ガチャでめぐる、偶然のデートスポットを見つけるアプリ（Flutter）。バックエンドAPIは持たず、外部API（駅・路線情報、AI提案等）とFirebaseを利用する構成。

## 一次情報と資料の優先順位

1. 一次情報源（詳細仕様）はNotion「ぶらりデートガチャ 仕様書」。画面デザインは[Figmaデザインファイル](https://www.figma.com/design/1zNLU0L3FyTI4IXodCTtog)。
2. [docs/全体設計書.md](docs/全体設計書.md) が、Notion・Figmaの内容をこのリポジトリのコードベースと対応づけて要点整理したもの。

| ドキュメント | 内容 |
|---|---|
| [全体設計書](docs/全体設計書.md) | プロジェクト目標・主要機能・アーキテクチャ・データ設計 |
| [デザイントークン](docs/デザイントークン.md) | カラー・スペーシング・サイズ等のUI定数 |
| [コード規約](docs/コード規約.md) | 命名規則・アーキテクチャ方針・テスト規約（kumayokeru-app/tekushare-appと共通、**必読**） |
| [環境とブランチ運用](docs/環境とブランチ運用.md) | Flavor（dev/stg/prod）・GitHub Flow + タグリリース |
| [環境構築手順](docs/環境構築手順.md) | 新規セットアップ手順（Flutter/Android/iOS） |
| [テスト方針](docs/テスト方針.md) | テストの方針と実行コマンド |
| [ストア公開チェックリスト](docs/ストア公開チェックリスト.md) | Google Playの入力・素材・規約対応・公開前の残り。仕組みを変えたときの更新先 |

コードを書く前に必ず[コード規約](docs/コード規約.md)を確認する（命名規則・importの順序・エラー表示方針・非同期処理の規約はkumayokeru-appと共通）。

## ブランチ・PRの運用: GitHub Flow + タグリリース

環境ごとの長命ブランチ（dev/stg/prodブランチ）は作らない。環境の切り替えはFlavor（`lib/main_dev.dart`/`main_stg.dart`/`main_prod.dart`、Android productFlavorsで別パッケージ名）で行う（[環境とブランチ運用](docs/環境とブランチ運用.md)参照）。iOSのFlavor分けは未対応（Xcode環境がないため）。

```text
main                    ← これ1本
  ├─ feature/xxx        ← 機能開発（短命）
  └─ fix/xxx             ← バグ修正（短命）
```

- `main`へのpushでstg APKが自動ビルドされる（`deploy-stg.yml`）。`v*.*.*`タグでprod aabのビルド＋GitHub Releaseが作成される（`deploy-prod.yml`）。ストアへの自動配信は未設定。
- 作業は`main`から分岐し、PR経由で`main`へマージする。`main`へ直接pushしない。
- PRと同じタイミングで対応するテストを作成する（[テスト方針](docs/テスト方針.md)）。

## コミット・PRメッセージ

- 日本語で、変更の意図（なぜ）が分かるように書く。
- コミットメッセージ・PR説明の末尾に付ける attribution（Co-Authored-By等）は、呼び出し元（Claude Codeのシステム設定）の指示に従う。本ファイルでは固定しない。

## セットアップ・実行

```bash
flutter pub get
flutter run --flavor dev -t lib/main_dev.dart

flutter test
```

詳細は[環境構築手順](docs/環境構築手順.md)を参照。

## 秘密情報の扱い

外部APIキー・Firebase設定の秘密値をリポジトリに含めない。作業中に`macos/`・`windows/`配下の自動生成ファイル（`GeneratedPluginRegistrant`等）やdevtools関連の設定ファイルがビルドで変更されることがあるが、無関係な変更なのでコミット対象に含めない。
