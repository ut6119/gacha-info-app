# ガチャガチャ情報アプリ（独立版）

このディレクトリは `card-tracker` とは完全に別アプリです。  
レシート管理アプリ側のコードや設定には影響しません。

## 機能

- 新作ガチャ情報（メーカーサイト由来）一覧
- X投稿の速報一覧
- 各商品の公式URL表示
- メルカリ / Yahoo!フリマの販売価格相場（最安/中央値/最高）
- フィルタ（メーカー別）
- `scripts/update_data.py` でデータ自動取得

## データ取得元

- メーカー系: DuckDuckGo検索経由で `gashapon.jp` / `takaratomy-arts.co.jp` / `kenelephant.co.jp` などを巡回
- X系: Yahoo!リアルタイム検索で `x.com` / `twitter.com` 投稿URLを抽出
- 中古相場: DuckDuckGo検索経由で `jp.mercari.com` / `paypayfleamarket.yahoo.co.jp` を集計

## セットアップ

```bash
cd /Users/ookuboyuuta/Documents/New\ project/gacha_info_app
flutter pub get
```

## 起動

```bash
flutter run -d chrome
```

## データ更新

```bash
./scripts/update_data.sh
```

`update_data.sh` は初回実行時に `.venv` を作成して依存を入れます。

このアプリの情報は「常時リアルタイム配信」ではなく、`update_data.sh` 実行時点の最新情報です。

更新結果は以下へ同期されます。

- `data/releases.json`
- `data/x_posts.json`
- `assets/data/*.json`
- `web/data/*.json`

## 自動更新の例（cron）

3時間ごと実行:

```cron
0 */3 * * * cd /Users/ookuboyuuta/Documents/New\ project/gacha_info_app && /usr/bin/env bash ./scripts/update_data.sh
```

## スマホ共有（2人で使う）

GitHub Pagesで公開すると、iPhone/Androidのブラウザから同じURLで利用できます。

1. この `gacha_info_app` をGitHubリポジトリへpush
2. GitHubの `Settings > Pages` で `Build and deployment` を `GitHub Actions` にする
3. `Actions` で `Deploy Web App` を実行（または `main/master` へのpushで自動実行）
4. 公開URLを共有

公開URLの形式:

- 通常リポジトリ: `https://<GitHubユーザー名>.github.io/<リポジトリ名>/`
- `<ユーザー名>.github.io` リポジトリ: `https://<GitHubユーザー名>.github.io/`

ワークフロー定義:

- `/.github/workflows/deploy-pages.yml`

## 注意

- 外部サイトのHTML構造変更で取得ロジックが壊れる可能性があります。
- Xの正式APIを使う場合は、別途APIキー管理とレート制御を追加してください。
